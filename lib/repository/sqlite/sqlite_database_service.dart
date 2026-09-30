// Copyright 2026 Anytime Podcast Player contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Provides a [Database] instance for the SQLite-backed repository.
///
/// Unlike Sembast, SQLite opens the database file by reading only the
/// header and page cache — typically < 100 ms even for large files.
class SqliteDatabaseService {
  static final _log = Logger('SqliteDatabaseService');
  static const int _schemaVersion = 3;

  Database? _db;
  Future<Database>? _dbFuture;

  /// Bumped by [close]; an open that finishes after a close is discarded
  /// instead of being cached and handed out.
  var _generation = 0;

  final String databaseName;

  SqliteDatabaseService({this.databaseName = 'anytime.sqlite'});

  Future<Database> get database {
    final db = _db;
    if (db != null) return Future.value(db);

    final generation = _generation;

    // Cache the Future itself: without this, concurrent callers racing through
    // the await would each open their own connection and leak all but the last.
    return _dbFuture ??= _open().then((value) {
      if (generation != _generation) {
        // close() ran while this connection was opening; it must not be cached
        // or handed out.
        value.close();

        throw StateError('The database was closed while opening');
      }

      _db = value;
      return value;
    }, onError: (Object error, StackTrace stackTrace) {
      // A failed open (transient I/O error) must not poison every later call:
      // clear the cached future so the next caller can retry.
      _dbFuture = null;

      Error.throwWithStackTrace(error, stackTrace);
    });
  }

  Future<Database> _open() async {
    final sw = Stopwatch()..start();
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, databaseName);
    _log.fine('Opening SQLite database at $path');

    final db = await openDatabase(
      path,
      version: _schemaVersion,
      singleInstance: false,
      onCreate: _onCreate,
      onOpen: (db) async {
        // Enable WAL mode for better concurrent read performance.
        // sqflite requires rawQuery for PRAGMA statements.
        //
        // Foreign keys are intentionally not enabled: the schema defines no
        // FK constraints, and the repository removes dependent rows (episodes,
        // bookmarks) explicitly inside the delete transactions.
        await db.rawQuery('PRAGMA journal_mode=WAL');
      },
    );

    _log.fine('SQLite database opened in ${sw.elapsedMilliseconds}ms');
    return db;
  }

  /// Creates all tables and indexes on first launch.
  Future<void> _onCreate(Database db, int version) async {
    final sw = Stopwatch()..start();
    _log.fine('Creating SQLite schema v$version');

    await db.execute('''
      CREATE TABLE podcast (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        guid            TEXT UNIQUE,
        url             TEXT NOT NULL,
        link            TEXT,
        title           TEXT NOT NULL,
        description     TEXT,
        imageUrl        TEXT,
        thumbImageUrl   TEXT,
        copyright       TEXT,
        etag            TEXT DEFAULT '',
        subscribedDate  INTEGER,
        lastUpdated     INTEGER,
        rssFeedLastUpdated INTEGER,
        latestEpisodeDate  INTEGER,
        filter          INTEGER DEFAULT 0,
        sort            INTEGER DEFAULT 0,
        newEpisodes     INTEGER DEFAULT 0,
        funding         TEXT,
        person          TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE episode (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        guid              TEXT NOT NULL,
        pguid             TEXT,
        downloadTaskId    TEXT,
        filepath          TEXT,
        filename          TEXT,
        downloadState     INTEGER DEFAULT 0,
        podcast           TEXT,
        title             TEXT,
        description       TEXT,
        content           TEXT,
        link              TEXT,
        imageUrl          TEXT,
        thumbImageUrl     TEXT,
        publicationDate   INTEGER,
        contentUrl        TEXT,
        length            INTEGER DEFAULT 0,
        mimeType          TEXT,
        author            TEXT,
        season            INTEGER DEFAULT 0,
        episode           INTEGER DEFAULT 0,
        duration          INTEGER DEFAULT 0,
        position          INTEGER DEFAULT 0,
        downloadPercentage INTEGER DEFAULT 0,
        played            INTEGER DEFAULT 0,
        ne                INTEGER DEFAULT 0,
        chaptersUrl       TEXT,
        chapters          TEXT,
        tid               INTEGER DEFAULT 0,
        transcriptUrls    TEXT,
        persons           TEXT,
        lastUpdated       INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE transcript (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        guid         TEXT,
        subtitles    TEXT,
        lastUpdated  INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE bookmark (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        episodeGuid  TEXT NOT NULL,
        episodeTitle TEXT,
        podcastName  TEXT,
        podcastGuid  TEXT,
        positionMs   INTEGER NOT NULL,
        note         TEXT,
        createdAt    INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE queue (
        id    INTEGER PRIMARY KEY CHECK (id = 1),
        guids TEXT
      )
    ''');

    // Indexes for fast lookups and sorting.
    await db.execute('CREATE INDEX idx_podcast_guid ON podcast(guid)');
    await db.execute('CREATE INDEX idx_episode_pubdate ON episode(publicationDate)');
    await db.execute('CREATE INDEX idx_episode_pguid ON episode(pguid)');
    await db.execute('CREATE INDEX idx_episode_guid ON episode(guid)');
    await db.execute('CREATE INDEX idx_episode_download ON episode(downloadState, downloadPercentage)');
    await db.execute('CREATE INDEX idx_episode_task ON episode(downloadTaskId)');
    await db.execute('CREATE INDEX idx_bookmark_episode ON bookmark(episodeGuid)');
    await db.execute('CREATE INDEX idx_bookmark_created ON bookmark(createdAt)');

    _log.fine('SQLite schema created in ${sw.elapsedMilliseconds}ms');
  }

  Future<void> close() async {
    _generation++;

    final future = _dbFuture;
    _dbFuture = null;
    _db = null;

    if (future != null) {
      try {
        final db = await future;
        await db.close();
      } catch (_) {
        // Opening the database failed, or the connection was discarded by the
        // generation check; there is nothing to close.
      }
    }
  }
}

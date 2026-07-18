// Copyright 2026 Anytime Podcast Player contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:anytime/entities/bookmark.dart';
import 'package:anytime/entities/episode.dart';
import 'package:anytime/entities/podcast.dart';
import 'package:anytime/entities/transcript.dart';
import 'package:anytime/repository/repository.dart';
import 'package:anytime/repository/sqlite/migration_service.dart';
import 'package:anytime/repository/sqlite/sqlite_database_service.dart';
import 'package:anytime/state/episode_state.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite-backed implementation of [Repository].
///
/// Compared to Sembast this gives:
/// - Database open in < 100 ms (reads file header only, not entire log)
/// - Indexed queries for [findEpisodesBefore] and [findEpisodeCountByPodcast]
/// - No append-only log bloat — SQLite reuses freed pages
class SqliteRepository extends Repository {
  static final _log = Logger('SqliteRepository');

  final _podcastSubject = BehaviorSubject<Podcast>();
  final _episodeSubject = BehaviorSubject<EpisodeState>();

  final SqliteDatabaseService _databaseService;
  final _queueGuids = <String>[];
  bool _migrationChecked = false;

  SqliteRepository({String databaseName = 'anytime.sqlite'})
      : _databaseService = SqliteDatabaseService(databaseName: databaseName);

  Future<Database> get _db async {
    final db = await _databaseService.database;
    if (!_migrationChecked) {
      _migrationChecked = true;
      await MigrationService.migrate(sqliteDb: db);
    }
    return db;
  }

  // ---------------------------------------------------------------------------
  // Podcast CRUD
  // ---------------------------------------------------------------------------

  @override
  Future<Podcast> savePodcast(Podcast podcast, {bool withEpisodes = true}) async {
    final db = await _db;
    _log.fine('Saving podcast (${podcast.id ?? -1}) ${podcast.url}');

    podcast.lastUpdated = DateTime.now();
    final map = _sanitizeForSqlite(podcast.toMap());

    if (podcast.id == null) {
      podcast.subscribedDate ??= DateTime.now();
      podcast.id = await db.insert('podcast', map, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await db.update('podcast', map, where: 'id = ?', whereArgs: [podcast.id]);
    }

    if (withEpisodes) {
      await _saveEpisodes(podcast.episodes);
    }

    _podcastSubject.add(podcast);
    return podcast;
  }

  @override
  Future<void> deletePodcast(Podcast podcast) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('episode', where: 'pguid = ?', whereArgs: [podcast.guid]);
      await txn.delete('podcast', where: 'id = ?', whereArgs: [podcast.id]);
    });
  }

  @override
  Future<Podcast?> findPodcastById(num id) async {
    final db = await _db;
    final rows = await db.query('podcast', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;

    final p = Podcast.fromMap(rows.first['id'] as int, _rowFromSqlite(rows.first));
    p.episodes = await findEpisodesByPodcastGuid(p.guid, filter: p.filter, sort: p.sort);
    return p;
  }

  @override
  Future<Podcast?> findPodcastByGuid(String guid) async {
    final db = await _db;
    final rows = await db.query('podcast', where: 'guid = ?', whereArgs: [guid], limit: 1);
    if (rows.isEmpty) return null;

    final p = Podcast.fromMap(rows.first['id'] as int, _rowFromSqlite(rows.first));
    p.episodes = await findEpisodesByPodcastGuid(p.guid, filter: p.filter, sort: p.sort);
    return p;
  }

  @override
  Future<List<Podcast>> subscriptions() async {
    final db = await _db;
    final rows = await db.query('podcast', orderBy: 'title COLLATE NOCASE');
    return rows.map((r) => Podcast.fromMap(r['id'] as int, _rowFromSqlite(r))).toList();
  }

  @override
  Future<List<Podcast>> searchPodcasts(String term) async {
    final db = await _db;
    final rows = await db.query(
      'podcast',
      where: 'title LIKE ? COLLATE NOCASE',
      whereArgs: ['%$term%'],
      orderBy: 'title COLLATE NOCASE',
    );
    return rows.map((r) => Podcast.fromMap(r['id'] as int, _rowFromSqlite(r))).toList();
  }

  // ---------------------------------------------------------------------------
  // Episode CRUD
  // ---------------------------------------------------------------------------

  @override
  Future<List<Episode>> findAllEpisodes() async {
    final db = await _db;
    final rows = await db.query('episode', orderBy: 'publicationDate DESC');
    return rows.map((r) => _episodeFromRow(r)).toList();
  }

  @override
  Future<List<Episode>> searchEpisodes(String term) async {
    final db = await _db;
    final rows = await db.query(
      'episode',
      where: 'title LIKE ? COLLATE NOCASE',
      whereArgs: ['%$term%'],
    );
    return rows.map((r) => _episodeFromRow(r)).toList();
  }

  @override
  Future<List<Episode>> findEpisodesBefore(DateTime beforeDate, {int limit = 100}) async {
    final sw = Stopwatch()..start();
    final db = await _db;
    final beforeMs = beforeDate.millisecondsSinceEpoch;

    final rows = await db.query(
      'episode',
      where: 'publicationDate < ?',
      whereArgs: [beforeMs],
      orderBy: 'publicationDate DESC',
      limit: limit,
    );

    final episodes = rows.map((r) => _episodeFromRow(r)).toList();
    _log.fine('findEpisodesBefore returned ${episodes.length} episodes in ${sw.elapsedMilliseconds}ms');
    return episodes;
  }

  @override
  Future<int> countEpisodesSince(DateTime sinceDate) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM episode WHERE publicationDate >= ?',
      [sinceDate.millisecondsSinceEpoch],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<Episode?> findEpisodeById(int? id) async {
    final db = await _db;
    final rows = await db.query('episode', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _loadEpisodeWithTranscript(rows.first);
  }

  @override
  Future<Episode?> findEpisodeByGuid(String guid) async {
    final db = await _db;
    final rows = await db.query('episode', where: 'guid = ?', whereArgs: [guid], limit: 1);
    if (rows.isEmpty) return null;
    return _loadEpisodeWithTranscript(rows.first);
  }

  @override
  Future<List<Episode>> findEpisodesByPodcastGuid(
    String? pguid, {
    PodcastEpisodeFilter filter = PodcastEpisodeFilter.none,
    PodcastEpisodeSort sort = PodcastEpisodeSort.none,
  }) async {
    final db = await _db;

    final where = _buildEpisodeFilterSql(filter, pguid);
    final orderBy = _buildEpisodeSortSql(sort);

    final rows = await db.query(
      'episode',
      where: where.$1,
      whereArgs: where.$2,
      orderBy: orderBy,
    );

    return rows.map((r) => _episodeFromRow(r)).toList();
  }

  @override
  Future<Map<String, int>> findEpisodeCountByPodcast({
    PodcastEpisodeFilter filter = PodcastEpisodeFilter.none,
  }) async {
    final db = await _db;

    String sql;
    switch (filter) {
      case PodcastEpisodeFilter.none:
        sql = 'SELECT pguid, COUNT(*) as cnt FROM episode GROUP BY pguid';
      case PodcastEpisodeFilter.played:
        sql = 'SELECT pguid, COUNT(*) as cnt FROM episode WHERE played = 1 GROUP BY pguid';
      case PodcastEpisodeFilter.notPlayed:
        sql = 'SELECT pguid, COUNT(*) as cnt FROM episode WHERE played = 0 GROUP BY pguid';
      case PodcastEpisodeFilter.started:
        sql = 'SELECT pguid, COUNT(*) as cnt FROM episode WHERE position > 0 GROUP BY pguid';
    }

    final rows = await db.rawQuery(sql);
    final counts = <String, int>{};
    for (var row in rows) {
      final pguid = row['pguid'] as String?;
      if (pguid != null) {
        counts[pguid] = (row['cnt'] as int?) ?? 0;
      }
    }
    return counts;
  }

  @override
  Future<int> findEpisodeCountByPodcastGuid(
    String pguid, {
    PodcastEpisodeFilter filter = PodcastEpisodeFilter.none,
    PodcastEpisodeSort sort = PodcastEpisodeSort.none,
  }) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM episode WHERE pguid = ? AND played = 0',
      [pguid],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<Episode?> findEpisodeByTaskId(String taskId) async {
    final db = await _db;
    final rows = await db.query('episode', where: 'downloadTaskId = ?', whereArgs: [taskId], limit: 1);
    if (rows.isEmpty) return null;
    return _loadEpisodeWithTranscript(rows.first);
  }

  @override
  Future<Episode?> findLatestPlayableEpisode(Podcast podcast) async {
    final db = await _db;
    final rows = await db.query(
      'episode',
      where: 'pguid = ?',
      whereArgs: [podcast.guid],
      orderBy: 'publicationDate DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _episodeFromRow(rows.first);
  }

  @override
  Future<Episode?> findNextUnplayedEpisode(Podcast podcast) async {
    final db = await _db;
    final rows = await db.query(
      'episode',
      where: 'pguid = ? AND played = 0',
      whereArgs: [podcast.guid],
      orderBy: 'publicationDate ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _episodeFromRow(rows.first);
  }

  @override
  Future<Episode?> findNextPlayableEpisode(Episode episode) async {
    if (episode.pguid == null) return null;

    final podcast = await findPodcastByGuid(episode.pguid!);
    if (podcast == null) return null;

    if (podcast.filter == PodcastEpisodeFilter.none) {
      final matchedIndex = podcast.episodes.indexWhere((e) => e.guid == episode.guid);
      if (matchedIndex != -1 && podcast.episodes.length > matchedIndex + 1) {
        final nextIndex = podcast.episodes.indexWhere((e) => !e.played, matchedIndex + 1);
        if (nextIndex != -1) return podcast.episodes[nextIndex];
      }
    } else {
      if (podcast.episodes.isNotEmpty) return podcast.episodes[0];
    }

    return null;
  }

  @override
  Future<Episode> saveEpisode(Episode episode, [bool updateIfSame = false]) async {
    final e = await _saveEpisode(episode, updateIfSame);
    _episodeSubject.add(EpisodeUpdateState(e));
    return e;
  }

  @override
  Future<List<Episode>> saveEpisodes(List<Episode> episodes, [bool updateIfSame = false]) async {
    final updated = <Episode>[];
    for (var e in episodes) {
      final saved = await _saveEpisode(e, updateIfSame);
      updated.add(saved);
      _episodeSubject.add(EpisodeUpdateState(saved));
    }
    return updated;
  }

  @override
  Future<void> deleteEpisode(Episode episode) async {
    final db = await _db;
    final count = await db.delete('episode', where: 'id = ?', whereArgs: [episode.id]);
    if (count > 0) {
      _episodeSubject.add(EpisodeDeleteState(episode));
    }
  }

  @override
  Future<void> deleteEpisodes(List<Episode> episodes) async {
    if (episodes.isEmpty) return;
    final db = await _db;
    final batch = db.batch();
    for (var e in episodes) {
      batch.delete('episode', where: 'id = ?', whereArgs: [e.id]);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<Episode>> findDownloadsByPodcastGuid(String pguid) async {
    final db = await _db;
    final rows = await db.query(
      'episode',
      where: 'pguid = ? AND downloadPercentage = 100',
      whereArgs: [pguid],
      orderBy: 'publicationDate DESC',
    );
    return rows.map((r) => _episodeFromRow(r)).toList();
  }

  @override
  Future<List<Episode>> findDownloads() async {
    final db = await _db;
    final rows = await db.query(
      'episode',
      where: 'downloadPercentage = 100',
      orderBy: 'publicationDate DESC',
    );
    return rows.map((r) => _episodeFromRow(r)).toList();
  }

  @override
  Future<List<Episode>> searchDownloads(String term) async {
    final db = await _db;
    final rows = await db.query(
      'episode',
      where: 'downloadPercentage = 100 AND title LIKE ? COLLATE NOCASE',
      whereArgs: ['%$term%'],
    );
    return rows.map((r) => _episodeFromRow(r)).toList();
  }

  // ---------------------------------------------------------------------------
  // Transcript CRUD
  // ---------------------------------------------------------------------------

  @override
  Future<Transcript?> findTranscriptById(int? id) async {
    final db = await _db;
    final rows = await db.query('transcript', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Transcript.fromMap(rows.first['id'] as int, _rowFromSqlite(rows.first));
  }

  @override
  Future<Transcript> saveTranscript(Transcript transcript) async {
    final db = await _db;
    transcript.lastUpdated = DateTime.now();
    final map = _sanitizeForSqlite(transcript.toMap());

    if (transcript.id == null || transcript.id == 0) {
      transcript.id = await db.insert('transcript', map);
    } else {
      await db.update('transcript', map, where: 'id = ?', whereArgs: [transcript.id]);
    }
    return transcript;
  }

  @override
  Future<void> deleteTranscriptById(int id) async {
    final db = await _db;
    await db.delete('transcript', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> deleteTranscriptsById(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await _db;
    final batch = db.batch();
    for (var id in ids) {
      batch.delete('transcript', where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  // ---------------------------------------------------------------------------
  // Queue
  // ---------------------------------------------------------------------------

  @override
  Future<void> saveQueue(List<Episode> episodes) async {
    final db = await _db;

    // Save any ad-hoc episodes first.
    for (var e in episodes) {
      if (e.pguid == null || e.pguid!.isEmpty) {
        await _saveEpisode(e, false);
      }
    }

    final guids = episodes.map((e) => e.guid).toList();

    if (!listEquals(guids, _queueGuids)) {
      await db.insert(
        'queue',
        {'id': 1, 'guids': jsonEncode(guids)},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _queueGuids
        ..clear()
        ..addAll(guids);
    }
  }

  @override
  Future<List<Episode>> loadQueue() async {
    final db = await _db;
    final rows = await db.query('queue', where: 'id = 1', limit: 1);
    if (rows.isEmpty) return [];

    final guidsRaw = rows.first['guids'] as String?;
    if (guidsRaw == null || guidsRaw.isEmpty) return [];

    final guids = (jsonDecode(guidsRaw) as List).cast<String>();
    final episodes = <Episode>[];
    for (var guid in guids) {
      final e = await findEpisodeByGuid(guid);
      if (e != null) episodes.add(e);
    }
    return episodes;
  }

  // ---------------------------------------------------------------------------
  // Bookmark CRUD
  // ---------------------------------------------------------------------------

  @override
  Future<List<Bookmark>> findAllBookmarks() async {
    final db = await _db;
    final rows = await db.query('bookmark', orderBy: 'createdAt DESC');
    return rows.map((r) => Bookmark.fromMap(r['id'] as int, _rowFromSqlite(r))).toList();
  }

  @override
  Future<List<Bookmark>> findBookmarksByEpisodeGuid(String episodeGuid) async {
    final db = await _db;
    final rows = await db.query(
      'bookmark',
      where: 'episodeGuid = ?',
      whereArgs: [episodeGuid],
      orderBy: 'positionMs ASC',
    );
    return rows.map((r) => Bookmark.fromMap(r['id'] as int, _rowFromSqlite(r))).toList();
  }

  @override
  Future<Bookmark> saveBookmark(Bookmark bookmark) async {
    final db = await _db;
    final map = bookmark.toMap();

    if (bookmark.id == null) {
      bookmark.id = await db.insert('bookmark', map);
    } else {
      await db.update('bookmark', map, where: 'id = ?', whereArgs: [bookmark.id]);
    }
    return bookmark;
  }

  @override
  Future<void> deleteBookmark(Bookmark bookmark) async {
    final db = await _db;
    await db.delete('bookmark', where: 'id = ?', whereArgs: [bookmark.id]);
  }

  @override
  Future<void> deleteBookmarksByEpisodeGuid(String episodeGuid) async {
    final db = await _db;
    await db.delete('bookmark', where: 'episodeGuid = ?', whereArgs: [episodeGuid]);
  }

  @override
  Future<List<Bookmark>> searchBookmarks(String term) async {
    final db = await _db;
    final rows = await db.query(
      'bookmark',
      where: 'episodeTitle LIKE ? OR podcastName LIKE ? OR note LIKE ? COLLATE NOCASE',
      whereArgs: ['%$term%', '%$term%', '%$term%'],
      orderBy: 'createdAt DESC',
    );
    return rows.map((r) => Bookmark.fromMap(r['id'] as int, _rowFromSqlite(r))).toList();
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  Future<List<Episode>> cleanupEpisodes() async {
    final db = await _db;
    final threshold = DateTime.now().subtract(const Duration(days: 60)).millisecondsSinceEpoch;

    final rows = await db.rawQuery('''
      SELECT e.* FROM episode e
      WHERE e.downloadState = 0
        AND e.lastUpdated < ?
        AND e.pguid NOT IN (SELECT guid FROM podcast)
      LIMIT 20
    ''', [threshold]);

    final orphaned = rows.map((r) => _episodeFromRow(r)).toList();
    if (orphaned.isNotEmpty) {
      await deleteEpisodes(orphaned);
    }
    return orphaned;
  }

  // ---------------------------------------------------------------------------
  // Event listeners
  // ---------------------------------------------------------------------------

  @override
  Stream<Podcast> get podcastListener => _podcastSubject.stream;

  @override
  Stream<EpisodeState> get episodeListener => _episodeSubject.stream;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> close() async {
    await _databaseService.close();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Converts List/Map values in [map] to JSON strings for SQLite storage.
  Map<String, dynamic> _sanitizeForSqlite(Map<String, dynamic> map) {
    final sanitized = <String, dynamic>{};
    for (var entry in map.entries) {
      final value = entry.value;
      if (value is List || value is Map) {
        sanitized[entry.key] = jsonEncode(value);
      } else if (value is bool) {
        sanitized[entry.key] = value ? 1 : 0;
      } else {
        sanitized[entry.key] = value;
      }
    }
    return sanitized;
  }

  /// Converts a SQLite row back to the format expected by entity `fromMap()`.
  /// - INTEGER fields that fromMap() expects as String → convert to String
  /// - JSON text fields that fromMap() expects as List → jsonDecode
  Map<String, dynamic> _rowFromSqlite(Map<String, dynamic> row) {
    final converted = <String, dynamic>{};
    for (var entry in row.entries) {
      var value = entry.value;
      if (value is int) {
        if (_intToStringFields.contains(entry.key)) {
          value = value.toString();
        } else if (_intToBoolStringFields.contains(entry.key)) {
          value = value == 1 ? 'true' : 'false';
        }
        // else: keep as int (downloadState, length, ne, tid, filter, sort, etc.)
      } else if (value is String && _jsonListFields.contains(entry.key)) {
        try {
          value = jsonDecode(value);
        } catch (_) {
          // Not valid JSON — leave as-is.
        }
      }
      converted[entry.key] = value;
    }
    return converted;
  }

  /// Fields that Podcast/Episode/Bookmark fromMap() expects as String
  /// but SQLite stores as INTEGER.
  /// Fields that fromMap() expects as String but SQLite stores as INTEGER.
  /// Based on actual cast types in Episode.fromMap and Podcast.fromMap.
  static const _intToStringFields = {
    'subscribedDate', 'publicationDate', 'season', 'episode',
    'duration', 'position', 'downloadPercentage',
    'positionMs', 'createdAt',
  };

  /// Fields that need int→'true'/'false' String conversion (Episode.played).
  static const _intToBoolStringFields = {'played'};

  /// Fields stored as JSON text that fromMap() expects as List.
  static const _jsonListFields = {
    'chapters', 'transcriptUrls', 'persons', 'person',
    'funding', 'subtitles', 'q',
  };


  /// Converts a database row to an [Episode], parsing nested JSON fields.
  Episode _episodeFromRow(Map<String, dynamic> r) {
    final map = _rowFromSqlite(r);
    // Episode.fromMap expects lastUpdated as String (unlike Podcast which expects int).
    // SQLite stores it as INTEGER, so convert for Episode only.
    if (map['lastUpdated'] is int) {
      map['lastUpdated'] = (map['lastUpdated'] as int).toString();
    }
    return Episode.fromMap(r['id'] as int, map);
  }

  /// Loads an episode and attaches its transcript if one exists.
  Future<Episode> _loadEpisodeWithTranscript(Map<String, dynamic> row) async {
    final episode = _episodeFromRow(row);
    if (episode.transcriptId != null && episode.transcriptId! > 0) {
      episode.transcript = await findTranscriptById(episode.transcriptId);
    }
    return episode;
  }

  /// Saves or updates a single episode.
  Future<Episode> _saveEpisode(Episode episode, bool updateIfSame) async {
    final db = await _db;
    episode.lastUpdated = DateTime.now();
    final map = _sanitizeForSqlite(episode.toMap());

    if (episode.id == null) {
      episode.id = await db.insert('episode', map);
    } else {
      if (!updateIfSame) {
        // Check if the episode has changed before writing.
        final existing = await db.query('episode', where: 'id = ?', whereArgs: [episode.id], limit: 1);
        if (existing.isNotEmpty) {
          final oldMap = _rowFromSqlite(existing.first);
          if (oldMap['lastUpdated'] is int) {
            oldMap['lastUpdated'] = (oldMap['lastUpdated'] as int).toString();
          }
          final old = Episode.fromMap(episode.id, oldMap);
          if (episode == old) return episode;
        }
      }
      await db.update('episode', map, where: 'id = ?', whereArgs: [episode.id]);
    }
    return episode;
  }

  /// Saves a list of episodes in a single batch transaction.
  Future<void> _saveEpisodes(List<Episode?>? episodes) async {
    if (episodes == null || episodes.isEmpty) return;

    final db = await _db;
    final dateStamp = DateTime.now();

    for (var chunk in episodes.whereType<Episode>().toList().chunk(100)) {
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (var episode in chunk) {
          episode.lastUpdated = dateStamp;
          final map = _sanitizeForSqlite(episode.toMap());
          if (episode.id == null) {
            batch.insert('episode', map);
          } else {
            batch.update('episode', map, where: 'id = ?', whereArgs: [episode.id]);
          }
        }
        await batch.commit(noResult: true);
      });
    }
  }

  /// Builds the WHERE clause for episode filtering by podcast and played state.
  (String, List<Object?>) _buildEpisodeFilterSql(PodcastEpisodeFilter filter, String? pguid) {
    switch (filter) {
      case PodcastEpisodeFilter.none:
        return ('pguid = ?', [pguid]);
      case PodcastEpisodeFilter.started:
        return ('pguid = ? AND position > 0', [pguid]);
      case PodcastEpisodeFilter.played:
        return ('pguid = ? AND played = 1', [pguid]);
      case PodcastEpisodeFilter.notPlayed:
        return ('pguid = ? AND played = 0', [pguid]);
    }
  }

  /// Builds the ORDER BY clause for episode sorting.
  String _buildEpisodeSortSql(PodcastEpisodeSort sort) {
    switch (sort) {
      case PodcastEpisodeSort.none:
      case PodcastEpisodeSort.latestFirst:
        return 'publicationDate DESC';
      case PodcastEpisodeSort.earliestFirst:
        return 'publicationDate ASC';
      case PodcastEpisodeSort.alphabeticalAscending:
        return 'title COLLATE NOCASE ASC';
      case PodcastEpisodeSort.alphabeticalDescending:
        return 'title COLLATE NOCASE DESC';
    }
  }
}

/// Extension to add chunking to lists (matching SembastRepository's usage).
extension _ListChunk<T> on List<T> {
  List<List<T>> chunk(int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < length; i += size) {
      chunks.add(sublist(i, i + size > length ? length : i + size));
    }
    return chunks;
  }
}

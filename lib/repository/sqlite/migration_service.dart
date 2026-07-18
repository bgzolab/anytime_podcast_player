// Copyright 2026 Anytime Podcast Player contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart' as sembast;
import 'package:sqflite/sqflite.dart' as sqflite;

/// One-shot migration from the legacy Sembast database to SQLite.
///
/// After a successful migration the Sembast file is renamed to
/// `*.sembast.bak` so it is no longer opened on subsequent launches.
class MigrationService {
  static final _log = Logger('MigrationService');

  /// Migrates all data from the Sembast file [sembastName] into the
  /// already-open SQLite [sqliteDb].  Returns `true` if migration was
  /// performed (i.e. the Sembast file existed), `false` if skipped.
  static Future<bool> migrate({
    required sqflite.Database sqliteDb,
    String sembastName = 'anytime.db',
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final sembastPath = join(dir.path, sembastName);
    final sembastFile = File(sembastPath);

    // Also check for the .bak file left by a previous successful migration
    // that the app crashed before consuming.
    final bakFile = File('$sembastPath.sembast.bak');
    if (!await sembastFile.exists() && !await bakFile.exists()) {
      _log.fine('No Sembast database found — skipping migration');
      return false;
    }

    // If the original file was already renamed, use the backup.
    final sourceFile = await sembastFile.exists() ? sembastFile : bakFile;
    final sourcePath = sourceFile.path;

    _log.fine('Starting Sembast → SQLite migration from $sourcePath');
    final sw = Stopwatch()..start();

    // Open the Sembast database (read-only intent).
    final sembastDb = await sembast.databaseFactoryIo.openDatabase(sourcePath);

    try {
      // --- Podcasts ---
      final podcastStore = sembast.intMapStoreFactory.store('podcast');
      final podcastSnapshots = await podcastStore.find(sembastDb);
      _log.fine('Migrating ${podcastSnapshots.length} podcasts');

      for (var snap in podcastSnapshots) {
        final map = _sanitizeMap(Map<String, dynamic>.from(snap.value));
        map['id'] = snap.key;
        await sqliteDb.insert('podcast', map, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
      }

      // --- Episodes ---
      final episodeStore = sembast.intMapStoreFactory.store('episode');
      final episodeSnapshots = await episodeStore.find(sembastDb);
      _log.fine('Migrating ${episodeSnapshots.length} episodes');

      // Batch-insert in chunks of 500 for memory efficiency.
      const chunkSize = 500;
      for (var i = 0; i < episodeSnapshots.length; i += chunkSize) {
        final end = (i + chunkSize > episodeSnapshots.length) ? episodeSnapshots.length : i + chunkSize;
        final batch = sqliteDb.batch();
        for (var j = i; j < end; j++) {
          final snap = episodeSnapshots[j];
          final map = _sanitizeMap(Map<String, dynamic>.from(snap.value));
          map['id'] = snap.key;
          batch.insert('episode', map, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
        _log.fine('  ... episodes $i..$end done');
      }

      // --- Transcripts ---
      final transcriptStore = sembast.intMapStoreFactory.store('transcript');
      final transcriptSnapshots = await transcriptStore.find(sembastDb);
      _log.fine('Migrating ${transcriptSnapshots.length} transcripts');

      for (var snap in transcriptSnapshots) {
        final map = _sanitizeMap(Map<String, dynamic>.from(snap.value));
        map['id'] = snap.key;
        await sqliteDb.insert('transcript', map, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
      }

      // --- Bookmarks ---
      final bookmarkStore = sembast.intMapStoreFactory.store('bookmark');
      final bookmarkSnapshots = await bookmarkStore.find(sembastDb);
      _log.fine('Migrating ${bookmarkSnapshots.length} bookmarks');

      for (var snap in bookmarkSnapshots) {
        final map = _sanitizeMap(Map<String, dynamic>.from(snap.value));
        map['id'] = snap.key;
        await sqliteDb.insert('bookmark', map, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
      }

      // --- Queue ---
      final queueStore = sembast.intMapStoreFactory.store('queue');
      final queueSnapshot = await queueStore.record(1).getSnapshot(sembastDb);
      if (queueSnapshot != null) {
        final map = Map<String, dynamic>.from(queueSnapshot.value);
        map['id'] = 1;
        await sqliteDb.insert('queue', map, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
        _log.fine('Migrated queue');
      }

      _log.fine('Migration completed in ${sw.elapsedMilliseconds}ms');

      // Rename Sembast file to .bak so it is not opened again.
      final bakPath = '$sembastPath.sembast.bak';
      if (sourceFile.path == sembastPath) {
        await sourceFile.rename(bakPath);
        _log.fine('Sembast file renamed to $bakPath');
      } else {
        _log.fine('Sembast backup already at $bakPath');
      }

      // Delete the .bak file so migration does not re-run on next launch.
      final bak = File(bakPath);
      if (await bak.exists()) {
        await bak.delete();
        _log.fine('Deleted Sembast backup file');
      }
    } finally {
      await sembastDb.close();
    }

    return true;
  }

  /// Converts List values in [map] to JSON strings so they can be stored
  /// in SQLite (which only supports num, String, and Uint8List).
  static Map<String, dynamic> _sanitizeMap(Map<String, dynamic> map) {
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
}

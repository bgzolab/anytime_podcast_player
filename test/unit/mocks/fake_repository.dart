// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/entities/bookmark.dart';
import 'package:anytime/entities/episode.dart';
import 'package:anytime/entities/podcast.dart';
import 'package:anytime/entities/transcript.dart';
import 'package:anytime/repository/repository.dart';
import 'package:anytime/state/episode_state.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeRepository extends Fake implements Repository {
  final List<Bookmark> _bookmarks = [];
  int _nextId = 1;

  @override
  Future<List<Bookmark>> findAllBookmarks() async {
    final sorted = List<Bookmark>.from(_bookmarks);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  @override
  Future<List<Bookmark>> findBookmarksByEpisodeGuid(String episodeGuid) async {
    final filtered = _bookmarks.where((b) => b.episodeGuid == episodeGuid).toList();
    filtered.sort((a, b) => a.positionMs.compareTo(b.positionMs));
    return filtered;
  }

  @override
  Future<Bookmark> saveBookmark(Bookmark bookmark) async {
    if (bookmark.id == null) {
      bookmark.id = _nextId++;
      _bookmarks.add(bookmark);
    } else {
      final index = _bookmarks.indexWhere((b) => b.id == bookmark.id);
      if (index >= 0) {
        _bookmarks[index] = bookmark;
      } else {
        _bookmarks.add(bookmark);
      }
    }
    return bookmark;
  }

  @override
  Future<void> deleteBookmark(Bookmark bookmark) async {
    _bookmarks.removeWhere((b) => b.id == bookmark.id);
  }

  @override
  Future<void> deleteBookmarksByEpisodeGuid(String episodeGuid) async {
    _bookmarks.removeWhere((b) => b.episodeGuid == episodeGuid);
  }

  // Unused methods required by Fake
  @override
  Future<void> close() async {}
  @override
  Future<Podcast?> findPodcastById(num id) async => null;
  @override
  Future<Podcast?> findPodcastByGuid(String guid) async => null;
  @override
  Future<Podcast> savePodcast(Podcast podcast, {bool withEpisodes = true}) async => podcast;
  @override
  Future<void> deletePodcast(Podcast podcast) async {}
  @override
  Future<List<Podcast>> subscriptions() async => [];
  @override
  Future<List<Episode>> findAllEpisodes() async => [];
  @override
  Future<List<Episode>> findEpisodesBefore(DateTime beforeDate, {int limit = 100}) async => [];
  @override
  Future<int> countEpisodesSince(DateTime sinceDate) async => 0;
  @override
  Future<Episode?> findEpisodeById(int id) async => null;
  @override
  Future<Episode?> findEpisodeByGuid(String guid) async => null;
  @override
  Future<List<Episode>> findEpisodesByPodcastGuid(String pguid,
          {PodcastEpisodeFilter filter = PodcastEpisodeFilter.none,
          PodcastEpisodeSort sort = PodcastEpisodeSort.none}) async =>
      [];
  @override
  Future<Map<String, int>> findEpisodeCountByPodcast({PodcastEpisodeFilter filter = PodcastEpisodeFilter.none}) async =>
      {};
  @override
  Future<int> findEpisodeCountByPodcastGuid(String pguid,
          {PodcastEpisodeFilter filter = PodcastEpisodeFilter.none,
          PodcastEpisodeSort sort = PodcastEpisodeSort.none}) async =>
      0;
  @override
  Future<Episode?> findEpisodeByTaskId(String taskId) async => null;
  @override
  Future<Episode?> findLatestPlayableEpisode(Podcast podcast) async => null;
  @override
  Future<Episode?> findNextUnplayedEpisode(Podcast podcast) async => null;
  @override
  Future<Episode?> findNextPlayableEpisode(Episode episode) async => null;
  @override
  Future<Episode> saveEpisode(Episode episode, [bool updateIfSame = false]) async => episode;
  @override
  Future<List<Episode>> saveEpisodes(List<Episode> episodes, [bool updateIfSame = false]) async => episodes;
  @override
  Future<void> deleteEpisode(Episode episode) async {}
  @override
  Future<void> deleteEpisodes(List<Episode> episodes) async {}
  @override
  Future<List<Episode>> findDownloadsByPodcastGuid(String pguid) async => [];
  @override
  Future<List<Episode>> findDownloads() async => [];
  @override
  Future<Transcript?> findTranscriptById(int id) async => null;
  @override
  Future<Transcript> saveTranscript(Transcript transcript) async => transcript;
  @override
  Future<void> deleteTranscriptById(int id) async {}
  @override
  Future<void> deleteTranscriptsById(List<int> id) async {}
  @override
  Future<void> saveQueue(List<Episode> episodes) async {}
  @override
  Future<List<Episode>> loadQueue() async => [];
  @override
  Stream<Podcast> get podcastListener => const Stream.empty();
  @override
  Stream<EpisodeState> get episodeListener => const Stream.empty();
}

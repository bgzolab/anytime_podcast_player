// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/entities/bookmark.dart';
import 'package:anytime/entities/episode.dart';
import 'package:anytime/entities/podcast.dart';
import 'package:anytime/entities/transcript.dart';
import 'package:anytime/state/episode_state.dart';

/// An abstract class that represent the actions supported by the chosen
/// database or storage implementation.
abstract class Repository {
  /// General
  Future<void> close();

  /// Podcasts
  Future<Podcast?> findPodcastById(num id);

  Future<Podcast?> findPodcastByGuid(String guid);

  Future<Podcast> savePodcast(Podcast podcast, {bool withEpisodes = true});

  Future<void> deletePodcast(Podcast podcast);

  Future<List<Podcast>> subscriptions();

  /// Search subscribed podcasts whose title contains [term] (case-insensitive).
  Future<List<Podcast>> searchPodcasts(String term);

  /// Episodes
  Future<List<Episode>> findAllEpisodes();

  /// Search episodes whose title contains [term] (case-insensitive).
  Future<List<Episode>> searchEpisodes(String term);

  /// Returns up to [limit] episodes whose [publicationDate] is strictly before
  /// [beforeDate], sorted newest-first. Used for cursor-based pagination.
  /// Returns up to [limit] episodes published before [beforeDate], newest
  /// first.
  ///
  /// [beforeId] is the row id of the last episode of the previous page and
  /// acts as a tie-breaker: a group of episodes sharing one publication date
  /// can then span pages without repeating or skipping entries.
  Future<List<Episode>> findEpisodesBefore(DateTime beforeDate, {int limit = 100, int? beforeId});

  /// Returns the number of episodes whose [publicationDate] is on or after
  /// [sinceDate]. Used to calculate the scroll offset for date-jump.
  Future<int> countEpisodesSince(DateTime sinceDate);

  Future<Episode?> findEpisodeById(int id);

  Future<Episode?> findEpisodeByGuid(String guid);

  Future<List<Episode>> findEpisodesByPodcastGuid(
    String pguid, {
    PodcastEpisodeFilter filter = PodcastEpisodeFilter.none,
    PodcastEpisodeSort sort = PodcastEpisodeSort.none,
  });

  Future<Map<String, int>> findEpisodeCountByPodcast({
    PodcastEpisodeFilter filter = PodcastEpisodeFilter.none,
  });

  Future<int> findEpisodeCountByPodcastGuid(
    String pguid, {
    PodcastEpisodeFilter filter = PodcastEpisodeFilter.none,
    PodcastEpisodeSort sort = PodcastEpisodeSort.none,
  });

  Future<Episode?> findEpisodeByTaskId(String taskId);

  Future<Episode?> findLatestPlayableEpisode(Podcast podcast);

  Future<Episode?> findNextUnplayedEpisode(Podcast podcast);

  Future<Episode?> findNextPlayableEpisode(Episode episode);

  Future<Episode> saveEpisode(Episode episode, [bool updateIfSame = false]);

  Future<List<Episode>> saveEpisodes(List<Episode> episodes, [bool updateIfSame = false]);

  Future<void> deleteEpisode(Episode episode);

  Future<void> deleteEpisodes(List<Episode> episodes);

  /// Removes a small batch of episodes that are not linked to any subscribed
  /// podcast and have not been updated for a while; returns the removed
  /// episodes.
  Future<List<Episode>> cleanupEpisodes();

  Future<List<Episode>> findDownloadsByPodcastGuid(String pguid);

  Future<List<Episode>> findDownloads();

  /// Search downloaded episodes whose title contains [term] (case-insensitive).
  Future<List<Episode>> searchDownloads(String term);

  Future<Transcript?> findTranscriptById(int id);

  Future<Transcript> saveTranscript(Transcript transcript);

  Future<void> deleteTranscriptById(int id);

  Future<void> deleteTranscriptsById(List<int> id);

  /// Queue
  Future<void> saveQueue(List<Episode> episodes);

  Future<List<Episode>> loadQueue();

  /// Bookmarks
  Future<List<Bookmark>> findAllBookmarks();

  Future<List<Bookmark>> findBookmarksByEpisodeGuid(String episodeGuid);

  Future<Bookmark> saveBookmark(Bookmark bookmark);

  Future<void> deleteBookmark(Bookmark bookmark);

  Future<void> deleteBookmarksByEpisodeGuid(String episodeGuid);

  /// Search bookmarks where episodeTitle, podcastName, or note contains
  /// [term] (case-insensitive).
  Future<List<Bookmark>> searchBookmarks(String term);

  /// Event listeners
  late Stream<Podcast> podcastListener;
  late Stream<EpisodeState> episodeListener;
}

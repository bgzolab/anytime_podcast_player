// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:anytime/entities/chapter.dart';
import 'package:anytime/entities/episode.dart';
import 'package:anytime/entities/persistable.dart';
import 'package:anytime/repository/repository.dart';
import 'package:anytime/services/audio/default_audio_player_service.dart';
import 'package:anytime/services/podcast/podcast_service.dart';
import 'package:anytime/services/settings/settings_service.dart';
import 'package:anytime/state/persistent_state.dart';
import 'package:anytime/state/queue_event_state.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../mocks/mock_path_provider.dart';

class _RecordingAudioHandler extends BaseAudioHandler {
  final List<MediaItem> played = <MediaItem>[];

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    played.add(mediaItem);
  }
}

class _FakeRepository implements Repository {
  final episodesById = <int, Episode>{};

  @override
  Future<Episode?> findEpisodeById(int id) async => episodesById[id];

  @override
  Future<Episode> saveEpisode(Episode episode, [bool updateIfSame = false]) async => episode;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class _FakePodcastService implements PodcastService {
  Future<List<Episode>> Function()? onLoadQueue;

  @override
  Future<List<Episode>> loadQueue() => onLoadQueue?.call() ?? Future.value(<Episode>[]);

  @override
  Future<List<Chapter>> loadChaptersByUrl({required String url}) async => <Chapter>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

/// A path provider backed by a per-test directory, so persisted state files
/// do not leak into the shared system temp directory.
class _TempPathProvider extends MockPathProvder {
  _TempPathProvider(this.directory);

  final Directory directory;

  @override
  Future<Directory> getApplicationDocumentsDirectory() async => directory;

  @override
  Future<String> getApplicationDocumentsPath() async => directory.path;

  @override
  Future<String> getApplicationSupportPath() async => directory.path;

  @override
  Future<String> getTemporaryPath() async => directory.path;
}

class _FakeSettingsService implements SettingsService {
  @override
  double get playbackSpeed => 1.0;

  @override
  bool get trimSilence => false;

  @override
  bool get volumeBoost => false;

  @override
  bool get autoPlay => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

/// Covers the playback requests that arrive while the platform audio service is
/// still initialising: the last request is replayed once it is ready, the
/// stored queue is loaded first so the replay cannot be overwritten, and
/// stop cancels a request that is still waiting.
void main() {
  late _FakeRepository repository;
  late _FakePodcastService podcastService;
  late _FakeSettingsService settingsService;
  late _RecordingAudioHandler handler;
  late Completer<AudioHandler> initialiser;

  setUp(() {
    repository = _FakeRepository();
    podcastService = _FakePodcastService();
    settingsService = _FakeSettingsService();
    handler = _RecordingAudioHandler();
    initialiser = Completer<AudioHandler>();
  });

  DefaultAudioPlayerService createService() => DefaultAudioPlayerService(
        repository: repository,
        settingsService: settingsService,
        podcastService: podcastService,
        audioServiceInitializer: () => initialiser.future,
      );

  Episode createEpisode(String guid, String title) => Episode(
        guid: guid,
        podcast: 'Test Podcast',
        title: title,
        contentUrl: 'https://example.com//$guid.mp3',
        imageUrl: 'https://example.com/$guid-art.jpg',
        chaptersUrl: 'https://example.com/$guid-chapters.json',
      );

  test('replays a playback request received during initialisation', () async {
    final episode = createEpisode('ep-1', 'Episode 1');
    final service = createService();

    await service.playEpisode(episode: episode);

    expect(handler.played, isEmpty, reason: 'nothing may play before the audio service is ready');

    initialiser.complete(handler);

    await pumpEventQueue();

    expect(handler.played, hasLength(1));
    expect(handler.played.single.extras!['eid'], episode.guid);
    // The URL is normalised before it reaches the player.
    expect(handler.played.single.id, 'https://example.com/ep-1.mp3');
  });

  test('only the last request received during initialisation is replayed', () async {
    final first = createEpisode('ep-1', 'Episode 1');
    final second = createEpisode('ep-2', 'Episode 2');
    final service = createService();

    await service.playEpisode(episode: first);
    await service.playEpisode(episode: second);

    initialiser.complete(handler);

    await pumpEventQueue();

    expect(handler.played, hasLength(1));
    expect(handler.played.single.extras!['eid'], second.guid);
  });

  test('stop during initialisation cancels the pending playback request', () async {
    final episode = createEpisode('ep-1', 'Episode 1');
    final service = createService();

    await service.playEpisode(episode: episode);
    await service.stop();

    initialiser.complete(handler);

    await pumpEventQueue();

    expect(handler.played, isEmpty);
  });

  test('the stored queue is loaded before the replay so it is not overwritten', () async {
    final episode = createEpisode('ep-1', 'Episode 1');
    final stored = Episode(guid: 'stored', podcast: 'Test Podcast', title: 'Stored episode');

    final storedQueue = Completer<List<Episode>>();
    podcastService.onLoadQueue = () => storedQueue.future;

    final queueStates = <QueueListState>[];
    final service = createService();
    service.queueState.listen(queueStates.add);
    await service.playEpisode(episode: episode);

    initialiser.complete(handler);
    await pumpEventQueue();

    // The replay must wait for the stored queue to load.
    expect(handler.played, isEmpty);

    storedQueue.complete(<Episode>[episode, stored]);
    await pumpEventQueue();

    expect(handler.played, hasLength(1));

    // The replayed episode was removed from the queue; a late overwrite by the
    // stored queue would put it back.
    expect(queueStates, isNotEmpty);
    expect(queueStates.last.queue.map((e) => e.guid), isNot(contains(episode.guid)));
  });

  test('a failed initialisation drops the pending request and reports 501', () async {
    final episode = createEpisode('ep-1', 'Episode 1');
    final service = createService();

    final errors = <int>[];
    service.playbackError.listen(errors.add);

    await service.playEpisode(episode: episode);

    initialiser.completeError(StateError('no platform audio service'));
    await pumpEventQueue();

    expect(handler.played, isEmpty);
    expect(errors, contains(501));

    // The error is latched for a listener that is not mounted yet, and can be
    // marked as shown.
    expect(service.pendingPlaybackError, 501);
    service.clearPendingPlaybackError();
    expect(service.pendingPlaybackError, isNull);
  });

  test('a play request during initialisation plays the restored episode', () async {
    final previousPathProvider = PathProviderPlatform.instance;
    final tempDirectory = Directory.systemTemp.createTempSync('anytime_audio_replay_');
    PathProviderPlatform.instance = _TempPathProvider(tempDirectory);

    addTearDown(() async {
      // Clear while the temp provider is still installed: restoring the
      // default provider first would use the platform channel, which no test
      // binding initialises here.
      await PersistentState.clearState();

      PathProviderPlatform.instance = previousPathProvider;

      if (tempDirectory.existsSync()) {
        tempDirectory.deleteSync(recursive: true);
      }
    });

    final restored = createEpisode('ep-restored', 'Restored episode');
    repository.episodesById[42] = restored;

    await PersistentState.persistState(Persistable(pguid: '', episodeId: 42, position: 100, state: LastState.paused));

    final service = createService();

    // Nothing is playing yet (resume has not restored the episode) but the tap
    // must not be dropped: the replay awaits resume() and then plays.
    await service.play();

    initialiser.complete(handler);
    await pumpEventQueue();

    expect(handler.played, hasLength(1));
    expect(handler.played.single.extras!['eid'], 'ep-restored');
  });
}

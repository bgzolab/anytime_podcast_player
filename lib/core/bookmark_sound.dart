// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';

/// Plays a short sound effect when a bookmark is created.
///
/// Uses a dedicated [AudioPlayer] instance to avoid interfering with
/// the main podcast playback.
class BookmarkSound {
  static final _log = Logger('BookmarkSound');
  static AudioPlayer? _player;
  static bool _prepared = false;
  static bool _playing = false;

  /// Play the bookmark creation sound effect.
  ///
  /// The asset is loaded once and reused; calls that arrive while the sound is
  /// still playing are ignored so rapid taps cannot interrupt each other.
  static Future<void> play() async {
    if (_playing) return;

    _playing = true;

    try {
      final player = _player ??= AudioPlayer();

      if (!_prepared) {
        await player.setAsset('assets/notification/water-drop.mp3');
        _prepared = true;
      }

      await player.seek(Duration.zero);
      await player.play();
    } catch (e) {
      _log.warning('Failed to play bookmark sound: $e');
    } finally {
      _playing = false;
    }
  }

  /// Dispose the player when the app shuts down.
  static void dispose() {
    _player?.dispose();
    _player = null;
    _prepared = false;
    _playing = false;
  }
}

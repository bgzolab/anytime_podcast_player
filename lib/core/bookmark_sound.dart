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

  /// Play the bookmark creation sound effect.
  static Future<void> play() async {
    try {
      _player ??= AudioPlayer();
      await _player!.setAsset('assets/notification/water-drop.mp3');
      await _player!.play();
    } catch (e) {
      _log.warning('Failed to play bookmark sound: $e');
    }
  }

  /// Dispose the player when the app shuts down.
  static void dispose() {
    _player?.dispose();
    _player = null;
  }
}

// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/entities/episode.dart';

abstract class DownloadService {
  /// Whether downloads are supported on the current platform.
  bool get supported;

  Future<bool> downloadEpisode(Episode episode);

  Future<Episode?> findEpisodeByTaskId(String taskId);

  void dispose();
}

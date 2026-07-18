// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// An object that represents a bookmark at a specific playback position
/// within an episode.
class Bookmark {
  /// Database ID
  int? id;

  /// The GUID of the episode this bookmark belongs to.
  final String episodeGuid;

  /// The title of the episode (denormalized for display convenience).
  final String? episodeTitle;

  /// The name of the podcast (denormalized for display convenience).
  final String? podcastName;

  /// The GUID of the podcast (denormalized for lookup convenience).
  final String? podcastGuid;

  /// The bookmark position within the episode in milliseconds.
  final int positionMs;

  /// An optional user-provided note for this bookmark.
  final String? note;

  /// The date and time this bookmark was created.
  final DateTime createdAt;

  Bookmark({
    this.id,
    required this.episodeGuid,
    this.episodeTitle,
    this.podcastName,
    this.podcastGuid,
    required this.positionMs,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'episodeGuid': episodeGuid,
      'episodeTitle': episodeTitle,
      'podcastName': podcastName,
      'podcastGuid': podcastGuid,
      'positionMs': positionMs.toString(),
      'note': note,
      'createdAt': createdAt.millisecondsSinceEpoch.toString(),
    };
  }

  static Bookmark fromMap(int? key, Map<String, dynamic> map) {
    return Bookmark(
      id: key,
      episodeGuid: map['episodeGuid'] as String,
      episodeTitle: map['episodeTitle'] as String?,
      podcastName: map['podcastName'] as String?,
      podcastGuid: map['podcastGuid'] as String?,
      positionMs: int.parse(map['positionMs'] as String),
      note: map['note'] as String?,
      createdAt: map['createdAt'] == null || map['createdAt'] == 'null'
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(int.parse(map['createdAt'] as String)),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Bookmark &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            episodeGuid == other.episodeGuid &&
            episodeTitle == other.episodeTitle &&
            podcastName == other.podcastName &&
            podcastGuid == other.podcastGuid &&
            positionMs == other.positionMs &&
            note == other.note &&
            createdAt.millisecondsSinceEpoch == other.createdAt.millisecondsSinceEpoch;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      episodeGuid.hashCode ^
      episodeTitle.hashCode ^
      podcastName.hashCode ^
      podcastGuid.hashCode ^
      positionMs.hashCode ^
      note.hashCode ^
      createdAt.hashCode;

  @override
  String toString() {
    return 'Bookmark{id: $id, episodeGuid: $episodeGuid, episodeTitle: $episodeTitle, '
        'podcastName: $podcastName, positionMs: $positionMs, note: $note, createdAt: $createdAt}';
  }
}

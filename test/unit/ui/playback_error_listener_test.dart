// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/bloc/podcast/audio_bloc.dart';
import 'package:anytime/l10n/L.dart';
import 'package:anytime/services/audio/audio_player_service.dart';
import 'package:anytime/ui/podcast/playback_error_listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

class _FakeAudioPlayerService extends Fake implements AudioPlayerService {
  final errorController = PublishSubject<int>();
  int? pending;

  @override
  Stream<int>? get playbackError => errorController.stream;

  @override
  int? get pendingPlaybackError => pending;

  @override
  void clearPendingPlaybackError() => pending = null;
}

void main() {
  testWidgets('a latched playback error is shown once', (tester) async {
    final service = _FakeAudioPlayerService()..pending = 501;
    final audioBloc = AudioBloc(audioPlayerService: service);

    addTearDown(() {
      audioBloc.dispose();
      service.errorController.close();
    });

    Widget wrap() {
      return MaterialApp(
        localizationsDelegates: const [AnytimeLocalisationsDelegate()],
        supportedLocales: const [Locale('en')],
        home: Provider<AudioBloc>.value(
          value: audioBloc,
          child: const Scaffold(body: PlaybackErrorListener(child: SizedBox())),
        ),
      );
    }

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // The error happened before this listener existed (e.g. playback is not
    // supported on the platform); it is reported and the latch cleared.
    expect(service.pending, isNull);
    expect(find.byType(SnackBar), findsOneWidget);

    // Re-mounting the listener must not show the same error again.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
  });
}

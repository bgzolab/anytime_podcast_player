// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:anytime/l10n/L.dart';
import 'package:anytime/repository/repository.dart';
import 'package:anytime/ui/library/downloads.dart';
import 'package:anytime/ui/search/search.dart';
import 'package:anytime/ui/search/search_mode.dart';
import 'package:anytime/ui/widgets/search_slide_route.dart';
import 'package:flutter/material.dart';

/// Full-screen Downloads page. Pushed as a separate route from MyPage.
class DownloadsPage extends StatefulWidget {
  final Repository? repository;

  const DownloadsPage({super.key, this.repository});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L.of(context)!.downloads),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: L.of(context)!.search_episodes_tooltip,
            onPressed: () async {
              await Navigator.push(
                context,
                defaultTargetPlatform == TargetPlatform.iOS
                    ? MaterialPageRoute<void>(
                        fullscreenDialog: false,
                        settings: const RouteSettings(name: 'search'),
                        builder: (context) => Search(mode: SearchMode.download, repository: widget.repository),
                      )
                    : SlideRightRoute(
                        widget: Search(mode: SearchMode.download, repository: widget.repository),
                        settings: const RouteSettings(name: 'search'),
                      ),
              );
            },
          ),
        ],
      ),
      body: const CustomScrollView(
        slivers: [
          Downloads(),
        ],
      ),
    );
  }
}

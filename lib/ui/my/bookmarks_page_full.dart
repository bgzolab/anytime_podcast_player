// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:anytime/l10n/L.dart';
import 'package:anytime/repository/repository.dart';
import 'package:anytime/ui/library/bookmarks_page.dart';
import 'package:anytime/ui/search/search.dart';
import 'package:anytime/ui/search/search_mode.dart';
import 'package:anytime/ui/widgets/search_slide_route.dart';
import 'package:flutter/material.dart';

/// Full-screen Bookmarks page. Pushed as a separate route from MyPage.
class BookmarksPageFull extends StatefulWidget {
  final Repository? repository;

  const BookmarksPageFull({super.key, this.repository});

  @override
  State<BookmarksPageFull> createState() => _BookmarksPageFullState();
}

class _BookmarksPageFullState extends State<BookmarksPageFull> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L.of(context)!.bookmarks_label),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: L.of(context)!.search_bookmarks_tooltip,
            onPressed: () async {
              await Navigator.push(
                context,
                defaultTargetPlatform == TargetPlatform.iOS
                    ? MaterialPageRoute<void>(
                        fullscreenDialog: false,
                        settings: const RouteSettings(name: 'search'),
                        builder: (context) => Search(mode: SearchMode.my, repository: widget.repository),
                      )
                    : SlideRightRoute(
                        widget: Search(mode: SearchMode.my, repository: widget.repository),
                        settings: const RouteSettings(name: 'search'),
                      ),
              );
            },
          ),
        ],
      ),
      body: const CustomScrollView(
        slivers: [
          BookmarksPage(),
        ],
      ),
    );
  }
}

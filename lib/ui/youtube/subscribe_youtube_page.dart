// Copyright 2026 Anytime Podcast Player contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/entities/podcast.dart';
import 'package:anytime/services/youtube/youtube_rss_service.dart';
import 'package:anytime/services/youtube/youtube_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Page for subscribing to a YouTube channel by pasting a URL or channel ID.
///
/// The user enters a YouTube channel URL (e.g. `youtube.com/@channelname`
/// or `youtube.com/channel/UC...`) or just the channel ID. The page
/// resolves the channel, shows a preview, and allows subscribing.
class SubscribeYouTubePage extends StatefulWidget {
  const SubscribeYouTubePage({super.key});

  @override
  State<SubscribeYouTubePage> createState() => _SubscribeYouTubePageState();
}

class _SubscribeYouTubePageState extends State<SubscribeYouTubePage> {
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  var _loading = false;
  String? _errorMessage;
  Podcast? _previewPodcast;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = _strings(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l['title']!),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // URL input.
              TextFormField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: l['hint'],
                  hintText: 'youtube.com/@channelname',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.link),
                  suffixIcon: _urlController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _urlController.clear();
                            setState(() {
                              _previewPodcast = null;
                              _errorMessage = null;
                            });
                          },
                        )
                      : null,
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _preview(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l['validation_empty'];
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Preview button.
              ElevatedButton.icon(
                onPressed: _loading ? null : _preview,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(l['preview']!),
              ),

              // Error message.
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_errorMessage!)),
                      ],
                    ),
                  ),
                ),
              ],

              // Preview card.
              if (_previewPodcast != null) ...[
                const SizedBox(height: 24),
                _buildPreview(context, _previewPodcast!, l),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context, Podcast podcast, Map<String, String?> l) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Artwork.
            if (podcast.imageUrl != null && podcast.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  podcast.imageUrl!,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.podcasts, size: 80),
                ),
              ),

            const SizedBox(height: 12),

            // Title.
            Text(
              podcast.title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),

            if (podcast.description != null && podcast.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                podcast.description!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 8),

            // Episode count.
            Text(
              '${podcast.episodes.length} ${l['episodes']}',
              style: Theme.of(context).textTheme.bodySmall,
            ),

            const SizedBox(height: 16),

            // Subscribe button.
            FilledButton.icon(
              onPressed: _loading ? null : () => _subscribe(podcast),
              icon: const Icon(Icons.add),
              label: Text(l['subscribe']!),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _preview() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
      _previewPodcast = null;
    });

    try {
      final input = _urlController.text.trim();

      // Try to resolve channel handle to ID.
      final youtubeService = context.read<YouTubeService>();
      final rssService = context.read<YouTubeRssService>();
      String? channelId;

      // Extract directly if it's a channel ID or channel URL.
      final directId = _extractChannelId(input);
      if (directId != null) {
        channelId = directId;
      } else {
        channelId = await youtubeService.resolveChannelId(input);
      }

      if (channelId == null) {
        setState(() {
          _errorMessage = _strings(context)['error_resolve']!;
          _loading = false;
        });
        return;
      }

      // Fetch the channel's RSS feed for preview.

      final podcast = await rssService.fetchChannel(channelId);

      setState(() {
        _previewPodcast = podcast;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  void _subscribe(Podcast podcast) {
    // Navigate back with the podcast so the caller can subscribe.
    Navigator.of(context).pop(podcast);
  }

  /// Extracts a YouTube channel ID from user input.
  static String? _extractChannelId(String input) {
    if (RegExp(r'^UC[A-Za-z0-9_-]{22}$').hasMatch(input.trim())) {
      return input.trim();
    }
    final match = RegExp(r'channel/(UC[A-Za-z0-9_-]{22})').firstMatch(input);
    return match?.group(1);
  }

  Map<String, String?> _strings(BuildContext context) {
    // Localized strings with English fallbacks.
    // TODO: Replace with actual l10n when TASK-027+ are implemented.
    return {
      'title': 'Subscribe to YouTube',
      'hint': 'Paste channel URL or ID',
      'preview': 'Preview',
      'subscribe': 'Subscribe',
      'episodes': 'episodes',
      'validation_empty': 'Please enter a YouTube channel URL',
      'error_resolve': 'Could not find this YouTube channel. Check the URL and try again.',
      'subscribed': 'Subscribed to {name}',
    };
  }
}

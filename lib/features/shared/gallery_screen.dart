// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
import '../../data/seed/content_seed.dart';
import '../../widgets/common.dart';

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Impact gallery'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Our purpose in action — clean-ups, workshops and drives across Pondicherry.', style: text.bodyLarge),
                      const SizedBox(height: 4),
                      Text('Sample photos for the pilot. Partner NGOs replace them with photos from their own events.',
                          style: text.bodySmall),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 360,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _Tile(item: ContentSeed.gallery[i]),
                    childCount: ContentSeed.gallery.length,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item});
  final GalleryItem item;

  void _open(BuildContext context) {
    unawaited(Navigator.of(context).push(PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      barrierLabel: 'Close photo',
      pageBuilder: (context, a1, a2) => _Viewer(item: item),
      transitionsBuilder: (context, a, _, child) => FadeTransition(opacity: a, child: child),
    )));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '${item.title}. ${item.description}. Open photo.',
      onTap: () => _open(context),
      child: ExcludeSemantics(
        child: Material(
          borderRadius: BorderRadius.circular(AqRadius.card),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _open(context),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(tag: 'gallery-${item.id}', child: AdaptiveImage(seed: item.imageSeed, alt: item.title, width: 600, height: 760)),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xD9081A22)],
                      stops: [0.45, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: text.titleMedium?.copyWith(color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Viewer extends StatelessWidget {
  const _Viewer({required this.item});
  final GalleryItem item;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop()},
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            leading: IconButton(tooltip: 'Close photo', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
          ),
          body: Column(
            children: [
              Expanded(
                child: InteractiveViewer(
                  child: Center(
                    child: Hero(tag: 'gallery-${item.id}', child: AdaptiveImage(seed: item.imageSeed, alt: 'Sample photo for ${item.title}', width: 1200, height: 1500, fit: BoxFit.contain)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: Column(
                  children: [
                    Text(item.title, style: text.titleLarge?.copyWith(color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(item.description, textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

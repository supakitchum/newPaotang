import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../data/news_models.dart';
import '../data/news_repository.dart';
import 'news_visual_tokens.dart';

class AnnouncementModalHost extends ConsumerStatefulWidget {
  const AnnouncementModalHost({
    required this.router,
    required this.child,
    super.key,
  });

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<AnnouncementModalHost> createState() =>
      _AnnouncementModalHostState();
}

class _AnnouncementModalHostState extends ConsumerState<AnnouncementModalHost> {
  bool _loaded = false;
  bool _visible = false;
  NewsItem? _announcement;

  @override
  void initState() {
    super.initState();
    widget.router.routeInformationProvider.addListener(_handleRouteChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadModal());
  }

  @override
  void didUpdateWidget(covariant AnnouncementModalHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router.routeInformationProvider ==
        widget.router.routeInformationProvider) {
      return;
    }
    oldWidget.router.routeInformationProvider.removeListener(
      _handleRouteChanged,
    );
    widget.router.routeInformationProvider.addListener(_handleRouteChanged);
  }

  @override
  void dispose() {
    widget.router.routeInformationProvider.removeListener(_handleRouteChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_visible && _announcementImageUrl(_announcement).isNotEmpty)
          _AnnouncementModalOverlay(
            announcement: _announcement!,
            onClose: _close,
            onOpenDetail: _openDetail,
          ),
      ],
    );
  }

  Future<void> _loadModal() async {
    if (_loaded) return;
    setState(() => _loaded = true);
    if (_shouldSuppress(_currentPath)) return;

    try {
      final announcement = await ref.read(newsRepositoryProvider).modal();
      if (!mounted || announcement == null || _shouldSuppress(_currentPath)) {
        return;
      }
      setState(() {
        _announcement = announcement;
        _visible = true;
      });
    } catch (_) {
      // Announcement modal must never block the app shell.
    }
  }

  void _handleRouteChanged() {
    if (_visible && _shouldSuppress(_currentPath)) {
      setState(() => _visible = false);
    }
    if (!_loaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadModal());
    }
  }

  void _close() {
    if (!_visible) return;
    setState(() => _visible = false);
  }

  void _openDetail() {
    final announcement = _announcement;
    if (announcement == null) return;

    final slug = announcement.slug.trim();
    _close();
    if (slug.isNotEmpty) {
      widget.router.go('/news/${Uri.encodeComponent(slug)}');
    }
  }

  String get _currentPath {
    final value = widget.router.routeInformationProvider.value.uri.path;
    return value.isEmpty ? '/' : value;
  }
}

class _AnnouncementModalOverlay extends StatelessWidget {
  const _AnnouncementModalOverlay({
    required this.announcement,
    required this.onClose,
    required this.onOpenDetail,
  });

  final NewsItem announcement;
  final VoidCallback onClose;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _announcementImageUrl(announcement);
    final title = announcement.title.isEmpty
        ? context.l10n.newsFallbackTitle
        : announcement.title;

    return Positioned.fill(
      child: ColoredBox(
        color: newsNuxtModalOverlay,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth <= 420 ? 22.0 : 24.0;
            final verticalPadding = constraints.maxWidth <= 420 ? 20.0 : 24.0;
            final maxHeight = math.min(constraints.maxHeight * 0.78, 760.0);

            return SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onClose,
                    ),
                  ),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: verticalPadding,
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Semantics(
                              button: true,
                              label: title,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: newsNuxtModalImageShadow,
                                      blurRadius: 44,
                                      offset: const Offset(0, 20),
                                    ),
                                  ],
                                ),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    key: const Key(
                                      'announcement-modal-image-button',
                                    ),
                                    behavior: HitTestBehavior.opaque,
                                    onTap: onOpenDetail,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxHeight: maxHeight,
                                        ),
                                        child: Image.network(
                                          imageUrl,
                                          fit: BoxFit.contain,
                                          width: double.infinity,
                                          frameBuilder: (
                                            context,
                                            child,
                                            frame,
                                            wasSynchronouslyLoaded,
                                          ) {
                                            if (wasSynchronouslyLoaded ||
                                                frame != null) {
                                              return child;
                                            }
                                            return const NewsImageLoadingFrame(
                                              aspectRatio: 1,
                                            );
                                          },
                                          errorBuilder: (context, _, __) =>
                                              const AspectRatio(
                                            aspectRatio: 1,
                                            child: NewsFallbackArtwork(
                                              iconSize: 52,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: constraints.maxWidth <= 420 ? -12 : -14,
                              top: constraints.maxWidth <= 420 ? -12 : -14,
                              child: Semantics(
                                button: true,
                                label: context.l10n.newsModalClose,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    key: const Key(
                                      'announcement-modal-close-button',
                                    ),
                                    behavior: HitTestBehavior.opaque,
                                    onTap: onClose,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: newsNuxtSurface,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: newsNuxtModalCloseShadow,
                                            blurRadius: 20,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: SizedBox.square(
                                        dimension: constraints.maxWidth <= 420
                                            ? 40
                                            : 44,
                                        child: Icon(
                                          Icons.close,
                                          color: newsNuxtModalCloseForeground,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

String _announcementImageUrl(NewsItem? announcement) {
  if (announcement == null) return '';
  return announcement.detailImageUrl.isNotEmpty
      ? announcement.detailImageUrl
      : announcement.coverUrl;
}

bool shouldSuppressAnnouncementModal(String path) {
  return path == '/news' ||
      path.startsWith('/news/') ||
      path.startsWith('/maintenance');
}

bool _shouldSuppress(String path) => shouldSuppressAnnouncementModal(path);

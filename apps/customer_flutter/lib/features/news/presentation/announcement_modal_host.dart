import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_link_launcher.dart';
import '../data/news_models.dart';
import '../data/news_repository.dart';
import 'news_card.dart';
import 'news_link_target.dart';
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
  String _noticeMessage = '';
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
        if (_visible && _announcement?.coverUrl.isNotEmpty == true)
          _AnnouncementModalOverlay(
            announcement: _announcement!,
            noticeMessage: _noticeMessage,
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
        _noticeMessage = '';
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
    setState(() {
      _visible = false;
      _noticeMessage = '';
    });
  }

  void _openDetail() {
    final announcement = _announcement;
    if (announcement == null) return;

    final internalPath = newsInternalPath(announcement);
    final externalUri = newsExternalUri(announcement);

    if (internalPath != null) {
      _close();
      widget.router.go(internalPath);
      return;
    }

    if (externalUri != null) {
      setState(() => _noticeMessage = '');
      unawaited(_openExternalNews(externalUri));
      return;
    }

    _close();
  }

  Future<void> _openExternalNews(Uri uri) async {
    final opened = await ref.read(customerLinkLauncherProvider).openExternal(
          uri,
        );
    if (!mounted) return;
    if (opened) {
      setState(() {
        _visible = false;
        _noticeMessage = '';
      });
      return;
    }
    setState(() => _noticeMessage = context.l10n.newsOpenFailed);
  }

  String get _currentPath {
    final value = widget.router.routeInformationProvider.value.uri.path;
    return value.isEmpty ? '/' : value;
  }
}

class _AnnouncementModalOverlay extends StatelessWidget {
  const _AnnouncementModalOverlay({
    required this.announcement,
    required this.noticeMessage,
    required this.onClose,
    required this.onOpenDetail,
  });

  final NewsItem announcement;
  final String noticeMessage;
  final VoidCallback onClose;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final imageUrl = announcement.coverUrl;
    final title = announcement.title.isEmpty
        ? context.l10n.newsFallbackTitle
        : announcement.title;

    return Positioned.fill(
      child: Material(
        color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.62),
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
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Semantics(
                                  button: true,
                                  label: title,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.scrim.withValues(
                                                alpha: 0.28,
                                              ),
                                          blurRadius: 44,
                                          offset: const Offset(0, 20),
                                        ),
                                      ],
                                    ),
                                    child: InkWell(
                                      key: const Key(
                                        'announcement-modal-image-button',
                                      ),
                                      borderRadius: BorderRadius.circular(8),
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
                                if (noticeMessage.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  NewsInlineNotice(message: noticeMessage),
                                ],
                              ],
                            ),
                            Positioned(
                              right: constraints.maxWidth <= 420 ? -12 : -14,
                              top: constraints.maxWidth <= 420 ? -12 : -14,
                              child: Semantics(
                                button: true,
                                label: context.l10n.newsModalClose,
                                child: Material(
                                  color: Theme.of(context).colorScheme.surface,
                                  shape: const CircleBorder(),
                                  elevation: 8,
                                  shadowColor: Theme.of(
                                    context,
                                  ).colorScheme.scrim.withValues(
                                        alpha: 0.22,
                                      ),
                                  child: InkWell(
                                    key: const Key(
                                      'announcement-modal-close-button',
                                    ),
                                    customBorder: const CircleBorder(),
                                    onTap: onClose,
                                    child: SizedBox.square(
                                      dimension:
                                          constraints.maxWidth <= 420 ? 40 : 44,
                                      child: Icon(
                                        Icons.close,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                        size: 24,
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

bool shouldSuppressAnnouncementModal(String path) {
  return path == '/news' ||
      path.startsWith('/news/') ||
      path.startsWith('/maintenance');
}

bool _shouldSuppress(String path) => shouldSuppressAnnouncementModal(path);

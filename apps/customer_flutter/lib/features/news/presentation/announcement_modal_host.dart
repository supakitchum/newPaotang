import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../data/news_models.dart';
import '../data/news_repository.dart';

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
        if (_visible && _announcement?.coverUrl.isNotEmpty == true)
          _AnnouncementModalOverlay(
            announcement: _announcement!,
            onClose: _close,
            onOpenDetail: _openDetail,
          ),
      ],
    );
  }

  Future<void> _loadModal() async {
    if (_loaded || _shouldSuppress(_currentPath)) return;
    setState(() => _loaded = true);

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
    final slug = _announcement?.slug.trim() ?? '';
    _close();
    if (slug.isEmpty) return;
    widget.router.go('/news/${Uri.encodeComponent(slug)}');
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
    final imageUrl = announcement.coverUrl;
    final title = announcement.title.isEmpty
        ? context.l10n.newsFallbackTitle
        : announcement.title;

    return Positioned.fill(
      child: Material(
        color: Colors.black.withAlpha(158),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Semantics(
                      button: true,
                      label: title,
                      child: InkWell(
                        key: const Key('announcement-modal-image-button'),
                        borderRadius: BorderRadius.circular(10),
                        onTap: onOpenDetail,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
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
                              if (wasSynchronouslyLoaded || frame != null) {
                                return child;
                              }
                              return const AspectRatio(
                                aspectRatio: 1,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                            errorBuilder: (context, _, __) => AspectRatio(
                              aspectRatio: 1,
                              child: ColoredBox(
                                color: Theme.of(context).colorScheme.surface,
                                child: Icon(
                                  Icons.campaign_outlined,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 52,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -14,
                      top: -14,
                      child: Semantics(
                        button: true,
                        label: context.l10n.newsModalClose,
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          shape: const CircleBorder(),
                          elevation: 8,
                          child: InkWell(
                            key: const Key('announcement-modal-close-button'),
                            customBorder: const CircleBorder(),
                            onTap: onClose,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Icon(
                                Icons.close,
                                color: Theme.of(context).colorScheme.onSurface,
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

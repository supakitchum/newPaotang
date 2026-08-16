import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_errors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../data/customer_notification_models.dart';
import '../data/customer_notification_repository.dart';
import 'customer_notification_navigation.dart';
import 'customer_notification_realtime_monitor.dart';

class CustomerNotificationsScreen extends ConsumerStatefulWidget {
  const CustomerNotificationsScreen({super.key, this.markAllOnOpen = true});

  final bool markAllOnOpen;

  @override
  ConsumerState<CustomerNotificationsScreen> createState() =>
      _CustomerNotificationsScreenState();
}

class _CustomerNotificationsScreenState
    extends ConsumerState<CustomerNotificationsScreen> {
  final _items = <CustomerNotificationItem>[];
  String _cursor = '';
  bool _hasMore = false;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  bool _refreshing = false;
  bool _realtimeRefreshPending = false;
  bool _markingAll = false;
  int _unreadCount = 0;
  String _error = '';
  String _inlineError = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadInitial(markAllOnOpen: widget.markAllOnOpen));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ref.listen<int>(
      customerNotificationRealtimeTickProvider,
      (_, __) => _scheduleRealtimeRefresh(),
    );

    return AppShell(
      title: l10n.notificationsTitle,
      currentPath: '/notifications',
      backPath: '/',
      sensitive: true,
      showBottomNavigation: false,
      compactHeader: true,
      heroContent: const SizedBox.shrink(),
      heroMinHeight: customerReferenceCompactHeroHeight,
      heroSheetOverlap: 0,
      heroContentTopGap: 0,
      child: _NotificationPageBody(child: _buildContent(context)),
    );
  }

  Widget _buildContent(BuildContext context) {
    final l10n = context.l10n;
    if (_loadingInitial) {
      return const _NotificationLoading();
    }
    if (_error.isNotEmpty) {
      return _NotificationError(
        message: _error,
        onRetry: () => _loadInitial(showLoading: true),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadInitial(showLoading: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [_NotificationEmpty()],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadInitial(showLoading: false),
      child: ListView(
        key: const ValueKey('customer-notification-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.notificationsInboxLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.appInk,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  key: const ValueKey('customer-notification-read-all'),
                  onPressed: _unreadCount == 0 || _markingAll
                      ? null
                      : _markAllRead,
                  child: Text(
                    _markingAll
                        ? l10n.notificationsMarkingAll
                        : l10n.notificationsMarkAll,
                  ),
                ),
              ],
            ),
          ),
          if (_inlineError.isNotEmpty)
            _NotificationInlineError(
              message: _inlineError,
              onRetry: () => _loadInitial(showLoading: false),
            ),
          for (final item in _items)
            _NotificationTile(
              key: ValueKey('customer-notification-${item.id}'),
              item: item,
              onTap: () => _open(item),
            ),
          if (_hasMore)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: OutlinedButton(
                onPressed: _loadingMore ? null : _loadMore,
                child: Text(
                  _loadingMore
                      ? l10n.notificationsLoadingMore
                      : l10n.notificationsLoadMore,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _scheduleRealtimeRefresh() {
    if (!mounted) return;
    if (_loadingInitial || _loadingMore || _refreshing) {
      _realtimeRefreshPending = true;
      return;
    }
    Future.microtask(() {
      if (mounted) _loadInitial(showLoading: false, preserveOnError: true);
    });
  }

  void _drainRealtimeRefresh() {
    if (!mounted ||
        !_realtimeRefreshPending ||
        _loadingInitial ||
        _loadingMore ||
        _refreshing) {
      return;
    }
    _realtimeRefreshPending = false;
    Future.microtask(() {
      if (mounted) _loadInitial(showLoading: false, preserveOnError: true);
    });
  }

  Future<void> _loadInitial({
    bool showLoading = true,
    bool preserveOnError = false,
    bool markAllOnOpen = false,
  }) async {
    if (_refreshing) return;
    _refreshing = true;
    setState(() {
      if (showLoading || _items.isEmpty) _loadingInitial = true;
      _error = '';
      _inlineError = '';
    });
    try {
      final repository = ref.read(customerNotificationRepositoryProvider);
      var markAllError = '';
      if (markAllOnOpen) {
        if (mounted) setState(() => _markingAll = true);
        try {
          await repository.markAllRead();
          ref.invalidate(customerNotificationUnreadCountProvider);
        } catch (error) {
          if (!mounted) return;
          if (await handleCustomerOperationalError(
            ref: ref,
            context: context,
            error: error,
          )) {
            return;
          }
          if (!mounted) return;
          markAllError = _notificationErrorMessage(
            error,
            context.l10n.notificationsMarkAllFailed,
          );
        } finally {
          if (mounted) setState(() => _markingAll = false);
        }
      }

      final page = await repository.list();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _unreadCount = page.unreadCount;
        _inlineError = markAllError;
      });
      ref.invalidate(customerNotificationUnreadCountProvider);
    } catch (error) {
      if (!mounted) return;
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      )) {
        return;
      }
      if (!mounted) return;
      final message = _notificationErrorMessage(
        error,
        context.l10n.notificationsLoadFailed,
      );
      setState(() {
        if (preserveOnError && _items.isNotEmpty) {
          _inlineError = message;
        } else {
          _error = message;
        }
      });
    } finally {
      _refreshing = false;
      if (mounted) setState(() => _loadingInitial = false);
      _drainRealtimeRefresh();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _cursor.isEmpty) return;
    setState(() {
      _loadingMore = true;
      _inlineError = '';
    });
    try {
      final page = await ref
          .read(customerNotificationRepositoryProvider)
          .list(cursor: _cursor);
      if (!mounted) return;
      setState(() {
        final existingIds = _items.map((item) => item.id).toSet();
        _items.addAll(page.items.where((item) => existingIds.add(item.id)));
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _unreadCount = page.unreadCount;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _inlineError = _notificationErrorMessage(
          error,
          context.l10n.notificationsLoadMoreFailed,
        );
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
      _drainRealtimeRefresh();
    }
  }

  Future<void> _open(CustomerNotificationItem item) async {
    if (!item.isRead) {
      final index = _items.indexWhere((entry) => entry.id == item.id);
      if (index < 0) return;
      final previous = _items[index];
      final optimisticReadAt = DateTime.now();
      setState(() {
        _items[index] = previous.copyWith(
          isRead: true,
          readAt: optimisticReadAt,
        );
        if (_unreadCount > 0) _unreadCount--;
        _inlineError = '';
      });
      ref.invalidate(customerNotificationUnreadCountProvider);
      try {
        final authoritative = await ref
            .read(customerNotificationRepositoryProvider)
            .markRead(item.id);
        if (!mounted) return;
        final currentIndex = _items.indexWhere((entry) => entry.id == item.id);
        if (currentIndex >= 0) {
          setState(() {
            _replaceItemAndAdjustUnread(currentIndex, authoritative);
          });
        }
      } catch (error) {
        if (!mounted) return;
        final currentIndex = _items.indexWhere((entry) => entry.id == item.id);
        setState(() {
          if (currentIndex >= 0 &&
              _items[currentIndex].readAt == optimisticReadAt) {
            _items[currentIndex] = previous;
            _unreadCount++;
          }
          _inlineError = _notificationErrorMessage(
            error,
            context.l10n.notificationsMarkReadFailed,
          );
        });
        ref.invalidate(customerNotificationUnreadCountProvider);
        return;
      }
    }

    if (!mounted) return;
    final route = customerNotificationRoute(item.action);
    if (route != null) context.push(route);
  }

  Future<void> _markAllRead() async {
    if (_markingAll) return;
    final previousUnread = <String, CustomerNotificationItem>{
      for (final item in _items)
        if (!item.isRead) item.id: item,
    };
    final previousUnreadCount = _unreadCount;
    final optimisticReadAt = DateTime.now();
    setState(() {
      _markingAll = true;
      _inlineError = '';
      for (var index = 0; index < _items.length; index++) {
        if (!_items[index].isRead) {
          _items[index] = _items[index].copyWith(
            isRead: true,
            readAt: optimisticReadAt,
          );
        }
      }
      _unreadCount = 0;
    });
    ref.invalidate(customerNotificationUnreadCountProvider);
    try {
      final authoritativeUnreadCount = await ref
          .read(customerNotificationRepositoryProvider)
          .markAllRead();
      if (mounted) {
        setState(() => _unreadCount = authoritativeUnreadCount);
        _realtimeRefreshPending = true;
        _drainRealtimeRefresh();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        var restoredUnreadCount = 0;
        for (final entry in previousUnread.entries) {
          final index = _items.indexWhere((item) => item.id == entry.key);
          if (index >= 0 && _items[index].readAt == optimisticReadAt) {
            _items[index] = entry.value;
            restoredUnreadCount++;
          }
        }
        if (restoredUnreadCount == previousUnread.length) {
          _unreadCount = previousUnreadCount;
        } else {
          _unreadCount += restoredUnreadCount;
        }
        _inlineError = _notificationErrorMessage(
          error,
          context.l10n.notificationsMarkAllFailed,
        );
      });
      ref.invalidate(customerNotificationUnreadCountProvider);
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  void _replaceItemAndAdjustUnread(
    int index,
    CustomerNotificationItem replacement,
  ) {
    final current = _items[index];
    if (current.isRead != replacement.isRead) {
      _unreadCount += replacement.isRead ? -1 : 1;
      if (_unreadCount < 0) _unreadCount = 0;
    }
    _items[index] = replacement;
  }
}

class _NotificationPageBody extends StatelessWidget {
  const _NotificationPageBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: ColoredBox(
            color: Colors.white,
            child: CustomerPageBody(
              maxWidth: 640,
              top: 0,
              bottom: 0,
              mobileHorizontal: 0,
              wideHorizontal: 0,
              minViewportHeight: true,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap, super.key});

  final CustomerNotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: item.isRead
          ? Colors.white
          : colorScheme.primary.withValues(alpha: 0.055),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 18, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _notificationIcon(item.iconKey, item.category),
                  color: colorScheme.primary,
                  size: 23,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: AppTheme.appInk,
                                  fontSize: 16,
                                  fontWeight: item.isRead
                                      ? FontWeight.w500
                                      : FontWeight.w600,
                                  height: 1.35,
                                ),
                          ),
                        ),
                        if (!item.isRead) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (item.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF64748B),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 1.45,
                        ),
                      ),
                    ],
                    if (item.imageUrl.isNotEmpty ||
                        item.imageThumbUrl.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _NotificationImage(
                        url: item.imageThumbUrl.isNotEmpty
                            ? item.imageThumbUrl
                            : item.imageUrl,
                      ),
                    ],
                    const SizedBox(height: 7),
                    Text(
                      _notificationTime(context, item.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (customerNotificationRoute(item.action) != null) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.primary,
                  size: 23,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationImage extends StatelessWidget {
  const _NotificationImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: AspectRatio(
        aspectRatio: 16 / 7,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => ColoredBox(
            color: const Color(0xFFF1F5F9),
            child: const Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationLoading extends StatelessWidget {
  const _NotificationLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 64),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _NotificationEmpty extends StatelessWidget {
  const _NotificationEmpty();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 54, 28, 32),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              color: colorScheme.primary,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.notificationsEmptyTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.appInk,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.notificationsEmptySubtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF64748B),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationError extends StatelessWidget {
  const _NotificationError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 54, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 46,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onRetry,
            child: Text(context.l10n.notificationsRetry),
          ),
        ],
      ),
    );
  }
}

class _NotificationInlineError extends StatelessWidget {
  const _NotificationInlineError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFD92D20)),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
          TextButton(
            onPressed: onRetry,
            child: Text(context.l10n.notificationsRetry),
          ),
        ],
      ),
    );
  }
}

IconData _notificationIcon(String iconKey, String category) {
  final key = iconKey.trim().toLowerCase();
  final fallback = category.trim().toLowerCase();
  return switch (key.isEmpty ? fallback : key) {
    'ticket' ||
    'tickets' ||
    'lottery' ||
    'order' => Icons.confirmation_number_outlined,
    'wallet' => Icons.account_balance_wallet_outlined,
    'topup' => Icons.add_card_outlined,
    'reward' => Icons.emoji_events_outlined,
    'activity' => Icons.celebration_outlined,
    'affiliate' => Icons.group_outlined,
    'news' => Icons.campaign_outlined,
    'account' || 'security' => Icons.shield_outlined,
    _ => Icons.notifications_none_rounded,
  };
}

String _notificationTime(BuildContext context, DateTime? createdAt) {
  if (createdAt == null) return '';
  final l10n = context.l10n;
  final difference = DateTime.now().difference(createdAt);
  if (difference.isNegative || difference.inMinutes < 1) {
    return l10n.notificationsJustNow;
  }
  if (difference.inHours < 1) {
    return l10n.notificationsMinutesAgo(difference.inMinutes);
  }
  if (difference.inDays < 1) {
    return l10n.notificationsHoursAgo(difference.inHours);
  }
  if (difference.inDays < 7) {
    return l10n.notificationsDaysAgo(difference.inDays);
  }
  return formatLocalizedDateTime(createdAt, localeTag(l10n.locale));
}

String _notificationErrorMessage(Object error, String fallback) {
  final message = ApiErrorInfo.fromObject(error).message.trim();
  return message.isEmpty ? fallback : message;
}

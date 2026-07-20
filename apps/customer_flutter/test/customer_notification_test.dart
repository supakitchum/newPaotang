import 'package:customer_flutter/app/customer_routes.dart';
import 'package:customer_flutter/core/realtime/customer_realtime_client.dart';
import 'package:customer_flutter/features/notifications/data/customer_notification_models.dart';
import 'package:customer_flutter/features/notifications/presentation/customer_notification_navigation.dart';
import 'package:customer_flutter/features/notifications/presentation/customer_notification_realtime_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification page parses authoritative read and cursor state', () {
    final page = CustomerNotificationPage.fromJson({
      'data': [
        {
          'id': 'cnt_01',
          'category': 'topup',
          'event_key': 'topup.approved',
          'title': 'เติมเงินสำเร็จ',
          'body': 'ยอดเงินเข้ากระเป๋าแล้ว',
          'icon_key': 'topup',
          'action': {'key': 'topup', 'entity_id': 'top_01'},
          'subject': {'type': 'topup', 'id': 'top_01'},
          'is_read': false,
          'created_at': '2026-07-21T10:00:00+07:00',
        },
      ],
      'meta': {'next_cursor': 'cnr_01', 'has_more': true, 'unread_count': 7},
    });

    expect(page.items, hasLength(1));
    expect(page.items.single.id, 'cnt_01');
    expect(page.items.single.isRead, isFalse);
    expect(page.items.single.action.entityId, 'top_01');
    expect(page.nextCursor, 'cnr_01');
    expect(page.hasMore, isTrue);
    expect(page.unreadCount, 7);
  });

  test('notification action map only produces allowlisted in-app routes', () {
    expect(
      customerNotificationRoute(
        const CustomerNotificationAction(key: 'ticket', entityId: 'tic 01'),
      ),
      '/tickets/view?id=tic+01',
    );
    expect(
      customerNotificationRoute(
        const CustomerNotificationAction(key: 'news', entityId: 'tenant-news'),
      ),
      '/news/tenant-news',
    );
    expect(
      customerNotificationRoute(
        const CustomerNotificationAction(
          key: 'https://evil.invalid',
          entityId: 'https://evil.invalid',
        ),
      ),
      isNull,
    );
    expect(isSensitiveCustomerPath('/notifications'), isTrue);
  });

  test('notification realtime events trigger server refetch behavior', () {
    expect(
      shouldRefreshNotificationsFromRealtimeEvent(
        const CustomerRealtimeEvent(
          name: 'customer.notification.created',
          channel: 'private-customer.tenant.ten_1.customer.cus_1.notifications',
          payload: {'notification_id': 'cnt_1', 'unread_count': 1},
        ),
      ),
      isTrue,
    );
    expect(
      shouldRefreshNotificationsFromRealtimeEvent(
        const CustomerRealtimeEvent(
          name: 'wallet.updated',
          channel: 'private-customer.tenant.ten_1.customer.cus_1.wallet',
          payload: {},
        ),
      ),
      isFalse,
    );
  });
}

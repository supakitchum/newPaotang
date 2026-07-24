import '../data/customer_notification_models.dart';

String? customerNotificationRoute(CustomerNotificationAction action) {
  final key = action.key.trim().toLowerCase();
  final entityId = action.entityId.trim();

  return switch (key) {
    'none' || '' => null,
    'home' => '/',
    'order' =>
      entityId.isEmpty
          ? '/purchase-history'
          : '/purchase-history/${Uri.encodeComponent(entityId)}',
    'checkout_pending' => Uri(
      path: '/checkout/pending',
      queryParameters: {if (entityId.isNotEmpty) 'order_id': entityId},
    ).toString(),
    'wallet' => '/my-wallet',
    'tickets' => '/tickets',
    'ticket' =>
      entityId.isEmpty
          ? '/tickets'
          : '/tickets/view?id=${Uri.encodeQueryComponent(entityId)}',
    'topups' => '/topup/history',
    'topup' =>
      entityId.isEmpty
          ? '/topup/history'
          : '/topup/${Uri.encodeComponent(entityId)}',
    'reward_claims' => '/reward-claims',
    'reward_claim' =>
      entityId.isEmpty
          ? '/reward-claims'
          : '/reward-claims/${Uri.encodeComponent(entityId)}',
    'activities' => '/activities',
    'activity' =>
      entityId.isEmpty
          ? '/activities'
          : '/activities/${Uri.encodeComponent(entityId)}',
    'activity_claims' => '/activity-claims',
    'activity_claim' =>
      entityId.isEmpty
          ? '/activity-claims'
          : '/activity-claims/${Uri.encodeComponent(entityId)}',
    'affiliate' => '/affiliate',
    'support' => '/support',
    'support_ticket' =>
      entityId.isEmpty
          ? '/support'
          : '/support/tickets/${Uri.encodeComponent(entityId)}',
    'news' =>
      entityId.isEmpty ? '/news' : '/news/${Uri.encodeComponent(entityId)}',
    _ => null,
  };
}

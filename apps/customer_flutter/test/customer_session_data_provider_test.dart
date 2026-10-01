import 'package:customer_flutter/core/auth/auth_controller.dart';
import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/security/biometric_auth_service.dart';
import 'package:customer_flutter/features/activities/data/activity_models.dart';
import 'package:customer_flutter/features/activities/data/activity_repository.dart';
import 'package:customer_flutter/features/tickets/data/ticket_models.dart';
import 'package:customer_flutter/features/tickets/data/ticket_repository.dart';
import 'package:customer_flutter/features/wallet/data/wallet_models.dart';
import 'package:customer_flutter/features/wallet/data/wallet_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('customer data providers clear across PIN and account transitions',
      () async {
    final auth = _TestAuthController();
    final tickets = _RecordingTicketRepository();
    final wallet = _RecordingWalletRepository();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith((_) => auth),
        ticketRepositoryProvider.overrideWithValue(tickets),
        walletRepositoryProvider.overrideWithValue(wallet),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(currentTicketsProvider.future), isEmpty);
    expect(
      (await container.read(walletSummaryProvider.future)).wallets,
      isEmpty,
    );
    expect(tickets.calls, 0);
    expect(wallet.calls, 0);

    auth.setSession(authenticated: true, pinRequired: true);
    expect(await container.read(currentTicketsProvider.future), isEmpty);
    expect(
      (await container.read(walletSummaryProvider.future)).wallets,
      isEmpty,
    );
    expect(tickets.calls, 0);
    expect(wallet.calls, 0);

    auth.setSession(authenticated: true);
    await container.read(currentTicketsProvider.future);
    await container.read(walletSummaryProvider.future);
    expect(tickets.calls, 1);
    expect(wallet.calls, 1);

    auth.setSession(authenticated: false);
    expect(await container.read(currentTicketsProvider.future), isEmpty);
    expect(
      (await container.read(walletSummaryProvider.future)).wallets,
      isEmpty,
    );
    expect(tickets.calls, 1);
    expect(wallet.calls, 1);

    auth.setSession(authenticated: true);
    await container.read(currentTicketsProvider.future);
    await container.read(walletSummaryProvider.future);
    expect(tickets.calls, 2);
    expect(wallet.calls, 2);
  });

  test('authenticated activity detail is discarded when its route unmounts',
      () async {
    final repository = _RecordingActivityRepository();
    final container = ProviderContainer(
      overrides: [
        activityRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    const request = ActivityDetailRequest(
      slug: 'customer-lucky-board',
      authenticated: true,
    );
    final firstListener = container.listen(
      activityDetailProvider(request),
      (_, __) {},
    );
    final first = await container.read(activityDetailProvider(request).future);
    expect(first.name, 'Customer detail 1');
    expect(repository.calls, 1);

    firstListener.close();
    await container.pump();

    final secondListener = container.listen(
      activityDetailProvider(request),
      (_, __) {},
    );
    addTearDown(secondListener.close);
    final second = await container.read(activityDetailProvider(request).future);
    expect(second.name, 'Customer detail 2');
    expect(repository.calls, 2);
  });
}

class _TestAuthController extends AuthController {
  factory _TestAuthController() {
    final tokenStore = AuthTokenStore();
    final api = _testApi(tokenStore);
    return _TestAuthController._(tokenStore, api);
  }

  _TestAuthController._(AuthTokenStore tokenStore, ApiClient api)
      : super(
          authRepository: AuthRepository(api: api, tokenStore: tokenStore),
          tokenStore: tokenStore,
          biometricAuth: BiometricAuthService(api),
        );

  void setSession({
    required bool authenticated,
    bool pinRequired = false,
  }) {
    isAuthenticated = authenticated;
    this.pinRequired = pinRequired;
    pinSetupRequired = false;
    notifyListeners();
  }
}

class _RecordingTicketRepository extends TicketRepository {
  _RecordingTicketRepository() : super(_testApi(AuthTokenStore()));

  int calls = 0;

  @override
  Future<List<CustomerTicket>> currentAll({
    int limit = TicketRepository.defaultPageLimit,
    int maxPages = TicketRepository.maxAutoPages,
  }) async {
    calls++;
    return const [];
  }
}

class _RecordingWalletRepository extends WalletRepository {
  _RecordingWalletRepository() : super(_testApi(AuthTokenStore()));

  int calls = 0;

  @override
  Future<WalletSummary> summary() async {
    calls++;
    return const WalletSummary(wallets: [], ledger: []);
  }
}

class _RecordingActivityRepository extends ActivityRepository {
  _RecordingActivityRepository()
      : super(_testApi(AuthTokenStore()), (value) => value);

  int calls = 0;

  @override
  Future<ActivityItem> detail(
    String slug, {
    bool authenticated = false,
  }) async {
    calls++;
    return ActivityItem(
      id: 'activity_$calls',
      name: 'Customer detail $calls',
      slug: slug,
      type: 'lucky_board',
      imageUrl: '',
      conditionText: '',
      remainingNumbers: 0,
      hasRight: authenticated,
      estimatedCashbackAmount: 0,
    );
  }
}

ApiClient _testApi(AuthTokenStore tokenStore) {
  return ApiClient(
    const AppConfig(
      apiBaseUrl: 'https://partner.example.test/api/v1',
      defaultLocale: 'th-TH',
    ),
    tokenStore,
    localeTag: 'th-TH',
    dio: Dio(),
  );
}

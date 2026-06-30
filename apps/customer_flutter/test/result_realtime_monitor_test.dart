import 'dart:async';

import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/realtime/customer_realtime_client.dart';
import 'package:customer_flutter/core/realtime/customer_realtime_monitor.dart';
import 'package:customer_flutter/core/realtime/customer_realtime_protocol.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/features/results/data/result_models.dart';
import 'package:customer_flutter/features/results/data/result_repository.dart';
import 'package:customer_flutter/features/results/presentation/result_realtime_monitor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('result realtime monitor refreshes latest and detail providers', (
    tester,
  ) async {
    var latestLoads = 0;
    var detailLoads = 0;
    final client = _FakeRealtimeClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith((_) async => _bootstrap()),
          customerRealtimeClientFactoryProvider
              .overrideWithValue((_) => client),
          currentResultProvider.overrideWith((_) async {
            latestLoads++;
            return _bundle('latest_$latestLoads');
          }),
          resultDetailProvider('game_1').overrideWith((_) async {
            detailLoads++;
            return _bundle('detail_$detailLoads');
          }),
        ],
        child: const _ResultRealtimeHarness(gameId: 'game_1'),
      ),
    );

    await tester.pumpAndSettle();

    expect(client.connectedChannels, hasLength(1));
    expect(client.connectedChannels.single, [publicLatestResultChannel()]);
    expect(latestLoads, 1);
    expect(detailLoads, 1);
    expect(find.text('latest:latest_1'), findsOneWidget);
    expect(find.text('detail:detail_1'), findsOneWidget);

    client.emit(
      CustomerRealtimeEvent(
        name: 'topup.updated',
        channel: publicLatestResultChannel(),
        payload: const {'game_id': 'game_1'},
      ),
    );
    await tester.pumpAndSettle();

    expect(latestLoads, 1);
    expect(detailLoads, 1);
    expect(find.text('latest:latest_1'), findsOneWidget);
    expect(find.text('detail:detail_1'), findsOneWidget);

    client.emit(
      CustomerRealtimeEvent(
        name: 'reward.result.live.updated',
        channel: publicLatestResultChannel(),
        payload: const {'game_id': 'game_1'},
      ),
    );
    await tester.pumpAndSettle();

    expect(latestLoads, 2);
    expect(detailLoads, 2);
    expect(find.text('latest:latest_2'), findsOneWidget);
    expect(find.text('detail:detail_2'), findsOneWidget);
  });

  testWidgets('result realtime monitor refreshes latest without game id', (
    tester,
  ) async {
    var latestLoads = 0;
    var detailLoads = 0;
    final client = _FakeRealtimeClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith((_) async => _bootstrap()),
          customerRealtimeClientFactoryProvider
              .overrideWithValue((_) => client),
          currentResultProvider.overrideWith((_) async {
            latestLoads++;
            return _bundle('latest_$latestLoads');
          }),
          resultDetailProvider('game_1').overrideWith((_) async {
            detailLoads++;
            return _bundle('detail_$detailLoads');
          }),
        ],
        child: const _ResultRealtimeHarness(gameId: 'game_1'),
      ),
    );

    await tester.pumpAndSettle();

    client.emit(
      CustomerRealtimeEvent(
        name: 'reward.result.live.updated',
        channel: publicLatestResultChannel(),
        payload: const {},
      ),
    );
    await tester.pumpAndSettle();

    expect(latestLoads, 2);
    expect(detailLoads, 1);
    expect(find.text('latest:latest_2'), findsOneWidget);
    expect(find.text('detail:detail_1'), findsOneWidget);
  });
}

class _ResultRealtimeHarness extends StatelessWidget {
  const _ResultRealtimeHarness({required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ResultRealtimeMonitor(
        child: _ResultReadout(gameId: gameId),
      ),
    );
  }
}

class _ResultReadout extends ConsumerWidget {
  const _ResultReadout({required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(currentResultProvider);
    final detail = ref.watch(resultDetailProvider(gameId));

    return Column(
      textDirection: TextDirection.ltr,
      children: [
        latest.when(
          data: (bundle) => Text(
            'latest:${bundle.selectedResult?.id ?? ''}',
            textDirection: TextDirection.ltr,
          ),
          loading: () =>
              const Text('latest:loading', textDirection: TextDirection.ltr),
          error: (_, __) =>
              const Text('latest:error', textDirection: TextDirection.ltr),
        ),
        detail.when(
          data: (bundle) => Text(
            'detail:${bundle.selectedResult?.id ?? ''}',
            textDirection: TextDirection.ltr,
          ),
          loading: () =>
              const Text('detail:loading', textDirection: TextDirection.ltr),
          error: (_, __) =>
              const Text('detail:error', textDirection: TextDirection.ltr),
        ),
      ],
    );
  }
}

RewardResultBundle _bundle(String resultId) {
  return RewardResultBundle(
    currentGame: const CurrentGame(
      id: 'game_1',
      name: 'งวดทดสอบ',
      status: 'closed',
      drawAt: '2026-07-01T16:00:00+07:00',
    ),
    selectedResult: RewardResultGame(
      id: resultId,
      name: 'งวดทดสอบ',
      status: 'live',
      resultStatus: 'live',
      officialStatus: 'unofficial',
      completionPercent: 80,
      drawAt: '2026-07-01T16:00:00+07:00',
      rewards: const [],
    ),
    history: const [],
  );
}

class _FakeRealtimeClient extends CustomerRealtimeClient {
  _FakeRealtimeClient()
      : super(
          config: _realtimeConfig(),
          api: _apiClient(),
        );

  final StreamController<CustomerRealtimeEvent> _events =
      StreamController<CustomerRealtimeEvent>.broadcast();
  final List<List<String>> connectedChannels = [];

  @override
  Stream<CustomerRealtimeEvent> get events => _events.stream;

  @override
  Future<void> connect(Iterable<String> channels) async {
    connectedChannels.add(channels.toList(growable: false));
  }

  void emit(CustomerRealtimeEvent event) {
    _events.add(event);
  }

  @override
  Future<void> dispose() async {
    await _events.close();
  }
}

MobileBootstrap _bootstrap() {
  return MobileBootstrap.fromJson({
    'mobile': {
      'realtime': {
        'enabled': true,
        'url': 'https://realtime.example.test',
        'key': 'customer-key',
      },
    },
  });
}

MobileRealtimeConfig _realtimeConfig() {
  return MobileRealtimeConfig.fromJson({
    'enabled': true,
    'url': 'https://realtime.example.test',
    'key': 'customer-key',
  });
}

ApiClient _apiClient() {
  return ApiClient(
    const AppConfig(
      apiBaseUrl: 'https://partner.example.test/api/v1',
      defaultLocale: 'th-TH',
    ),
    AuthTokenStore(),
    localeTag: 'th-TH',
  );
}

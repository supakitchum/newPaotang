import 'package:customer_flutter/features/lottery/data/lottery_models.dart';
import 'package:customer_flutter/features/lottery/presentation/lottery_screens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatReservationCountdown renders mm:ss and clamps expired time', () {
    expect(formatReservationCountdown(const Duration(seconds: 0)), '00:00');
    expect(formatReservationCountdown(const Duration(seconds: 9)), '00:09');
    expect(formatReservationCountdown(const Duration(seconds: 125)), '02:05');
    expect(formatReservationCountdown(const Duration(seconds: -5)), '00:00');
  });

  test('reservationRemainingDuration uses expires_at against supplied now', () {
    final reservation = _reservation(
      id: 'res_1',
      expiresAt: '2026-06-26T12:05:00+07:00',
      expiresInSeconds: 999,
    );

    final remaining = reservationRemainingDuration(
      reservation,
      now: DateTime.parse('2026-06-26T12:03:30+07:00'),
    );

    expect(remaining, const Duration(seconds: 90));
  });

  test('reservationRemainingDuration falls back to expires_in_seconds', () {
    final reservation = _reservation(
      id: 'res_1',
      expiresInSeconds: 75,
    );

    final remaining = reservationRemainingDuration(
      reservation,
      now: DateTime.parse('2026-06-26T12:03:30+07:00'),
    );

    expect(remaining, const Duration(seconds: 75));
  });

  test('reservationRemainingDuration can count down from fallback deadline',
      () {
    final reservation = _reservation(
      id: 'res_1',
      expiresInSeconds: 75,
    );
    final now = DateTime.parse('2026-06-26T12:03:30+07:00');
    final fallbackDeadline = now.add(const Duration(seconds: 75));

    expect(
      reservationRemainingDuration(
        reservation,
        now: now.add(const Duration(seconds: 30)),
        fallbackExpiresAt: fallbackDeadline,
      ),
      const Duration(seconds: 45),
    );
    expect(
      reservationRemainingDuration(
        reservation,
        now: now.add(const Duration(seconds: 90)),
        fallbackExpiresAt: fallbackDeadline,
      ),
      Duration.zero,
    );
  });

  test('reservationServerTimeOffset compares backend server time to local now',
      () {
    final offset = reservationServerTimeOffset(
      '2026-06-26T12:03:45+07:00',
      localNow: DateTime.parse('2026-06-26T12:03:30+07:00'),
    );

    expect(offset, const Duration(seconds: 15));
  });

  test('reservationDeadlineExpired honors backend server time', () {
    final reservation = _reservation(
      id: 'res_1',
      expiresAt: '2026-06-26T12:03:45+07:00',
      serverTime: '2026-06-26T12:03:46+07:00',
    );

    expect(
      reservationDeadlineExpired(
        reservation,
        localNow: DateTime.parse('2026-06-26T10:00:00+07:00'),
      ),
      isTrue,
    );
  });

  test('earliestActiveReservation ignores inactive rows and picks soonest', () {
    final selected = earliestActiveReservation([
      _reservation(
        id: 'cancelled',
        status: 'cancelled',
        expiresAt: '2026-06-26T12:01:00+07:00',
      ),
      _reservation(
        id: 'later',
        expiresAt: '2026-06-26T12:05:00+07:00',
      ),
      _reservation(
        id: 'soonest',
        expiresAt: '2026-06-26T12:02:00+07:00',
      ),
    ]);

    expect(selected?.id, 'soonest');
  });
}

LotteryReservation _reservation({
  required String id,
  String status = 'active',
  Object? expiresAt,
  int expiresInSeconds = 0,
  Object? serverTime,
}) {
  return LotteryReservation(
    id: id,
    gameId: 'game_1',
    status: status,
    expiresAt: expiresAt,
    expiresInSeconds: expiresInSeconds,
    serverTime: serverTime,
    items: const [],
    total: 0,
  );
}

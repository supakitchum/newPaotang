import 'package:customer_flutter/features/lottery/presentation/lottery_digit_input_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('LotteryDigitInputRow keeps one digit per slot and moves focus', (
    tester,
  ) async {
    final controllers = List.generate(6, (_) => TextEditingController());
    addTearDown(() {
      for (final controller in controllers) {
        controller.dispose();
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LotteryDigitInputRow(controllers: controllers),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, '72');
    await tester.pump();

    expect(controllers.first.text, '7');
    expect(
      FocusScope.of(
        tester.element(find.byType(TextField).at(1)),
      ).focusedChild,
      isNotNull,
    );
  });
}

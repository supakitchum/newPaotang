import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/customer_app_smoke_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CustomerApp boots with runtime partner config and route guards',
      (
    tester,
  ) async {
    await runCustomerAppSmokeHarness(tester);
  });
}

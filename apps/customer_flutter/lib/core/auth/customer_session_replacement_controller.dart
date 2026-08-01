import 'package:flutter_riverpod/flutter_riverpod.dart';

final customerSessionReplacementControllerProvider =
    StateNotifierProvider<
      CustomerSessionReplacementController,
      CustomerSessionReplacementState
    >((_) {
      return CustomerSessionReplacementController();
    });

class CustomerSessionReplacementState {
  const CustomerSessionReplacementState({
    this.sequence = 0,
    this.pending = false,
    this.replacementSessionId = '',
  });

  final int sequence;
  final bool pending;
  final String replacementSessionId;
}

class CustomerSessionReplacementController
    extends StateNotifier<CustomerSessionReplacementState> {
  CustomerSessionReplacementController()
    : super(const CustomerSessionReplacementState());

  DateTime? _suppressUntil;

  void notify({String replacementSessionId = ''}) {
    final now = DateTime.now();
    if (state.pending ||
        (_suppressUntil != null && now.isBefore(_suppressUntil!))) {
      return;
    }
    state = CustomerSessionReplacementState(
      sequence: state.sequence + 1,
      pending: true,
      replacementSessionId: replacementSessionId.trim(),
    );
  }

  void acknowledge() {
    _suppressUntil = DateTime.now().add(const Duration(seconds: 3));
    state = CustomerSessionReplacementState(sequence: state.sequence);
  }
}

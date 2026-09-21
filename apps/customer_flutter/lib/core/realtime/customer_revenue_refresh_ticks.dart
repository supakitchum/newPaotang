import 'package:flutter_riverpod/flutter_riverpod.dart';

final cartRealtimeTickProvider = StateProvider<int>((_) => 0);
final ticketRealtimeTickProvider = StateProvider<int>((_) => 0);
final purchaseHistoryRefreshTickProvider = StateProvider<int>((_) => 0);

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../data/topup_repository.dart';

Future<TopupSlipUpload?> pickTopupSlipUpload() async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/*';
  final completer = Completer<TopupSlipUpload?>();
  late final StreamSubscription<web.Event> subscription;
  var removed = false;

  void removeInput() {
    if (removed) return;
    removed = true;
    input.remove();
  }

  input.style.display = 'none';
  web.document.body?.appendChild(input);

  subscription = input.onChange.listen((_) async {
    await subscription.cancel();
    removeInput();
    if (completer.isCompleted) return;

    final files = input.files;
    final file = files == null || files.length == 0 ? null : files.item(0);
    if (file == null) {
      completer.complete(null);
      return;
    }

    try {
      final buffer = await file.arrayBuffer().toDart;
      completer.complete(
        TopupSlipUpload(
          filename: file.name.isEmpty ? 'topup-slip.jpg' : file.name,
          bytes: Uint8List.view(buffer.toDart),
        ),
      );
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    }
  });

  input.click();
  return completer.future.timeout(
    const Duration(minutes: 5),
    onTimeout: () async {
      await subscription.cancel();
      removeInput();
      return null;
    },
  );
}

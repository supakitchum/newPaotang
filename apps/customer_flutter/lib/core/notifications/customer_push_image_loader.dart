import 'dart:typed_data';

import 'customer_push_image_loader_stub.dart'
    if (dart.library.io) 'customer_push_image_loader_io.dart'
    as loader;

Future<Uint8List?> loadCustomerPushImage(String url) {
  return loader.loadCustomerPushImage(url);
}

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

const _maximumImageBytes = 8 * 1024 * 1024;

Future<Uint8List?> loadCustomerPushImage(String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !const {'http', 'https'}.contains(uri.scheme)) return null;

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
  try {
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 3));
    final response = await request.close().timeout(const Duration(seconds: 3));
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final declaredLength = response.contentLength;
    if (declaredLength > _maximumImageBytes) return null;

    final builder = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(const Duration(seconds: 3))) {
      builder.add(chunk);
      if (builder.length > _maximumImageBytes) return null;
    }
    final bytes = builder.takeBytes();
    return bytes.isEmpty ? null : bytes;
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

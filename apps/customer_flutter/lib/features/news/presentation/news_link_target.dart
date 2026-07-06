import '../../../core/navigation/customer_link_launcher.dart';
import '../data/news_models.dart';

bool hasNewsTarget(NewsItem item) {
  return newsInternalPath(item) != null || newsExternalUri(item) != null;
}

String? newsInternalPath(NewsItem item) {
  final url = item.url.trim();
  if (url.isNotEmpty) return safeNewsInternalPath(url);

  final slug = item.slug.trim();
  if (slug.isEmpty) return null;
  return '/news/${Uri.encodeComponent(slug)}';
}

Uri? newsExternalUri(NewsItem item) {
  final value = item.url.trim();
  if (value.isEmpty) return null;

  final uri = Uri.tryParse(value);
  if (uri == null || !isSafeExternalLinkUri(uri)) return null;
  return uri;
}

String? safeNewsInternalPath(String value) {
  final trimmed = value.trim();
  if (trimmed == '#' || trimmed.startsWith('//')) return null;

  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;

  if (uri.path.isEmpty && uri.query.isEmpty) return null;
  final path = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
  return uri.replace(path: path).toString();
}

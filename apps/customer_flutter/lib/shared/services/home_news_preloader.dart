import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/news/data/news_models.dart';

typedef HomeNewsPreloader =
    Future<void> Function(BuildContext context, List<NewsItem> items);

final homeNewsPreloaderProvider = Provider<HomeNewsPreloader>((ref) {
  return (context, items) async {
    final urls = items
        .map((item) => item.coverUrl.trim())
        .where((url) => url.isNotEmpty)
        .toSet()
        .take(6);
    await Future.wait(
      urls.map(
        (url) => precacheImage(NetworkImage(url), context, onError: (_, __) {}),
      ),
    );
  };
});

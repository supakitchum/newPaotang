import 'package:flutter/material.dart';

import '../../../shared/widgets/customer_page_body.dart';
import 'news_visual_tokens.dart';

class NewsPageShell extends StatelessWidget {
  const NewsPageShell({
    required this.child,
    super.key,
    this.maxWidth = 640,
  });

  static const _heroHeight = 214.0;
  static const _sheetOverlap = 54.0;

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            const _NewsHeroBand(),
            Padding(
              padding: const EdgeInsets.only(top: _heroHeight - _sheetOverlap),
              child: _NewsContentSheet(
                child: CustomerPageBody(
                  maxWidth: maxWidth,
                  top: 0,
                  bottom: 96,
                  mobileHorizontal: 16,
                  wideHorizontal: 16,
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NewsHeroBand extends StatelessWidget {
  const _NewsHeroBand();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: NewsPageShell._heroHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary,
              Color.lerp(colorScheme.primary, colorScheme.secondary, 0.46) ??
                  colorScheme.primary,
            ],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _NewsContentSheet extends StatelessWidget {
  const _NewsContentSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: newsCardSurfaceColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 620),
        child: child,
      ),
    );
  }
}

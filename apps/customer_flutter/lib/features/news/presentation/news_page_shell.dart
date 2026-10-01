import 'package:flutter/material.dart';

import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_page_body.dart';
import 'news_visual_tokens.dart';

class NewsPageShell extends StatelessWidget {
  const NewsPageShell({
    required this.child,
    super.key,
    this.maxWidth = 760,
    this.topPadding = 16,
    this.mobileHorizontal = 16,
    this.wideHorizontal = 16,
  });

  static const heroMinHeight = customerReferenceCompactHeroHeight;
  static const sheetOverlap = 0.0;

  final Widget child;
  final double maxWidth;
  final double topPadding;
  final double mobileHorizontal;
  final double wideHorizontal;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _NewsContentSheet(
          child: CustomerPageBody(
            maxWidth: maxWidth,
            top: topPadding,
            bottom: 96,
            mobileHorizontal: mobileHorizontal,
            wideHorizontal: wideHorizontal,
            minViewportHeight: true,
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
      ],
    );
  }
}

class _NewsContentSheet extends StatelessWidget {
  const _NewsContentSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('news-content-sheet'),
      decoration: BoxDecoration(
        color: newsCardSurfaceColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: child,
    );
  }
}

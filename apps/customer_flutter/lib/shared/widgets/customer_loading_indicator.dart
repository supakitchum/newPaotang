import 'package:flutter/material.dart';

class CustomerLoadingMark extends StatelessWidget {
  const CustomerLoadingMark({
    super.key,
    this.color,
    this.trackColor,
    this.width = 34,
    this.height = 24,
    this.semanticLabel,
  });

  final Color? color;
  final Color? trackColor;
  final double width;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedColor = color ?? colorScheme.primary;
    final resolvedTrack =
        trackColor ?? colorScheme.primary.withValues(alpha: 0.12);
    final barHeight = (height * 0.16).clamp(3.0, 5.0).toDouble();

    return Semantics(
      label: semanticLabel,
      liveRegion: semanticLabel != null,
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LoadingMarkBar(
              widthFactor: 1,
              height: barHeight,
              color: resolvedColor,
            ),
            _LoadingMarkBar(
              widthFactor: 0.72,
              height: barHeight,
              color: resolvedColor.withValues(alpha: 0.58),
            ),
            _LoadingMarkBar(
              widthFactor: 0.44,
              height: barHeight,
              color: resolvedTrack,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingMarkBar extends StatelessWidget {
  const _LoadingMarkBar({
    required this.widthFactor,
    required this.height,
    required this.color,
  });

  final double widthFactor;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
        child: SizedBox(height: height),
      ),
    );
  }
}

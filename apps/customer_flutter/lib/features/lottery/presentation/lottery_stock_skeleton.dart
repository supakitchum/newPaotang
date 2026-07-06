import 'package:flutter/material.dart';

const lotteryStockSkeletonItemCount = 5;

List<Widget> lotteryStockSkeletonCards({
  String keyPrefix = 'lottery-stock-skeleton',
}) {
  return [
    for (var index = 0; index < lotteryStockSkeletonItemCount; index++)
      LotteryStockSkeletonCard(index: index, keyPrefix: keyPrefix),
  ];
}

class LotteryStockSkeletonCard extends StatelessWidget {
  LotteryStockSkeletonCard({
    required this.index,
    this.keyPrefix = 'lottery-stock-skeleton',
  }) : super(key: ValueKey('$keyPrefix-$index'));

  final int index;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final blockColor =
        Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.66,
            );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.75),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 100),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LotterySkeletonBlock(
                      width: 132,
                      height: 14,
                      color: blockColor,
                    ),
                    const SizedBox(height: 15),
                    _LotterySkeletonBlock(
                      width: 154,
                      height: 32,
                      color: blockColor,
                      radius: 7,
                    ),
                    const SizedBox(height: 14),
                    _LotterySkeletonBlock(
                      width: 180,
                      height: 13,
                      color: blockColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _LotterySkeletonBlock(
                width: 68,
                height: 40,
                color: blockColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LotterySkeletonBlock extends StatelessWidget {
  const _LotterySkeletonBlock({
    required this.width,
    required this.height,
    required this.color,
    this.radius = 999,
  });

  final double width;
  final double height;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final highlight =
        Color.lerp(color, Theme.of(context).colorScheme.surface, 0.62) ?? color;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, highlight, color],
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: SizedBox(width: width, height: height),
    );
  }
}

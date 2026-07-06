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
    final colorScheme = Theme.of(context).colorScheme;
    final blockColor = colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.66,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.75),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 420;
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _LotterySkeletonBlock.square(
                      size: 16,
                      color: blockColor,
                      radius: 8,
                    ),
                    const SizedBox(width: 6),
                    _LotterySkeletonBlock(
                      width: 136,
                      height: 14,
                      color: blockColor,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: [
                    for (var digit = 0; digit < 6; digit++)
                      _LotterySkeletonBlock(
                        width: 30,
                        height: 36,
                        color: blockColor,
                        radius: 8,
                      ),
                  ],
                ),
              ],
            );
            final actions = Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _LotterySkeletonBlock(
                  width: 112,
                  height: 42,
                  color: blockColor,
                  radius: 21,
                ),
                const SizedBox(height: 10),
                _LotterySkeletonBlock(
                  width: 62,
                  height: 14,
                  color: blockColor,
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  details,
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: actions),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: details),
                const SizedBox(width: 12),
                actions,
              ],
            );
          },
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

  const _LotterySkeletonBlock.square({
    required double size,
    required this.color,
    this.radius = 999,
  })  : width = size,
        height = size;

  final double width;
  final double height;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: SizedBox(width: width, height: height),
    );
  }
}

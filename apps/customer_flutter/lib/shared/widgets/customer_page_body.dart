import 'package:flutter/material.dart';

class CustomerPageBody extends StatelessWidget {
  const CustomerPageBody({
    required this.child,
    super.key,
    this.maxWidth = 960,
    this.top = 16,
    this.bottom = 128,
    this.mobileHorizontal = 16,
    this.wideHorizontal = 28,
  });

  final Widget child;
  final double maxWidth;
  final double top;
  final double bottom;
  final double mobileHorizontal;
  final double wideHorizontal;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal =
            constraints.maxWidth >= 720 ? wideHorizontal : mobileHorizontal;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

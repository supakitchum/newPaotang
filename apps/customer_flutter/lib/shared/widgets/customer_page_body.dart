import 'package:flutter/material.dart';

const double customerContentMaxWidthAuto = -1;

double customerContentMaxWidthFor(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 1280) return 1080;
  if (width >= 1024) return 920;
  return 960;
}

class CustomerPageBody extends StatelessWidget {
  const CustomerPageBody({
    required this.child,
    super.key,
    this.maxWidth = customerContentMaxWidthAuto,
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
        final effectiveMaxWidth =
            maxWidth >= 0 ? maxWidth : customerContentMaxWidthFor(context);
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
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

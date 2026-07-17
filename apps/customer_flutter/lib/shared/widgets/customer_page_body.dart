import 'package:flutter/material.dart';

const double customerContentMaxWidthAuto = -1;
const double customerContentMaxWidthMobile = 960;
const double customerContentMaxWidthTablet = 720;
const double customerContentMaxWidthDesktop = 920;
const double customerContentMaxWidthWide = 1080;
const double customerSheetTopPadding = 23;
const double customerSheetBottomPadding = 120;
const double customerSheetMobileHorizontalPadding = 18;
const double customerSheetWideHorizontalPadding = 24;

double customerContentMaxWidthFor(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 1280) return customerContentMaxWidthWide;
  if (width >= 1024) return customerContentMaxWidthDesktop;
  if (width >= 768) return customerContentMaxWidthTablet;
  return customerContentMaxWidthMobile;
}

class CustomerPageBody extends StatelessWidget {
  const CustomerPageBody({
    required this.child,
    super.key,
    this.maxWidth = customerContentMaxWidthAuto,
    this.top = customerSheetTopPadding,
    this.bottom = customerSheetBottomPadding,
    this.mobileHorizontal = customerSheetMobileHorizontalPadding,
    this.wideHorizontal = customerSheetWideHorizontalPadding,
    this.includeBottomSafeArea = true,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final double top;
  final double bottom;
  final double mobileHorizontal;
  final double wideHorizontal;
  final bool includeBottomSafeArea;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal =
            constraints.maxWidth >= 720 ? wideHorizontal : mobileHorizontal;
        final effectiveMaxWidth =
            maxWidth >= 0 ? maxWidth : customerContentMaxWidthFor(context);
        final effectiveBottom = bottom +
            (includeBottomSafeArea ? MediaQuery.paddingOf(context).bottom : 0);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            top,
            horizontal,
            effectiveBottom,
          ),
          child: Align(
            alignment: alignment,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

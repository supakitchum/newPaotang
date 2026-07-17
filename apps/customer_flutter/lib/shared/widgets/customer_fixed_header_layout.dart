import 'package:flutter/material.dart';

import 'customer_page_body.dart';

const double customerContentSheetTopRadius = 18;

/// Keeps the branded header outside the page's scrollable content viewport.
class CustomerFixedHeaderLayout extends StatelessWidget {
  const CustomerFixedHeaderLayout({
    required this.header,
    required this.headerHeight,
    required this.content,
    super.key,
    this.contentOverlap = 0,
    this.headerKey,
    this.contentRegionKey,
    this.allowHeaderOverflow = false,
    this.contentTopRadius = 0,
    this.contentBackdropColor,
  })  : assert(headerHeight >= 0),
        assert(contentOverlap >= 0),
        assert(contentOverlap <= headerHeight),
        assert(contentTopRadius >= 0);

  final Widget header;
  final double headerHeight;
  final Widget content;
  final double contentOverlap;
  final Key? headerKey;
  final Key? contentRegionKey;
  final bool allowHeaderOverflow;
  final double contentTopRadius;
  final Color? contentBackdropColor;

  @override
  Widget build(BuildContext context) {
    final contentTop = headerHeight - contentOverlap;
    final fixedHeader = allowHeaderOverflow
        ? OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: headerHeight,
            maxHeight: double.infinity,
            child: SizedBox(width: double.infinity, child: header),
          )
        : header;
    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final contentMinHeight = (layoutHeight - contentTop)
            .clamp(0.0, double.infinity)
            .toDouble();
        final scopedContent = CustomerContentViewportScope(
          minHeight: contentMinHeight,
          child: content,
        );
        final roundedContent = contentTopRadius > 0
            ? ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(contentTopRadius),
                ),
                clipBehavior: Clip.antiAlias,
                child: scopedContent,
              )
            : scopedContent;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              key: headerKey,
              top: 0,
              left: 0,
              right: 0,
              height: headerHeight,
              child: fixedHeader,
            ),
            if (contentTopRadius > 0 && contentBackdropColor != null)
              Positioned(
                top: contentTop,
                left: 0,
                right: 0,
                height: contentTopRadius,
                child: ColoredBox(color: contentBackdropColor!),
              ),
            Positioned(
              key: contentRegionKey,
              top: contentTop,
              left: 0,
              right: 0,
              bottom: 0,
              child: roundedContent,
            ),
          ],
        );
      },
    );
  }
}

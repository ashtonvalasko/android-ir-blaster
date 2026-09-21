import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:irblaster_controller/utils/remote_grid_layout.dart';

/// The physical layout does not mirror when the app language changes.
/// On very narrow screens, scroll horizontally instead of shrinking targets
/// below 48 logical pixels or moving buttons to different rows.
class RemoteCustomGrid extends StatelessWidget {
  const RemoteCustomGrid({
    super.key,
    required this.layout,
    required this.itemBuilder,
    this.controller,
    this.bottomPadding = 16,
  });

  final RemoteGridLayout layout;
  final IndexedWidgetBuilder itemBuilder;
  final ScrollController? controller;
  final double bottomPadding;

  static double canvasWidth(double width, int columns) =>
      math.max(width, 24 + columns * 48 + (columns - 1) * 10);

  static double rowExtent(double width, RemoteGridLayout layout) {
    final cellWidth =
        (canvasWidth(width, layout.columns) - 24 - (layout.columns - 1) * 10) /
            layout.columns;
    return (layout.shape == RemoteButtonShape.rectangle
            ? math.max(48, cellWidth / 1.8)
            : cellWidth) +
        10;
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final width = canvasWidth(constraints.maxWidth, layout.columns);
      return Directionality(
        textDirection: TextDirection.ltr,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            height: constraints.maxHeight,
            child: GridView.builder(
              controller: controller,
              padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPadding),
              itemCount: layout.cells.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: layout.columns,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: rowExtent(width, layout) - 10,
              ),
              itemBuilder: (context, index) => Directionality(
                textDirection: textDirection,
                child: itemBuilder(context, index),
              ),
            ),
          ),
        ),
      );
    });
  }
}

OutlinedBorder remoteGridButtonShape(RemoteButtonShape shape) =>
    shape == RemoteButtonShape.circle
        ? const CircleBorder()
        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

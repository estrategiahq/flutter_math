import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

import '../../render/layout/custom_layout.dart';
import '../../render/layout/shift_baseline.dart';
import '../options.dart';
import '../size.dart';
import '../syntax_tree.dart';

class MultiRowNode extends SlotableNode<EquationRowNode?> {
  final List<EquationRowNode> _children;

  /// Row count.
  final int rows;

  MultiRowNode._({
    required this.rows,
    required List<EquationRowNode> children,
  })  : _children = children,
        assert(children.length == rows);

  factory MultiRowNode({
    required List<EquationRowNode> children,
    double arrayStretch = 1.0,
  }) {
    final rows = children.length;
    final sanitizedBody = children;

    return MultiRowNode._(
      rows: rows,
      children: sanitizedBody,
    );
  }

  @override
  BuildResult buildWidget(
      MathOptions options, List<BuildResult?> childBuildResults) {
    assert(childBuildResults.length == rows);
    return BuildResult(
      options: options,
      widget: ShiftBaseline(
        relativePos: 0.5,
        offset: options.fontMetrics.axisHeight.cssEm.toLpUnder(options),
        child: CustomLayout<int>(
          delegate: MultiRowLayoutDelegate(
            arrayskip: 12.0.pt.toLpUnder(options),
            rows: rows,
          ),
          children: childBuildResults
              .mapIndexed((index, result) => result == null
                  ? null
                  : CustomLayoutId(id: index, child: result.widget))
              .whereNotNull()
              .toList(growable: false),
        ),
      ),
    );
  }

  @override
  List<MathOptions> computeChildOptions(MathOptions options) =>
      List.filled(rows, options, growable: false);

  @override
  List<EquationRowNode?> computeChildren() => _children.toList(growable: false);

  @override
  AtomType get leftType => AtomType.ord;

  @override
  AtomType get rightType => AtomType.ord;

  @override
  bool shouldRebuildWidget(MathOptions oldOptions, MathOptions newOptions) =>
      false;

  @override
  MultiRowNode updateChildren(List<EquationRowNode> newChildren) {
    assert(newChildren.length >= rows);
    var body = List<EquationRowNode>.generate(
      rows,
      (i) => newChildren[i],
      growable: false,
    );
    return copyWith(children: body);
  }

  MultiRowNode copyWith({
    double? arrayStretch,
    List<EquationRowNode>? children,
  }) =>
      MultiRowNode(
        children: children ?? this._children,
      );

  @override
  Map<String, Object?> toJson() => super.toJson()
    ..addAll({
      'children': _children.map((e) => e.toJson()),
    });

  String toString() {
    return "MatrixNode(${this.children.map((e) => e.toString()).toString()})";
  }
}

class MultiRowLayoutDelegate extends IntrinsicLayoutDelegate<int> {
  final int rows;
  final double arrayskip;

  MultiRowLayoutDelegate({
    required this.rows,
    required this.arrayskip,
  }) : hLinePos = List.filled(rows + 1, 0.0, growable: false);

  List<double> hLinePos;

  var totalHeight = 0.0;
  var width = 0.0;

  @override
  double? computeDistanceToActualBaseline(
          TextBaseline baseline,
          // ignore: avoid_returning_null
          Map<int, RenderBox> childrenTable) =>
      null;

  @override
  AxisConfiguration<int> performHorizontalIntrinsicLayout({
    required Map<int, double> childrenWidths,
    bool isComputingIntrinsics = false,
  }) {
    final childWidths = List.generate(
        rows, (index) => childrenWidths[index] ?? 0.0,
        growable: false);

    var maxWidth = childWidths.fold<double>(
      0.0,
      (previousValue, element) => max(previousValue, element),
    );

    width = maxWidth;

    return AxisConfiguration(
      size: width,
      offsetTable: childWidths.map((e) => 0.0).toList().asMap(),
    );
  }

  @override
  AxisConfiguration<int> performVerticalIntrinsicLayout({
    required Map<int, double> childrenHeights,
    required Map<int, double> childrenBaselines,
    bool isComputingIntrinsics = false,
  }) {
    final childHeights = List.generate(
      rows,
      (index) => childrenBaselines[index] ?? 0.0,
      growable: false,
    );
    final childDepth = List.generate(rows, (index) {
      final height = childrenBaselines[index];
      return height != null ? childrenHeights[index]! - height : 0.0;
    }, growable: false);

    final rowHeights = List.filled(rows, 0.7 * arrayskip, growable: false);
    final rowDepth = List.filled(rows, 0.3 * arrayskip, growable: false);
    for (var i = 0; i < rows; i++) {
      rowHeights[i] = max(rowHeights[i], childHeights[i]);
      rowDepth[i] = max(rowDepth[i], childDepth[i]);
    }

    var pos = 0.0;
    final rowBaselinePos = List.filled(rows, 0.0, growable: false);

    for (var i = 0; i < rows; i++) {
      hLinePos[i] = pos;
      pos += rowHeights[i];
      rowBaselinePos[i] = pos;
      pos += rowDepth[i];
    }
    hLinePos[rows] = pos;

    totalHeight = pos;

    // Calculate position for each children
    final childPos = List.generate(rows, (index) {
      return rowBaselinePos[index] - childHeights[index];
    }, growable: false);

    if (!isComputingIntrinsics) {
      this.hLinePos = hLinePos;
    }

    return AxisConfiguration(
      size: totalHeight,
      offsetTable: childPos.asMap(),
    );
  }
}

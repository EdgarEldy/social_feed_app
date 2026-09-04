import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:social_feed_app/app/theme/app_dimens.dart';
import 'package:social_feed_app/core/widgets/adaptive_grid.dart';

void main() {
  group('AdaptiveGrid.columnCountForWidth', () {
    test('returns 1 column for a narrow, mobile-sized width', () {
      expect(AdaptiveGrid.columnCountForWidth(320), 1);
    });

    test('returns 1 column for the widest width still below the mobile breakpoint', () {
      expect(
        AdaptiveGrid.columnCountForWidth(AppDimens.breakpointMobile - 1),
        1,
      );
    });

    test('returns 2 columns exactly at the mobile breakpoint', () {
      expect(
        AdaptiveGrid.columnCountForWidth(AppDimens.breakpointMobile),
        2,
      );
    });

    test('returns 2 columns for the widest width still below the tablet breakpoint', () {
      expect(
        AdaptiveGrid.columnCountForWidth(AppDimens.breakpointTablet - 1),
        2,
      );
    });

    test('returns 3 columns exactly at the tablet breakpoint', () {
      expect(
        AdaptiveGrid.columnCountForWidth(AppDimens.breakpointTablet),
        3,
      );
    });

    test('returns 3 columns for a wide, desktop-sized width', () {
      expect(AdaptiveGrid.columnCountForWidth(1440), 3);
    });
  });

  group('AdaptiveGrid widget', () {
    // The default test surface is 800x600 logical pixels, too narrow to lay
    // out a tablet-width grid without clipping. Widening it up front keeps
    // every width used below entirely on-screen.
    void useWideSurface(WidgetTester tester) {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    Widget buildGrid({required double width, required int childCount}) {
      return MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: AdaptiveGrid(
              children: [
                for (var i = 0; i < childCount; i++)
                  SizedBox(
                    key: ValueKey('item$i'),
                    height: 40,
                    child: Text('item $i'),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('renders a single column below the mobile breakpoint', (
      tester,
    ) async {
      useWideSurface(tester);
      await tester.pumpWidget(
        buildGrid(width: AppDimens.breakpointMobile - 1, childCount: 3),
      );
      await tester.pumpAndSettle();

      final offset0 = tester.getTopLeft(find.byKey(const ValueKey('item0')));
      final offset1 = tester.getTopLeft(find.byKey(const ValueKey('item1')));
      final offset2 = tester.getTopLeft(find.byKey(const ValueKey('item2')));

      // A single column means every item shares the same x position and
      // stacks strictly below the previous one.
      expect(offset0.dx, offset1.dx);
      expect(offset1.dx, offset2.dx);
      expect(offset1.dy, greaterThan(offset0.dy));
      expect(offset2.dy, greaterThan(offset1.dy));
    });

    testWidgets('renders multiple columns at the tablet breakpoint', (
      tester,
    ) async {
      useWideSurface(tester);
      await tester.pumpWidget(
        buildGrid(width: AppDimens.breakpointTablet, childCount: 3),
      );
      await tester.pumpAndSettle();

      final offset0 = tester.getTopLeft(find.byKey(const ValueKey('item0')));
      final offset1 = tester.getTopLeft(find.byKey(const ValueKey('item1')));
      final offset2 = tester.getTopLeft(find.byKey(const ValueKey('item2')));

      // Three columns means all three items land on the same row (same y)
      // at increasing x offsets, rather than stacking.
      expect(offset0.dy, offset1.dy);
      expect(offset1.dy, offset2.dy);
      expect(offset1.dx, greaterThan(offset0.dx));
      expect(offset2.dx, greaterThan(offset1.dx));
    });

    testWidgets('wraps a fourth item onto a second row at the tablet breakpoint', (
      tester,
    ) async {
      useWideSurface(tester);
      await tester.pumpWidget(
        buildGrid(width: AppDimens.breakpointTablet, childCount: 4),
      );
      await tester.pumpAndSettle();

      final firstRowOffset = tester.getTopLeft(
        find.byKey(const ValueKey('item0')),
      );
      final fourthOffset = tester.getTopLeft(
        find.byKey(const ValueKey('item3')),
      );

      expect(fourthOffset.dy, greaterThan(firstRowOffset.dy));
      expect(fourthOffset.dx, firstRowOffset.dx);
    });
  });
}

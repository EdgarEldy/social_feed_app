import 'package:flutter/widgets.dart';

import '../../app/theme/app_dimens.dart';

/// A responsive grid that adapts its column count to the available width.
///
/// Below [AppDimens.breakpointMobile] the content renders as a single
/// column (a typical phone in portrait). Between [AppDimens.breakpointMobile]
/// and [AppDimens.breakpointTablet] it switches to two columns. At or above
/// [AppDimens.breakpointTablet] it uses three columns, a sensible default for
/// tablet and desktop-sized viewports without needing a fourth breakpoint.
///
/// This widget is intentionally generic: it lays out any [children], with no
/// coupling to a specific feature. `feature/posts` reuses it to arrange
/// `PostCard`s in the feed once that branch is built.
///
/// Internally this uses [Wrap] rather than [GridView] so that children with
/// varying intrinsic heights (like post cards with optional images) size
/// themselves naturally instead of being forced into a fixed aspect ratio.
class AdaptiveGrid extends StatelessWidget {
  /// Creates an adaptive grid laying out [children] with a column count
  /// derived from the available width.
  const AdaptiveGrid({
    super.key,
    required this.children,
    this.spacing = AppDimens.spacingMd,
    this.runSpacing = AppDimens.spacingMd,
  });

  /// The items to lay out. Each item occupies exactly one grid cell.
  final List<Widget> children;

  /// The horizontal gap between items in the same row.
  final double spacing;

  /// The vertical gap between rows.
  final double runSpacing;

  /// Resolves the column count for a given available [width], per this
  /// widget's documented breakpoint behavior.
  static int columnCountForWidth(double width) {
    if (width < AppDimens.breakpointMobile) return 1;
    if (width < AppDimens.breakpointTablet) return 2;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = columnCountForWidth(constraints.maxWidth);
        final totalSpacing = spacing * (columnCount - 1);
        // A very large spacing relative to the available width can otherwise
        // drive this negative, which throws a BoxConstraints assertion below.
        final itemWidth = ((constraints.maxWidth - totalSpacing) / columnCount)
            .clamp(0.0, double.infinity);

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

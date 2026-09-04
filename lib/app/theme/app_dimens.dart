/// Numeric design tokens shared across the app: spacing, corner radius, and
/// responsive breakpoints.
///
/// Every widget that needs padding, a gap, or a rounded corner should read
/// from this scale instead of hardcoding a raw number, so the whole app
/// stays visually consistent and a future redesign only touches this one
/// file.
abstract final class AppDimens {
  const AppDimens._();

  // Spacing scale, in logical pixels. Each step is a multiple of a 4px base
  // unit, the convention behind most Material-derived spacing scales, which
  // keeps every gap in the app visually related to every other gap.
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;
  static const double spacingXxl = 48;

  // Corner radius scale, used for cards, buttons, and other rounded
  // surfaces.
  static const double radiusSm = 4;
  static const double radiusMd = 8;
  static const double radiusLg = 16;

  /// A radius large enough to render a fully pill-shaped/circular edge on
  /// any control this app ships (chips, avatars, small buttons).
  static const double radiusFull = 999;

  /// Below this width (in logical pixels), layouts render as a single,
  /// phone-oriented column.
  static const double breakpointMobile = 600;

  /// At or above this width, responsive layouts such as the `AdaptiveGrid`
  /// primitive (built later in `feature/design-system`, reused by
  /// `PostCard` in `feature/posts`) switch to a multi-column, tablet-oriented
  /// layout.
  static const double breakpointTablet = 840;
}

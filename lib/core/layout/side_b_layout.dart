import 'package:flutter/material.dart';

/// Breakpoints and measurements shared by SIDE B screens.
///
/// They use the available logical width, rather than a device model or its
/// physical resolution, so split-screen and orientation changes are handled
/// naturally.
enum SideBScreenSize { compact, medium, expanded }

class SideBLayout {
  SideBLayout._();

  static const compactBreakpoint = 600.0;
  static const expandedBreakpoint = 840.0;
  static const maxContentWidth = 1180.0;

  static SideBScreenSize sizeFor(double width) {
    if (width < compactBreakpoint) return SideBScreenSize.compact;
    if (width < expandedBreakpoint) return SideBScreenSize.medium;
    return SideBScreenSize.expanded;
  }

  static double horizontalPadding(double width) {
    switch (sizeFor(width)) {
      case SideBScreenSize.compact:
        return 20;
      case SideBScreenSize.medium:
        return 32;
      case SideBScreenSize.expanded:
        return 40;
    }
  }

  /// Keeps the home cover editorial on a phone and proportioned on a tablet.
  /// The height is deliberately capped instead of being derived only from
  /// width, preventing an image from taking over a large tablet viewport.
  static double featuredPostHeight(double width) {
    if (sizeFor(width) == SideBScreenSize.compact) {
      return (width * .78).clamp(260.0, 340.0).toDouble();
    }
    return (width * .42).clamp(320.0, 420.0).toDouble();
  }

  static EdgeInsets pageInsets(
    double width, {
    double top = 0,
    double bottom = 24,
  }) {
    final horizontal = horizontalPadding(width);
    return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
  }
}

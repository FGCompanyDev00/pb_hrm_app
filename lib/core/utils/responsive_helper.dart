import 'package:flutter/material.dart';

/// A utility class to make responsive UI easy in Flutter, inspired by Bootstrap
/// and Tailwind CSS breakpoints and responsive design principles.
class ResponsiveHelper {
  // Singleton instance
  static final ResponsiveHelper _instance = ResponsiveHelper._internal();
  factory ResponsiveHelper() => _instance;
  ResponsiveHelper._internal();

  // Breakpoints similar to Bootstrap
  static const double xs = 0; // Extra small (phone)
  static const double sm = 576; // Small (large phones, portrait tablets)
  static const double md = 768; // Medium (landscape tablets)
  static const double lg = 992; // Large (desktops)
  static const double xl = 1200; // Extra large (large desktops)
  static const double xxl = 1400; // Extra extra large (larger desktops)

  /// Current device screen size
  static Size _screenSize = Size.zero;

  /// Initialize responsive helper with MediaQuery data
  static void init(BuildContext context) {
    _screenSize = MediaQuery.of(context).size;
  }

  /// Get the current screen width
  static double get screenWidth => _screenSize.width;

  /// Get the current screen height
  static double get screenHeight => _screenSize.height;

  /// Check if the screen is extra small
  static bool get isXs => screenWidth >= xs && screenWidth < sm;

  /// Check if the screen is small
  static bool get isSm => screenWidth >= sm && screenWidth < md;

  /// Check if the screen is medium
  static bool get isMd => screenWidth >= md && screenWidth < lg;

  /// Check if the screen is large
  static bool get isLg => screenWidth >= lg && screenWidth < xl;

  /// Check if the screen is extra large
  static bool get isXl => screenWidth >= xl && screenWidth < xxl;

  /// Check if the screen is extra extra large
  static bool get isXxl => screenWidth >= xxl;

  /// Check if the screen is mobile (xs or sm)
  static bool get isMobile => isXs || isSm;

  /// Check if the screen is tablet (md)
  static bool get isTablet => isMd;

  /// Check if the screen is desktop (lg, xl, or xxl)
  static bool get isDesktop => isLg || isXl || isXxl;

  /// Returns a value based on screen size
  /// Similar to Bootstrap's responsive utility classes
  static T responsive<T>({
    required T xs,
    T? sm,
    T? md,
    T? lg,
    T? xl,
    T? xxl,
  }) {
    if (isXxl && xxl != null) return xxl;
    if (isXl && xl != null) return xl;
    if (isLg && lg != null) return lg;
    if (isMd && md != null) return md;
    if (isSm && sm != null) return sm;
    return xs;
  }

  /// Get a responsive font size
  static double fontSize(double size) {
    final baseFontScale = screenWidth / 375; // Base on iPhone 8 width
    return size * responsiveFontScale;
  }

  /// Get a responsive font scale factor
  static double get responsiveFontScale {
    final baseFontScale = screenWidth / 375;
    // Clamp the scale to reasonable values
    return baseFontScale.clamp(0.8, 1.4);
  }

  /// Get a responsive padding
  static EdgeInsets responsivePadding({
    double? horizontal,
    double? vertical,
    double? left,
    double? top,
    double? right,
    double? bottom,
    double? all,
  }) {
    final scale = responsiveScale;

    if (all != null) {
      return EdgeInsets.all(all * scale);
    }

    return EdgeInsets.fromLTRB(
      ((left ?? horizontal) ?? 0) * scale,
      ((top ?? vertical) ?? 0) * scale,
      ((right ?? horizontal) ?? 0) * scale,
      ((bottom ?? vertical) ?? 0) * scale,
    );
  }

  /// Get a responsive scale factor
  static double get responsiveScale {
    final baseScale = screenWidth / 375;
    // Clamp the scale to reasonable values
    return baseScale.clamp(0.8, 1.3);
  }

  /// Convert percentage to actual width
  static double percentageWidth(double percentage) {
    return screenWidth * (percentage / 100);
  }

  /// Convert percentage to actual height
  static double percentageHeight(double percentage) {
    return screenHeight * (percentage / 100);
  }

  /// Get responsive grid columns (similar to Bootstrap's 12-column grid)
  static double gridCol(int columns, {int totalColumns = 12}) {
    return percentageWidth((columns / totalColumns) * 100);
  }

  /// Create a responsive grid layout
  static Widget responsiveGrid({
    required List<Widget> children,
    int crossAxisCount = 2,
    double spacing = 10,
    double childAspectRatio = 1.0,
  }) {
    final responsiveCount = responsive(
      xs: crossAxisCount >= 2 ? 2 : 1,
      sm: crossAxisCount >= 2 ? 2 : 1,
      md: crossAxisCount >= 3 ? 3 : crossAxisCount,
      lg: crossAxisCount >= 4 ? 4 : crossAxisCount,
      xl: crossAxisCount,
    );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: responsiveCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}

/// A widget that adapts to different screen sizes
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    Key? key,
    required this.mobile,
    this.tablet,
    this.desktop,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ResponsiveHelper.init(context);

    // Return the appropriate layout based on screen size
    if (ResponsiveHelper.isDesktop && desktop != null) {
      return desktop!;
    }

    if (ResponsiveHelper.isTablet && tablet != null) {
      return tablet!;
    }

    return mobile;
  }
}

/// A responsive text widget that adapts font size automatically
class ResponsiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;
  final double? minFontSize;
  final double fontSize;
  final bool autoScale;

  const ResponsiveText(
    this.text, {
    Key? key,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
    this.minFontSize,
    this.fontSize = 14,
    this.autoScale = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ResponsiveHelper.init(context);

    final finalFontSize =
        autoScale ? ResponsiveHelper.fontSize(fontSize) : fontSize;

    final responsiveStyle = (style ?? const TextStyle()).copyWith(
      fontSize: finalFontSize,
    );

    return Text(
      text,
      style: responsiveStyle,
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
    );
  }
}

/// A widget that creates responsive padding
class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final double? horizontal;
  final double? vertical;
  final double? all;
  final double? left;
  final double? top;
  final double? right;
  final double? bottom;

  const ResponsivePadding({
    Key? key,
    required this.child,
    this.horizontal,
    this.vertical,
    this.all,
    this.left,
    this.top,
    this.right,
    this.bottom,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ResponsiveHelper.init(context);

    return Padding(
      padding: ResponsiveHelper.responsivePadding(
        horizontal: horizontal,
        vertical: vertical,
        all: all,
        left: left,
        top: top,
        right: right,
        bottom: bottom,
      ),
      child: child,
    );
  }
}

/// A widget that creates a responsive grid
class ResponsiveGridView extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double? aspectRatio;
  final int columns;
  final EdgeInsets? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const ResponsiveGridView({
    Key? key,
    required this.children,
    this.spacing = 10,
    this.aspectRatio,
    this.columns = 2,
    this.padding,
    this.shrinkWrap = true,
    this.physics,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ResponsiveHelper.init(context);

    final responsiveCount = ResponsiveHelper.responsive(
      xs: columns > 2 ? 2 : columns,
      sm: columns > 3 ? 3 : columns,
      md: columns > 4 ? 4 : columns,
      lg: columns > 6 ? 6 : columns,
      xl: columns,
    );

    // Calculate aspectRatio based on screen size if not provided
    final childAspectRatio = aspectRatio ??
        (ResponsiveHelper.isMobile
            ? 0.9
            : ResponsiveHelper.isTablet
                ? 1.1
                : 1.3);

    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics ?? const NeverScrollableScrollPhysics(),
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: responsiveCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}

/// A wrapper for container with responsive width constraints
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? maxWidth;
  final double? minWidth;
  final double? height;
  final double? maxHeight;
  final double? minHeight;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Decoration? decoration;
  final Color? color;

  const ResponsiveContainer({
    Key? key,
    required this.child,
    this.width,
    this.maxWidth,
    this.minWidth,
    this.height,
    this.maxHeight,
    this.minHeight,
    this.padding,
    this.margin,
    this.decoration,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ResponsiveHelper.init(context);

    // Apply responsive scaling to the dimensions
    final scale = ResponsiveHelper.responsiveScale;

    return Container(
      width: width != null ? width! * scale : null,
      height: height != null ? height! * scale : null,
      padding: padding,
      margin: margin,
      decoration: decoration,
      color: color,
      constraints: BoxConstraints(
        maxWidth: maxWidth != null ? maxWidth! * scale : double.infinity,
        minWidth: minWidth != null ? minWidth! * scale : 0,
        maxHeight: maxHeight != null ? maxHeight! * scale : double.infinity,
        minHeight: minHeight != null ? minHeight! * scale : 0,
      ),
      child: child,
    );
  }
}

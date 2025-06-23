// linear_loading_indicator.dart
// Google Calendar-style linear loading indicator for smooth data fetching feedback

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class LinearLoadingIndicator extends StatefulWidget {
  final bool isLoading;
  final Color? color;
  final double height;
  final Duration animationDuration;

  const LinearLoadingIndicator({
    super.key,
    required this.isLoading,
    this.color,
    this.height = 3.0,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  LinearLoadingIndicatorState createState() => LinearLoadingIndicatorState();
}

class LinearLoadingIndicatorState extends State<LinearLoadingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _opacityController;
  late Animation<double> _animation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    // Main loading animation controller
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Opacity controller for smooth show/hide
    _opacityController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    // Create smooth wave animation
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // Opacity animation for smooth transitions
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _opacityController,
      curve: Curves.easeInOut,
    ));

    if (widget.isLoading) {
      _startLoading();
    }
  }

  @override
  void didUpdateWidget(LinearLoadingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _startLoading();
      } else {
        _stopLoading();
      }
    }
  }

  void _startLoading() {
    _opacityController.forward();
    _controller.repeat();
  }

  void _stopLoading() {
    _opacityController.reverse();
    _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    _opacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color loadingColor = widget.color ?? Theme.of(context).primaryColor;

    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Container(
            height: widget.height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: loadingColor.withOpacity(0.1),
            ),
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return CustomPaint(
                  painter: _LinearLoadingPainter(
                    progress: _animation.value,
                    color: loadingColor,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _LinearLoadingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _LinearLoadingPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {

    // Create multiple moving segments for smooth loading effect
    const double segmentWidth = 100.0;
    const double totalSegments = 3;

    for (int i = 0; i < totalSegments; i++) {
      double segmentProgress = (progress + (i * 0.3)) % 1.0;
      double startX =
          (segmentProgress * (size.width + segmentWidth)) - segmentWidth;
      double endX = startX + segmentWidth;

      // Create gradient effect for each segment
      final Gradient gradient = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          color.withOpacity(0.0),
          color.withOpacity(0.8),
          color.withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      );

      final Rect rect = Rect.fromLTRB(
        startX.clamp(0.0, size.width),
        0.0,
        endX.clamp(0.0, size.width),
        size.height,
      );

      if (rect.width > 0) {
        final Paint gradientPaint = Paint()
          ..shader = gradient.createShader(rect);

        canvas.drawRect(rect, gradientPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LinearLoadingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

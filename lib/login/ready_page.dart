// ready_page.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:pb_hrsystem/l10n/app_localizations.dart';
import 'package:pb_hrsystem/main.dart';

class ReadyPage extends StatefulWidget {
  const ReadyPage({super.key});

  @override
  ReadyPageState createState() => ReadyPageState();
}

class ReadyPageState extends State<ReadyPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _arrowAnimation;
  double _slidePosition = 0.0;

  // You can adjust this for how “far” the slider handle travels horizontally.
  final double _maxSlideDistance = 250.0;

  @override
  void initState() {
    super.initState();

    // Initialize the animation controller
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Define the slide animation
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: _maxSlideDistance,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    )..addListener(() {
        setState(() {
          _slidePosition = _slideAnimation.value;
        });
      });

    // Define the arrow animation (used for the logo bounce, if desired)
    _arrowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    // Navigate to the main screen when the animation completes
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateSlidePosition(double position) {
    setState(() {
      _slidePosition = position;
    });
  }

  void _handleSlideEnd(BuildContext context) {
    // If user has slid at least halfway, animate the rest
    if (_slidePosition >= _maxSlideDistance / 2) {
      _controller.forward(from: _slidePosition / _maxSlideDistance);
    } else {
      // Otherwise, snap back
      setState(() {
        _slidePosition = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scrollController = ScrollController();

    return Scaffold(
      body: Stack(
        children: [
          // Background image with a fade-in animation
          AnimatedOpacity(
            opacity: 1.0,
            duration: const Duration(milliseconds: 800),
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/ready_bg.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          // Main scrollable content
          Scrollbar(
            controller: scrollController,
            thumbVisibility: true,
            thickness: 8.0,
            radius: const Radius.circular(10),
            scrollbarOrientation: ScrollbarOrientation.right,
            child: SingleChildScrollView(
              controller: scrollController,
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),

                    // Logo with a gentle bounce
                    Center(
                      child: AnimatedBuilder(
                        animation: _arrowAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1.0 + (_arrowAnimation.value * 0.1),
                            child: child,
                          );
                        },
                        child: Image.asset(
                          'assets/logo.png',
                          width: 120,
                          height: 120,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // "Ready to Go" text with fade-in
                    FadeInText(
                      text: AppLocalizations.of(context)!.readyToGo,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      delay: 500,
                    ),
                    const SizedBox(height: 40),

                    // Sliding button with improved layout & triple chevron arrow
                    Center(
                      child: SlidingButton(
                        slidePosition: _slidePosition,
                        maxSlideDistance: _maxSlideDistance,
                        onSlideUpdate: _updateSlidePosition,
                        onSlideEnd: () => _handleSlideEnd(context),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // A "Ready image" with slide-in animation
                    const SlideInImage(
                      imagePath: 'assets/ready_image.png',
                      width: 220,
                      height: 220,
                      delay: 800,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SlidingButton: Rectangular handle with triple "chevron_right" arrows.
// -----------------------------------------------------------------------------
class SlidingButton extends StatefulWidget {
  final double slidePosition;
  final double maxSlideDistance;
  final ValueChanged<double> onSlideUpdate;
  final VoidCallback onSlideEnd;

  const SlidingButton({
    super.key,
    required this.slidePosition,
    required this.maxSlideDistance,
    required this.onSlideUpdate,
    required this.onSlideEnd,
  });

  @override
  State<SlidingButton> createState() => _SlidingButtonState();
}

class _SlidingButtonState extends State<SlidingButton> with SingleTickerProviderStateMixin {
  late AnimationController _arrowController;
  late Animation<Offset> _arrowOffsetAnimation;

  @override
  void initState() {
    super.initState();
    // This controller gently moves the triple arrows left-right
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Shifts the arrow about 4% of its width to the right, then back
    _arrowOffsetAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.04, 0.0),
    ).animate(CurvedAnimation(
      parent: _arrowController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _arrowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Make the slider more sensitive: multiply delta by 1.5
      onPanUpdate: (details) {
        double newPosition = widget.slidePosition + details.delta.dx * 1.5;
        if (newPosition < 0) newPosition = 0;
        if (newPosition > widget.maxSlideDistance) {
          newPosition = widget.maxSlideDistance;
        }
        widget.onSlideUpdate(newPosition);
      },
      onPanEnd: (details) => widget.onSlideEnd(),
      child: SizedBox(
        // The total width is the track (white) + space for the handle on the far right
        width: widget.maxSlideDistance + 20,
        // More compact height to match your Figma style
        height: 60,
        child: Stack(
          children: [
            // Background track (white, pill-shaped, "Get Started" text on the right)
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.green, width: 2),
              ),
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 50.0),
                child: Text(
                  AppLocalizations.of(context)!.getStarted,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),

            // Rectangular handle with triple "chevron_right" arrows
            Positioned(
              left: widget.slidePosition,
              child: SlideTransition(
                position: _arrowOffsetAnimation,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chevron_right, color: Colors.white, size: 20),
                      Icon(Icons.chevron_right, color: Colors.white, size: 20),
                      Icon(Icons.chevron_right, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// FadeInText: Custom fade-in animation for text
// -----------------------------------------------------------------------------
class FadeInText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final int delay;

  const FadeInText({
    super.key,
    required this.text,
    required this.style,
    this.delay = 0,
  });

  @override
  FadeInTextState createState() => FadeInTextState();
}

class FadeInTextState extends State<FadeInText> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_fadeController);

    // Start fade after a delay
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Text(
        widget.text,
        style: widget.style,
        textAlign: TextAlign.center,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SlideInImage: Custom slide-in animation for an image
// -----------------------------------------------------------------------------
class SlideInImage extends StatefulWidget {
  final String imagePath;
  final double width;
  final double height;
  final int delay;

  const SlideInImage({
    super.key,
    required this.imagePath,
    required this.width,
    required this.height,
    this.delay = 0,
  });

  @override
  SlideInImageState createState() => SlideInImageState();
}

class SlideInImageState extends State<SlideInImage> with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0), // Start from below the screen
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _slideController.forward();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Image.asset(
        widget.imagePath,
        width: widget.width,
        height: widget.height,
      ),
    );
  }
}

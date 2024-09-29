import 'package:flutter/material.dart';
import 'package:pb_hrsystem/main.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ReadyPage extends StatefulWidget {
  const ReadyPage({super.key});

  @override
  _ReadyPageState createState() => _ReadyPageState();
}

class _ReadyPageState extends State<ReadyPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _arrowAnimation;
  double _slidePosition = 0.0;
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
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ))
      ..addListener(() {
        setState(() {
          _slidePosition = _slideAnimation.value;
        });
      });

    // Define the arrow animation
    _arrowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

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
    if (_slidePosition >= _maxSlideDistance / 2) {
      _controller.forward(from: _slidePosition / _maxSlideDistance);
    } else {
      setState(() {
        _slidePosition = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use a ScrollController to customize the scrollbar
    final ScrollController _scrollController = ScrollController();

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
          // Main content with smooth scrolling
          Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            thickness: 8.0,
            radius: const Radius.circular(10),
            scrollbarOrientation: ScrollbarOrientation.right,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    // Logo with a bounce animation
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
                    // "Ready to Go" text with a fade-in animation
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
                    // Sliding button with arrow animation
                    Center(
                      child: SlidingButton(
                        slidePosition: _slidePosition,
                        maxSlideDistance: _maxSlideDistance,
                        onSlideUpdate: _updateSlidePosition,
                        onSlideEnd: () => _handleSlideEnd(context),
                        arrowAnimation: _arrowAnimation,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Ready image with a slide-in animation
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

class SlidingButton extends StatelessWidget {
  final double slidePosition;
  final double maxSlideDistance;
  final ValueChanged<double> onSlideUpdate;
  final VoidCallback onSlideEnd;
  final Animation<double> arrowAnimation;

  const SlidingButton({
    super.key,
    required this.slidePosition,
    required this.maxSlideDistance,
    required this.onSlideUpdate,
    required this.onSlideEnd,
    required this.arrowAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        double newPosition = slidePosition + details.delta.dx;
        if (newPosition < 0) newPosition = 0;
        if (newPosition > maxSlideDistance) newPosition = maxSlideDistance;
        onSlideUpdate(newPosition);
      },
      onPanEnd: (details) {
        onSlideEnd();
      },
      child: Stack(
        children: [
          // Background track
          Container(
            width: maxSlideDistance + 60,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(35),
              border: Border.all(color: Colors.green, width: 2),
            ),
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 80.0),
              child: Text(
                AppLocalizations.of(context)!.getStarted,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          // Sliding button with arrow animation
          Positioned(
            left: slidePosition,
            child: Transform.rotate(
              angle: arrowAnimation.value * 0.5,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(35),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom widget for fade-in text animation
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
  _FadeInTextState createState() => _FadeInTextState();
}

class _FadeInTextState extends State<FadeInText> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_fadeController);

    Future.delayed(Duration(milliseconds: widget.delay), () {
      _fadeController.forward();
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

// Custom widget for slide-in image animation
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
  _SlideInImageState createState() => _SlideInImageState();
}

class _SlideInImageState extends State<SlideInImage> with SingleTickerProviderStateMixin {
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
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      _slideController.forward();
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

import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';

class CustomBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  _CustomBottomNavBarState createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);

    _colorAnimation = TweenSequence<Color?>(
      [
        TweenSequenceItem(
          tween: ColorTween(begin: Colors.green, end: Colors.yellow),
          weight: 2.0,
        ),
        TweenSequenceItem(
          tween: ColorTween(begin: Colors.yellow, end: Colors.orange),
          weight: 2.0,
        ),
        TweenSequenceItem(
          tween: ColorTween(begin: Colors.orange, end: Colors.green),
          weight: 2.0,
        ),
      ],
    ).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConvexAppBar(
      style: TabStyle.fixedCircle,
      items: [
        TabItem(
          icon: Transform.translate(
            offset: const Offset(0, 9),
            child: Icon(
              Icons.fingerprint,
              color: widget.currentIndex == 0 ? Colors.orangeAccent : Colors.grey,
              size: 30,
            ),
          ),
        ),
        TabItem(
          icon: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: widget.currentIndex == 1
                      ? Border.all(
                    color: _colorAnimation.value!,
                    width: 4.0,
                  )
                      : null,
                  boxShadow: widget.currentIndex == 1
                      ? [
                    BoxShadow(
                      color: _colorAnimation.value!.withOpacity(0.7),
                      blurRadius: 10.0,
                      spreadRadius: 2.0,
                    ),
                  ]
                      : null,
                ),
                child: const Icon(
                  Icons.home,
                  color: Colors.white,
                  size: 40,
                ),
              );
            },
          ),
        ),
        TabItem(
          icon: Transform.translate(
            offset: const Offset(0, 9),
            child: Icon(
              Icons.apps,
              color: widget.currentIndex == 2 ? Colors.orangeAccent : Colors.grey,
              size: 30,
            ),
          ),
        ),
      ],
      initialActiveIndex: widget.currentIndex,
      onTap: widget.onTap,
      backgroundColor: Colors.white,
      activeColor: Colors.orangeAccent,
      color: Colors.grey,
      height: 40,
      curveSize: 120,
      top: -40,
      shadowColor: Colors.black.withOpacity(0.1),
      elevation: 20,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

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
              color: currentIndex == 0 ? Colors.orangeAccent : Colors.grey,
              size: 30,
            ),
          ),
        ),
        TabItem(
          icon: AnimatedContainer(
            duration: const Duration(milliseconds: 20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: currentIndex == 1
                  ? Border.all(
                color: Colors.greenAccent.withOpacity(0.7),
                width: 4.0,
              )
                  : null,
            ),
            child: const Icon(
              Icons.home,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
        TabItem(
          icon: Transform.translate(
            offset: const Offset(0, 9),
            child: Icon(
              Icons.apps,
              color: currentIndex == 2 ? Colors.orangeAccent : Colors.grey,
              size: 30,
            ),
          ),
        ),
      ],
      initialActiveIndex: currentIndex,
      onTap: onTap,
      backgroundColor: Colors.white,
      activeColor: Colors.orangeAccent,
      color: Colors.grey,
      height: 30,
      curveSize: 80,
      top: -40,
      shadowColor: Colors.black.withOpacity(0.1),
      elevation: 20,
    );
  }
}

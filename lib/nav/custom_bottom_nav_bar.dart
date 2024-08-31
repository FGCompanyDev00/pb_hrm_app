import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDarkMode ? Colors.green : Colors.orangeAccent;

    return ConvexAppBar(
      style: TabStyle.fixedCircle,
      items: const [
        TabItem(icon: Icons.fingerprint),

        TabItem(
          icon: Icon(Icons.home),
        ),
        TabItem(icon: Icons.apps),
      ],
      initialActiveIndex: currentIndex,
      onTap: onTap,
      backgroundColor: Colors.white,
      activeColor: activeColor,
      color: Colors.grey,
      height: 50,
      curveSize: 100,
      top:-20,
    );
  }
}


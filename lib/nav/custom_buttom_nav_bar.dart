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
    return ConvexAppBar(
      style: TabStyle.fixedCircle,
      items: const [
        TabItem(icon: Icons.fingerprint),
        TabItem(icon: Icons.home),
        TabItem(icon: Icons.apps),
      ],
      initialActiveIndex: currentIndex,
      onTap: onTap,
      backgroundColor: Colors.white,
      activeColor: Colors.green,
      color: Colors.grey,
      height: 70,
    );
  }
}
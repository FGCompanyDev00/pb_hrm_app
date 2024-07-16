import 'package:flutter/material.dart';

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
    return BottomAppBar(
      
      notchMargin: 6.0,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _buildIcon(context, Icons.fingerprint, 0),
          const SizedBox(width: 40), // Spacer for the floating action button
          _buildIcon(context, Icons.apps, 2),
        ],
      ),
    );
  }

  Widget _buildIcon(BuildContext context, IconData icon, int index) {
    bool isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        padding: const EdgeInsets.all(10.0),
        decoration: isSelected
            ? BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12.0),
              )
            : null,
        child: Icon(
          icon,
          color: isSelected ? Colors.green : Colors.grey,
        ),
      ),
    );
  }
}

class CustomFloatingActionButton extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomFloatingActionButton({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          backgroundColor: currentIndex == 1 ? Colors.green : Colors.grey,
          onPressed: () => onTap(1),
          child: const Icon(
            Icons.home,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
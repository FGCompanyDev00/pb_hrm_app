// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pb_hrsystem/core/standard/constant_map.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityIndicator extends StatefulWidget {
  const ConnectivityIndicator({super.key});

  @override
  State<ConnectivityIndicator> createState() => _ConnectivityIndicatorState();
}

class _ConnectivityIndicatorState extends State<ConnectivityIndicator>
    with SingleTickerProviderStateMixin {
  bool _hasInternet = true;
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();

    // Setup pulse animation for status changes
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _animationController.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _animationController.forward();
        }
      });

    _animationController.forward();

    // Listen to connectivity changes
    _subscription = connectivityResult.onConnectivityChanged
        .listen(_updateConnectionStatus);
  }

  @override
  void dispose() {
    _subscription.cancel();
    _animationController.dispose();
    super.dispose();
  }

  // Check initial connectivity status
  Future<void> _checkConnectivity() async {
    final results = await connectivityResult.checkConnectivity();
    _updateConnectionStatus(results);
  }

  // Update connection status
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    if (!mounted) return;

    final bool connected = results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.mobile);

    if (connected != _hasInternet) {
      // Restart animation when status changes
      _animationController.reset();
      _animationController.forward();

      setState(() {
        _hasInternet = connected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      top: MediaQuery.of(context).padding.top,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _hasInternet ? Colors.green : Colors.black,
                boxShadow: [
                  BoxShadow(
                    color: _hasInternet
                        ? Colors.green.withOpacity(0.4)
                        : Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

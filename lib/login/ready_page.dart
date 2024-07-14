import 'package:flutter/material.dart';
import 'package:pb_hrsystem/main.dart';

class ReadyPage extends StatefulWidget {
  const ReadyPage({super.key});

  @override
  _ReadyPageState createState() => _ReadyPageState();
}

class _ReadyPageState extends State<ReadyPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _slidePosition = 0.0;
  final double _maxSlideDistance = 200.0;

  // @override
  // void initState() {
  //   super.initState();
  //   _controller = AnimationController(
  //     duration: const Duration(milliseconds: 300),
  //     vsync: this,
  //   );

  //   _animation = Tween<double>(
  //     begin: 0.0,
  //     end: _maxSlideDistance,
  //   ).animate(_controller)
  //     ..addListener(() {
  //       setState(() {
  //         _slidePosition = _animation.value;
  //       });
  //     });

  //   _controller.addStatusListener((status) {
  //     if (status == AnimationStatus.completed) {
  //       Navigator.pushReplacement(
  //         context,
  //         MaterialPageRoute(builder: (context) => const MainScreen()),
  //       );
  //     }
  //   }
  //   );
  // }

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
      setState(() {});
      _controller.forward(from: _slidePosition / _maxSlideDistance);
    } else {
      setState(() {
        _slidePosition = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/ready_bg.png'), // Change background image
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              Center(
                child: Image.asset(
                  'assets/logo.png',
                  width: 120,
                  height: 120,
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  "You're ready to go!",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const Spacer(),
              Center(
                child: SlidingButton(
                  slidePosition: _slidePosition,
                  maxSlideDistance: _maxSlideDistance,
                  onSlideUpdate: _updateSlidePosition,
                  onSlideEnd: () => _handleSlideEnd(context),
                ),
              ),
              const SizedBox(height: 20),
              Image.asset(
                'assets/ready_image.png',
                width: 200,
                height: 200,
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class SlidingButton extends StatelessWidget {
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
          Container(
            width: maxSlideDistance,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 5,
                ),
              ],
            ),
            alignment: Alignment.centerRight,
            child: const Padding(
              padding: EdgeInsets.only(right: 20.0),
              child: Text(
                'Get Started',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          Positioned(
            left: slidePosition,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.arrow_forward,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

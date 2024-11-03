import 'package:flutter/material.dart';
import 'package:pb_hrsystem/login/login_page.dart';
import 'package:pb_hrsystem/main.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/user_model.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Initialize the animation controller
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..forward();

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    // Check session validity after the splash delay
    _checkSessionAfterSplash();
  }

  // Delay splash for a few seconds before checking session validity
  void _checkSessionAfterSplash() {
    Future.delayed(const Duration(seconds: 6)).then((_) async {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.loadUser();

      if (userProvider.isLoggedIn && userProvider.isSessionValid) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOut;

              final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              final offsetAnimation = animation.drive(tween);

              return SlideTransition(
                position: offsetAnimation,
                child: child,
              );
            },
            transitionDuration: const Duration(seconds: 1),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const LoginPage(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOut;

              final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              final offsetAnimation = animation.drive(tween);

              return SlideTransition(
                position: offsetAnimation,
                child: child,
              );
            },
            transitionDuration: const Duration(seconds: 1),
          ),
        );
      }
    });
  }

  // Responsive font size helper
  double getResponsiveFontSize(double baseSize, double screenWidth) {
    return baseSize * (screenWidth / 375);
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;
    final bool isPortrait = screenHeight > screenWidth;

    final double logoSize = isPortrait ? screenWidth * 0.4 : screenHeight * 0.4;
    final double spacing = screenHeight * 0.02;
    final double welcomeFontSize = getResponsiveFontSize(30, screenWidth);
    final double subtitleFontSize = getResponsiveFontSize(18, screenWidth);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Main Content with Fade Transition
          FadeTransition(
            opacity: _animation,
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.05,
                  vertical: screenHeight * 0.02,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo Image
                    Image.asset(
                      'assets/logo.png',
                      width: logoSize,
                      height: logoSize,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(height: spacing * 2),
                    // Welcome Text
                    Text(
                      "Welcome to PSVB",
                      style: TextStyle(
                        fontSize: welcomeFontSize,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF333333),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: spacing),
                    // Subtitle Text
                    Text(
                      "You're not just another customer.\nWe're not just another Bank...",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: subtitleFontSize,
                        color: const Color(0xFF666666),
                      ),
                    ),
                    SizedBox(height: spacing * 3),
                    // Progress Indicator with ShaderMask
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: const Duration(seconds: 2),
                      builder: (context, value, child) {
                        return ShaderMask(
                          shaderCallback: (rect) {
                            return LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: const [
                                Colors.green,
                                Colors.yellow,
                                Colors.orange,
                              ],
                              stops: [value, value + 0.4, value + 0.4],
                            ).createShader(rect);
                          },
                          child: const CircularProgressIndicator(
                            strokeWidth: 5.0,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

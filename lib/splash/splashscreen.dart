import 'package:flutter/material.dart';
import 'package:pb_hrsystem/login/login_page.dart';
import 'package:pb_hrsystem/main.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/user_model.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _rotateAnimation;
  late final Animation<double> _slideAnimation;
  bool _isDisposed = false;

  // Memoize values that don't change
  static const Duration _splashDuration = Duration(seconds: 6);
  static const Duration _animationDuration = Duration(seconds: 2);
  static const Duration _transitionDuration = Duration(seconds: 1);

  // Memoize transition builder
  static Widget _buildTransition(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child) {
    const begin = Offset(1.0, 0.0);
    const end = Offset.zero;
    const curve = Curves.easeInOut;

    final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
    final offsetAnimation = animation.drive(tween);

    return SlideTransition(
      position: offsetAnimation,
      child: child,
    );
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );

    _scaleAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.5, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.bounceOut)),
        weight: 60.0,
      ),
    ]).animate(_controller);

    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * 3.14159, // 360 degrees in radians
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeInOut),
      ),
    );

    _slideAnimation = Tween<double>(
      begin: -50.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.elasticOut),
      ),
    );

    _controller.forward();
    _checkSessionAfterSplash();
  }

  void _checkSessionAfterSplash() {
    Future.delayed(_splashDuration).then((_) async {
      if (_isDisposed) return;

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.loadUser();

      if (_isDisposed) return;

      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                userProvider.isLoggedIn && userProvider.isSessionValid
                    ? const MainScreen()
                    : const LoginPage(),
            transitionsBuilder: _buildTransition,
            transitionDuration: _transitionDuration,
          ),
        );
      }
    });
  }

  // Memoize font size calculation
  static double _getResponsiveFontSize(double baseSize, double screenWidth) {
    return baseSize * (screenWidth / 375);
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;
    final bool isPortrait = screenHeight > screenWidth;

    // Calculate dimensions once
    final double logoSize = isPortrait ? screenWidth * 0.4 : screenHeight * 0.4;
    final double spacing = screenHeight * 0.02;
    final double welcomeFontSize = _getResponsiveFontSize(30, screenWidth);
    final double subtitleFontSize = _getResponsiveFontSize(18, screenWidth);

    final Color welcomeTextColor =
        isDarkMode ? Colors.white70 : const Color(0xFF333333);
    final Color subtitleTextColor =
        isDarkMode ? Colors.white60 : const Color(0xFF666666);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Animated Background with Gradient Overlay
          AnimatedContainer(
            duration: _animationDuration,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                    isDarkMode ? 'assets/darkbg.png' : 'assets/background.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      isDarkMode
                          ? Colors.black.withOpacity(0.3)
                          : Colors.white.withOpacity(0.3),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Main Content with Combined Animations
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05,
                vertical: screenHeight * 0.02,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Logo
                  Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: Transform.rotate(
                      angle: _rotateAnimation.value,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Image.asset(
                            'assets/logo.png',
                            width: logoSize,
                            height: logoSize,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: spacing * 2),
                  // Animated Welcome Text
                  Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        "Welcome to PSVB",
                        style: TextStyle(
                          fontSize: welcomeFontSize,
                          fontWeight: FontWeight.bold,
                          color: welcomeTextColor,
                          shadows: [
                            Shadow(
                              blurRadius: 10,
                              color: isDarkMode
                                  ? Colors.white.withOpacity(0.3)
                                  : Colors.black.withOpacity(0.1),
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  SizedBox(height: spacing),
                  // Animated Subtitle
                  Transform.translate(
                    offset: Offset(0, _slideAnimation.value * 1.2),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        "You're not just another customer.\nWe're not just another Bank...",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: subtitleFontSize,
                          color: subtitleTextColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: spacing * 3),
                  // Enhanced Loading Indicator
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: RepaintBoundary(
                      child: TweenAnimationBuilder(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: _animationDuration,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: 0.8 + (value * 0.2),
                            child: ShaderMask(
                              shaderCallback: (rect) {
                                return SweepGradient(
                                  startAngle: 0.0,
                                  endAngle: value * 3 * 3.14159,
                                  colors: const [
                                    Colors.green,
                                    Colors.yellow,
                                    Colors.orange,
                                    Colors.green,
                                  ],
                                  stops: [0.0, value, value + 0.5, 1.0],
                                ).createShader(rect);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDarkMode
                                        ? Colors.white.withOpacity(0.2)
                                        : Colors.black.withOpacity(0.1),
                                    width: 2,
                                  ),
                                ),
                                child: CircularProgressIndicator(
                                  strokeWidth: 5.0,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isDarkMode
                                        ? Colors.white.withOpacity(0.8)
                                        : Colors.orangeAccent,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller.dispose();
    super.dispose();
  }
}

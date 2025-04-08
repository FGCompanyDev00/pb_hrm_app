import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pb_hrsystem/login/login_page.dart';
import 'package:pb_hrsystem/main.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/user_model.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pb_hrsystem/widgets/update_dialog.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _pulseController;
  late final AnimationController _particleController;
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

    _pulseController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _particleController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

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
        // Add debug prints to help diagnose the issue
        debugPrint('Splash screen session check:');
        debugPrint('- isLoggedIn: ${userProvider.isLoggedIn}');
        debugPrint('- isSessionValid: ${userProvider.isSessionValid}');
        debugPrint('- hasToken: ${userProvider.token.isNotEmpty}');

        // First check if we should go to login page
        if (!userProvider.isLoggedIn ||
            !userProvider.isSessionValid ||
            userProvider.token.isEmpty) {
          debugPrint('Redirecting to login page due to invalid session');
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const LoginPage(),
              transitionsBuilder: _buildTransition,
              transitionDuration: _transitionDuration,
            ),
          );
          return;
        }

        // If we get here, we have a valid session
        debugPrint('Session is valid, proceeding to main screen');
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const MainScreen(),
            transitionsBuilder: _buildTransition,
            transitionDuration: _transitionDuration,
          ),
        );
      }
    });
  }

  void _navigateToNextScreen() async {
    // ... existing navigation logic ...

    // Check for updates when navigating from splash screen
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      _checkForUpdates();
    }
  }

  // Add the update checking method
  Future<void> _checkForUpdates() async {
    if (mounted) {
      await UpdateDialogService.showUpdateDialog(context);
    }
  }

  // Memoize font size calculation
  static double _getResponsiveFontSize(double baseSize, double screenWidth) {
    return baseSize * (screenWidth / 375);
  }

  Widget _buildFloatingParticles(bool isDarkMode) {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        return CustomPaint(
          painter: ParticlePainter(
            _particleController.value,
            isDarkMode ? Colors.white30 : Colors.black12,
          ),
          child: Container(),
        );
      },
    );
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

    final Color primaryColor =
        isDarkMode ? const Color(0xFFDBB342) : Colors.orange;
    final Color accentColor = isDarkMode ? Colors.white70 : Colors.black87;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Animated Background with Gradient Overlay
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                    isDarkMode ? 'assets/darkbg.png' : 'assets/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 800.ms, curve: Curves.easeOut)
              .then()
              .blurXY(
                  begin: 5, end: 0, duration: 1000.ms, curve: Curves.easeOut),

          // Gradient Overlay
          Container(
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
          ).animate().fadeIn(delay: 300.ms, duration: 800.ms),

          // Floating particles animation
          _buildFloatingParticles(isDarkMode),

          // Main Content with Staggered Animations
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05,
                vertical: screenHeight * 0.02,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Logo with pulse effect
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: logoSize * (1 + _pulseController.value * 0.05),
                        height: logoSize * (1 + _pulseController.value * 0.05),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(
                                  0.3 + _pulseController.value * 0.2),
                              blurRadius: 20 + _pulseController.value * 15,
                              spreadRadius: 5 + _pulseController.value * 5,
                            ),
                          ],
                        ),
                        child: child,
                      );
                    },
                    child: Image.asset(
                      'assets/logo.png',
                      width: logoSize,
                      height: logoSize,
                      fit: BoxFit.contain,
                    ),
                  )
                      .animate()
                      .scale(
                          begin: const Offset(0.5, 0.5),
                          end: const Offset(1.0, 1.0),
                          duration: 800.ms,
                          curve: Curves.elasticOut)
                      .rotate(
                          begin: 0.2,
                          end: 0,
                          duration: 1000.ms,
                          curve: Curves.easeOutBack)
                      .moveY(
                          begin: 30,
                          end: 0,
                          duration: 800.ms,
                          curve: Curves.easeOutQuad)
                      .fadeIn(duration: 600.ms),

                  SizedBox(height: spacing * 2),

                  // Animated Welcome Text with modern effects
                  ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        colors: [
                          accentColor,
                          primaryColor,
                          accentColor,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        tileMode: TileMode.mirror,
                      ).createShader(bounds);
                    },
                    child: Text(
                      "Welcome to PSVB Next",
                      style: TextStyle(
                        fontSize: welcomeFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
                  )
                      .animate(delay: 400.ms)
                      .moveY(
                          begin: 30,
                          end: 0,
                          duration: 800.ms,
                          curve: Curves.easeOutQuad)
                      .fadeIn(duration: 800.ms)
                      .then()
                      .animate(
                        onPlay: (controller) =>
                            controller.repeat(reverse: true),
                      )
                      .shimmer(
                        duration: 1800.ms,
                        color: isDarkMode
                            ? primaryColor
                            : primaryColor.withOpacity(0.8),
                      ),

                  SizedBox(height: spacing),

                  // Animated Subtitle
                  Text(
                    "You're not just another customer.\nWe're not just another Bank...",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: subtitleFontSize,
                      color: subtitleTextColor,
                      letterSpacing: 0.5,
                    ),
                  )
                      .animate(delay: 600.ms)
                      .moveY(
                          begin: 30,
                          end: 0,
                          duration: 800.ms,
                          curve: Curves.easeOutQuad)
                      .fadeIn(duration: 800.ms),

                  SizedBox(height: spacing * 3),

                  // Enhanced Loading Indicator with modern design
                  Container(
                    width: 70,
                    height: 70,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          primaryColor.withOpacity(0.3),
                          primaryColor,
                        ],
                        stops: const [0.8, 1.0],
                        transform: GradientRotation(
                            _pulseController.value * 2 * 3.14159),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDarkMode ? Colors.grey[900] : Colors.white,
                      ),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 3.0,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      ),
                    ),
                  )
                      .animate(delay: 800.ms)
                      .scale(
                        begin: const Offset(0.5, 0.5),
                        end: const Offset(1.0, 1.0),
                        duration: 600.ms,
                      )
                      .fadeIn(duration: 600.ms)
                      .then()
                      .animate(
                        onPlay: (controller) => controller.repeat(),
                      )
                      .shimmer(
                        duration: 1800.ms,
                        color: isDarkMode ? Colors.white24 : Colors.black12,
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
    _pulseController.dispose();
    _particleController.dispose();
    super.dispose();
  }
}

// Floating particles animation
class ParticlePainter extends CustomPainter {
  final double animationValue;
  final Color color;
  final List<Offset> _particles = [];

  ParticlePainter(this.animationValue, this.color) {
    // Initialize particles once
    if (_particles.isEmpty) {
      for (int i = 0; i < 30; i++) {
        _particles.add(Offset(
          0.1 + 0.8 * (i % 5) / 4, // x position
          0.1 + 0.8 * (i ~/ 5) / 5, // y position
        ));
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < _particles.length; i++) {
      // Calculate particle position with animation
      final offset = _particles[i];
      final x =
          size.width * offset.dx + 20 * sin(animationValue * 2 * 3.14159 + i);
      final y = size.height * offset.dy +
          20 * cos(animationValue * 2 * 3.14159 + i * 0.5);

      // Calculate particle size with animation (make it pulse)
      final radius = 2 + 1 * sin(animationValue * 2 * 3.14159 + i * 0.7);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => true;
}

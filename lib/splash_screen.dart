import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'login_screen.dart';
import 'storage_service.dart';
import 'sync_service.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({
    super.key,
    required this.nextScreen,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  String _status = 'Preparing your journeys...';

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _animationController.forward();

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      setState(() {
        _status = 'Preparing your journeys...';
      });

      await StorageService.instance.initialise();

      if (!mounted) return;

      setState(() {
        _status = 'Connecting to TravelMate...';
      });

      await SyncService.instance.start();

      if (!mounted) return;

      setState(() {
        _status = 'Checking your account...';
      });

      // Keep the splash visible long enough for the animation.
      await Future<void>.delayed(
        const Duration(milliseconds: 1800),
      );

      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        _openHome();
      } else {
        _openLogin();
      }
    } catch (_) {
      if (!mounted) return;

      // If initialization fails, don't leave the user trapped
      // on the splash screen.
      setState(() {
        _status = 'Starting TravelMate...';
      });

      await Future<void>.delayed(
        const Duration(milliseconds: 1000),
      );

      if (!mounted) return;

      _openLogin();
    }
  }

  void _openLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  void _openHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => widget.nextScreen,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TravelMateColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Teal decorative circle.
            Positioned(
              top: -100,
              right: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: const BoxDecoration(
                  color: TravelMateColors.teal100,
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // Coral decorative circle.
            Positioned(
              bottom: -110,
              left: -90,
              child: Container(
                width: 270,
                height: 270,
                decoration: const BoxDecoration(
                  color: TravelMateColors.coral100,
                  shape: BoxShape.circle,
                ),
              ),
            ),

            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // TravelMate logo.
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: TravelMateColors.navy900,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: TravelMateColors.navy900
                                  .withValues(alpha: 0.18),
                              blurRadius: 25,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(
                              Icons.explore_rounded,
                              size: 62,
                              color: TravelMateColors.teal500,
                            ),
                            Positioned(
                              right: 21,
                              top: 19,
                              child: Container(
                                width: 17,
                                height: 17,
                                decoration: BoxDecoration(
                                  color: TravelMateColors.coral500,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: TravelMateColors.navy900,
                                    width: 3,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      const Text(
                        'TravelMate',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: TravelMateColors.navy900,
                          letterSpacing: -1,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Plan. Explore. Remember.',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: TravelMateColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 44),

                      SizedBox(
                        width: 180,
                        child: LinearProgressIndicator(
                          minHeight: 5,
                          borderRadius: BorderRadius.circular(10),
                          backgroundColor:
                              TravelMateColors.backgroundAlt,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(
                            TravelMateColors.teal500,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      AnimatedSwitcher(
                        duration: const Duration(
                          milliseconds: 250,
                        ),
                        child: Text(
                          _status,
                          key: ValueKey<String>(_status),
                          style: const TextStyle(
                            fontSize: 13,
                            color: TravelMateColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: Text(
                'Your journey, beautifully organised.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: TravelMateColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
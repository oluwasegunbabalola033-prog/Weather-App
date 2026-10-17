// ============================================================================
// FILE: lib/signup.dart
// PURPOSE: Authentication & Sign-In Screen (WeatherScreen Widget)
// 
// NARRATION / ARCHITECTURE:
// - Provides Google Sign-In authentication integrated with Firebase Auth.
// - Features a custom-painted animated background (`WeatherPainter`) rendering 
//   sun glow, moving rain drops, and floating cloud vector shapes.
// - Renders a custom Material 3 Google Sign-In button (`GoogleButton`).
// ============================================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:weather_app/routes.dart';

/// Helper function to perform Google Sign-In and exchange tokens with Firebase
Future<UserCredential?> signInWithGoogle() async {
  final GoogleSignIn googleSignIn = GoogleSignIn();

  // Disconnect/sign out first so Google Account chooser is always shown
  // instead of silently auto-selecting the previously used account
  try {
    await googleSignIn.signOut();
  } catch (_) {}

  // 1. Trigger the native Google Account selector popup overlay
  final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

  // 2. Return null safely if user cancels or dismisses the dialog
  if (googleUser == null) return null;

  // 3. Extract authentication security tokens (accessToken & idToken)
  final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

  // 4. Convert security tokens into Firebase AuthCredential
  final AuthCredential credential = GoogleAuthProvider.credential(
    accessToken: googleAuth.accessToken,
    idToken: googleAuth.idToken,
  );

  // 5. Authenticate user with Firebase and return account profile
  return await FirebaseAuth.instance.signInWithCredential(credential);
}

/// Sign-In Screen Widget featuring Weather Vector Animation & Google Auth Button
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen>
    with SingleTickerProviderStateMixin {
  /// AnimationController driving the continuous rain and cloud motion
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 3-second continuous loop for rain drops and cloud bobbing
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 16.0,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Spacer(),

                        // Widget Section: Free-floating Animated Weather Graphic
                        Center(
                          child: SizedBox(
                            width: min(screenSize.width * 0.85, 320),
                            height: min(screenSize.height * 0.35, 260),
                            child: AnimatedBuilder(
                              animation: _controller,
                              builder: (context, child) {
                                return CustomPaint(
                                  painter: WeatherPainter(
                                    progress: _controller.value,
                                    isDarkMode: isDarkMode,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 60),

                        // Widget Section: Welcome Title Text
                        Text(
                          'Welcome to Weather App',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            fontSize: 20,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Widget Section: Subtitle Description Text
                        Text(
                          'Your live forecast, weather updates, and more, just one tap away',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            fontSize: 10.5,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 125),

                        // Widget Section: Google Sign-In Button
                        GoogleButton(
                          onPressed: () async {
                            try {
                              final userCredential = await signInWithGoogle();
                              if (userCredential != null && context.mounted) {
                                // Navigate to Home Weather Screen upon successful authentication
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  AppRoutes.weather,
                                  (route) => false,
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Sign-In Error: $e'),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Data class representing individual rain drop positions and speeds
class RainDrop {
  double x;
  double y;
  double length;
  double speed;

  RainDrop({
    required this.x,
    required this.y,
    required this.length,
    required this.speed,
  });
}

/// CustomPainter rendering sun glow, procedural rain drops, and vector cloud
class WeatherPainter extends CustomPainter {
  final double progress;
  final bool isDarkMode;

  static final Random _random = Random(42);
  static final List<RainDrop> _drops = List.generate(
    60,
    (_) => RainDrop(
      x: _random.nextDouble() * 300,
      y: _random.nextDouble() * 260,
      length: 10 + _random.nextDouble() * 15,
      speed: 250 + _random.nextDouble() * 180,
    ),
  );

  WeatherPainter({required this.progress, this.isDarkMode = false});

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / 300;
    final double scaleY = size.height / 260;
    final double scale = min(scaleX, scaleY);

    // 1. Draw Sun in the background with pulse glow
    final sunPaint = Paint()
      ..color = Colors.amber.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final sunGlowPaint = Paint()
      ..color = Colors.amber.withValues(alpha: 0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 22 * scale);

    final sunCenter = Offset(80 * scaleX, 70 * scaleY);
    final sunRadius = 35.0 * scale;

    canvas.drawCircle(
      sunCenter,
      sunRadius + (sin(progress * 2 * pi) * 5 * scale),
      sunGlowPaint,
    );
    canvas.drawCircle(sunCenter, sunRadius, sunPaint);

    // 2. Draw Moving Rain Drops
    final rainPaint = Paint()
      ..color = isDarkMode
          ? Colors.lightBlueAccent.withValues(alpha: 0.7)
          : Colors.blue.withValues(alpha: 0.6)
      ..strokeWidth = 1.8 * scale
      ..strokeCap = StrokeCap.round;

    for (var drop in _drops) {
      double currentY =
          (drop.y * scaleY + (progress * drop.speed * scaleY)) % size.height;
      double currentX = (drop.x * scaleX) - (currentY * 0.1);

      canvas.drawLine(
        Offset(currentX, currentY),
        Offset(currentX - (2 * scaleX), currentY + (drop.length * scaleY)),
        rainPaint,
      );
    }

    // 3. Draw Vector Cloud in the foreground
    final cloudColor = isDarkMode
        ? const Color(0xFFE2E8F0).withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.95);

    final cloudPaint = Paint()
      ..color = cloudColor
      ..style = PaintingStyle.fill;

    final cloudShadowPaint = Paint()
      ..color = isDarkMode
          ? Colors.black.withValues(alpha: 0.4)
          : Colors.black12
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * scale);

    final cloudOffset = Offset(0, sin(progress * 2 * pi) * 4 * scaleY);

    final cloudPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(160 * scaleX, 140 * scaleY) + cloudOffset,
            width: 170 * scaleX,
            height: 55 * scaleY,
          ),
          Radius.circular(28 * scale),
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(120 * scaleX, 115 * scaleY) + cloudOffset,
          radius: 32 * scale,
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(178 * scaleX, 105 * scaleY) + cloudOffset,
          radius: 42 * scale,
        ),
      );

    canvas.drawPath(cloudPath.shift(Offset(0, 6 * scaleY)), cloudShadowPaint);
    canvas.drawPath(cloudPath, cloudPaint);
  }

  @override
  bool shouldRepaint(covariant WeatherPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isDarkMode != isDarkMode;
  }
}

/// Custom Google Sign-In Button Widget
class GoogleButton extends StatelessWidget {
  final VoidCallback onPressed;

  const GoogleButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade300,
          foregroundColor: Colors.black87,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            SizedBox(
              width: 24,
              height: 24,
              child: CustomPaint(painter: GoogleLogoPainter()),
            ),
            SizedBox(width: 12),
            Flexible(
              child: Text(
                'Continue with Google',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3C4043),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// CustomPainter drawing the multi-colored Google 'G' Logo
class GoogleLogoPainter extends CustomPainter {
  const GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final Offset center = Offset(cx, cy);
    final double outerRadius = size.width / 2;
    final double innerRadius = outerRadius * 0.52;
    final double barHeight = outerRadius - innerRadius;

    final Paint bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    final Paint redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;

    final Paint yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;

    final Paint greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;

    double degToRad(double deg) => deg * pi / 180.0;

    Path createRingSegment(double startDeg, double sweepDeg) {
      final path = Path();
      final outerRect = Rect.fromCircle(center: center, radius: outerRadius);
      final innerRect = Rect.fromCircle(center: center, radius: innerRadius);

      final startRad = degToRad(startDeg);
      final sweepRad = degToRad(sweepDeg);
      final endRad = startRad + sweepRad;

      path.arcTo(outerRect, startRad, sweepRad, false);
      path.lineTo(
        cx + innerRadius * cos(endRad),
        cy + innerRadius * sin(endRad),
      );
      path.arcTo(innerRect, endRad, -sweepRad, false);
      path.close();
      return path;
    }

    // 1. Red (Top Arc)
    canvas.drawPath(createRingSegment(-145, 107), redPaint);

    // 2. Yellow (Left Arc)
    canvas.drawPath(createRingSegment(130, 85), yellowPaint);

    // 3. Green (Bottom Arc)
    canvas.drawPath(createRingSegment(38, 92), greenPaint);

    // 4. Blue (Bottom-Right Arc)
    canvas.drawPath(createRingSegment(0, 38), bluePaint);

    // 5. Blue Horizontal Bar
    final Rect barRect = Rect.fromLTRB(
      cx,
      cy - (barHeight / 2),
      cx + outerRadius,
      cy + (barHeight / 2),
    );
    canvas.drawRect(barRect, bluePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

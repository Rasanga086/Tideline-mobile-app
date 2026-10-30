import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../core/theme.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';

/// The Tideline wordmark: wave icon + name, as in the website's header.
class TidelineWordmark extends StatelessWidget {
  const TidelineWordmark({super.key, this.onDark = false, this.size = 20});
  final bool onDark;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        Icons.waves,
        color: onDark ? TL.tide300 : TL.tide600,
        size: size * 1.25,
      ),
      SizedBox(width: size * 0.45),
      Text(
        'Tideline',
        style: TextStyle(
          fontFamily: TL.fontDisplay,
          fontSize: size,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.03 * size,
          color: onDark ? Colors.white : TL.textStrong,
        ),
      ),
    ],
  );
}

/// The three layered waves from the website's landing page (Landing.jsx `Waves`), drawn
/// from the same curves so the shapes match.
class TidelineWaves extends StatelessWidget {
  const TidelineWaves({super.key, this.height = 90});
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: const CustomPaint(painter: _WavesPainter()),
  );
}

class _WavesPainter extends CustomPainter {
  const _WavesPainter();

  // (colour, baseline, amplitude) on the website's 180-unit-high viewBox.
  static const _layers = [
    (TL.sea500, 90.0, 60.0),
    (TL.tide600, 110.0, 50.0),
    (TL.sea950, 130.0, 35.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final sy = size.height / 180;
    // Two full wave periods across the width, like the 2880-unit SVG shown at half width.
    final period = size.width / 2;
    for (final (colour, base, amp) in _layers) {
      final path = Path()..moveTo(0, base * sy);
      for (var x = 0.0; x < size.width; x += period) {
        path.cubicTo(
          x + period / 3,
          (base - amp) * sy,
          x + period * 2 / 3,
          (base + amp) * sy,
          x + period,
          base * sy,
        );
      }
      path
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = colour);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Opens sign-in on top of the current screen. Once signed in, the app returns to the
/// signed-in home (see TidelineApp), like the website's /login → back to the app.
void openSignIn(BuildContext context, AuthController auth) => Navigator.of(
  context,
).push(MaterialPageRoute(builder: (_) => LoginScreen(auth: auth)));

void openRegister(BuildContext context, AuthController auth) => Navigator.of(
  context,
).push(MaterialPageRoute(builder: (_) => RegisterScreen(auth: auth)));

/// For a guest, asks them to sign in and returns false; for a signed-in user returns true.
/// Use before any action the API only allows signed-in accounts to take.
Future<bool> ensureSignedIn(
  BuildContext context,
  AuthController auth, {
  required String reason,
}) async {
  if (auth.isAuthenticated) return true;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sign in to continue',
              style: Theme.of(sheet).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(reason, style: Theme.of(sheet).textTheme.bodyMedium),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                Navigator.pop(sheet);
                openSignIn(context, auth);
              },
              child: const Text('Sign in'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () {
                Navigator.pop(sheet);
                openRegister(context, auth);
              },
              child: const Text('Join Tideline'),
            ),
          ],
        ),
      ),
    ),
  );
  return false;
}

/// Inline card shown to guests in place of an action, e.g. "Sign in to confirm or dispute
/// this report." — the website shows the same sentence with a Sign in link.
class SignInPrompt extends StatelessWidget {
  const SignInPrompt({super.key, required this.auth, required this.message});
  final AuthController auth;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
    decoration: BoxDecoration(
      color: TL.sea100,
      borderRadius: BorderRadius.circular(TL.radiusMd),
    ),
    child: Row(
      children: [
        const Icon(Icons.lock_outline, size: 18, color: TL.sea600),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ),
        TextButton(
          onPressed: () => openSignIn(context, auth),
          child: const Text('Sign in'),
        ),
      ],
    ),
  );
}

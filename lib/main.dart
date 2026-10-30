import 'package:flutter/material.dart';

import 'auth/auth_controller.dart';
import 'core/api_client.dart';
import 'core/theme.dart';
import 'screens/console_shell.dart';
import 'screens/home_shell.dart';
import 'screens/landing_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(TidelineApp(auth: AuthController(ApiClient())..init()));
}

class TidelineApp extends StatefulWidget {
  const TidelineApp({super.key, required this.auth});
  final AuthController auth;

  @override
  State<TidelineApp> createState() => _TidelineAppState();
}

class _TidelineAppState extends State<TidelineApp> {
  final _navigator = GlobalKey<NavigatorState>();
  bool _wasSignedIn = false;

  @override
  void initState() {
    super.initState();
    _wasSignedIn = widget.auth.isAuthenticated;
    widget.auth.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  /// Signing out (or an expired token) closes any screens pushed on top of the signed-in
  /// home, so they never stay visible over the landing page. Signing in from a guest screen
  /// (sign-in pushed over the feed, say) likewise returns to the new signed-in home.
  void _onAuthChanged() {
    final signedIn = widget.auth.isAuthenticated;
    if (_wasSignedIn != signedIn) {
      _navigator.currentState?.popUntil((route) => route.isFirst);
    }
    _wasSignedIn = signedIn;
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    return MaterialApp(
      navigatorKey: _navigator,
      title: 'Tideline',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: ListenableBuilder(
        listenable: auth,
        builder: (context, _) {
          if (!auth.ready) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          // Visitors start on the public front page, as on the website.
          if (!auth.isAuthenticated) return LandingScreen(auth: auth);
          // Administrators and government officers work from the console, as on the website.
          return auth.user!.isOfficial
              ? ConsoleShell(auth: auth)
              : HomeShell(auth: auth);
        },
      ),
    );
  }
}

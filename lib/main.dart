import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/user_details_screen.dart';
import 'services/api_client.dart';
import 'services/session_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient().init();
  runApp(const FitrybeApp());
}

class FitrybeApp extends StatelessWidget {
  const FitrybeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'fitrybe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const _SessionGate(),
    );
  }
}

/// Resolves where a returning user lands: the feed, the unfinished onboarding
/// wizard, or the welcome screen. A stored token can still be rejected by the
/// server (expired refresh token, deleted account), so the session is verified
/// against `/auth/me` before trusting it.
class _SessionGate extends StatefulWidget {
  const _SessionGate();

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  late Future<Map<String, dynamic>?> _bootstrap;

  @override
  void initState() {
    super.initState();
    _bootstrap = SessionService().load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _bootstrap,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppTheme.darkBackground,
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryOrange),
            ),
          );
        }

        final user = snapshot.data;
        if (user == null) return const WelcomeScreen();
        if (user['onboardingCompleted'] != true) return const UserDetailsScreen();
        return const HomeScreen();
      },
    );
  }
}

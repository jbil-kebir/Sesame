import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/catalogue_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/pin_setup_screen.dart';
import 'services/pin_service.dart';

void main() {
  runApp(const SesameApp());
}

class SesameApp extends StatelessWidget {
  const SesameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sésame',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const AppRouter(),
      routes: {
        // Après l'onboarding → configuration du PIN obligatoire
        '/home': (_) => const PinSetupScreen(),
      },
    );
  }
}

/// Redirige selon l'état de l'application :
/// - Premier lancement → CatalogueScreen (onboarding)
/// - PIN non configuré  → PinSetupScreen
/// - PIN configuré      → LockScreen
class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  @override
  void initState() {
    super.initState();
    _router();
  }

  Future<void> _router() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;
    if (!mounted) return;

    if (!onboardingDone) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const CatalogueScreen(
            premierLancement: true,
            urlsExistantes: {},
          ),
        ),
      );
      return;
    }

    final pinConfigure = await PinService().estConfigure();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => pinConfigure
            ? const LockScreen()
            : const PinSetupScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1565C0),
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

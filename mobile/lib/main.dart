import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config/theme.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/main_screen.dart';
import 'screens/movie_detail_screen.dart';
import 'screens/player_screen.dart';
import 'services/auth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.background,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const PeerPlayApp());
}

class PeerPlayApp extends StatelessWidget {
  const PeerPlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PeerPlay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AuthGate(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/main': (_) => const MainScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/movie_detail') {
          final movieId = settings.arguments as String;
          return MaterialPageRoute(builder: (_) => MovieDetailScreen(movieId: movieId), settings: settings);
        }
        if (settings.name == '/player') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => PlayerScreen(
              movieId: args['movieId'] as String,
              title: args['title'] as String,
              magnetLink: args['magnetLink'] as String?,
            ),
            settings: settings,
            fullscreenDialog: true,
          );
        }
        return null;
      },
    );
  }
}

/// Checks auth state and routes to login or main
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _isAuthenticated;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final authed = await AuthService.isAuthenticated();
    if (mounted) setState(() => _isAuthenticated = authed);
  }

  @override
  Widget build(BuildContext context) {
    // Always go to MainScreen — movie browsing is public.
    // Login/register are accessible from Settings when needed.
    return const MainScreen();
  }
}

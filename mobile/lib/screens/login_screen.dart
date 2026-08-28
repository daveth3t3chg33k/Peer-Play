import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _loading = false;
  String _error = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    try {
      await AuthService.login(email, password);
      if (mounted) Navigator.pushReplacementNamed(context, '/main');
    } catch (e) {
      setState(() => _error = 'Login failed. Please try again.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.12),

              // Brand
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  boxShadow: [
                    BoxShadow(color: AppTheme.primary.withOpacity(0.35), blurRadius: 20, spreadRadius: 2),
                  ],
                ),
                child: const Center(
                  child: Text('P', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              const Text('PeerPlay', style: TextStyle(fontSize: AppTheme.fontSizeHeading, fontWeight: FontWeight.w800, color: AppTheme.text, letterSpacing: -0.5)),
              const SizedBox(height: AppTheme.spacingXs),
              const Text('Stream free. Watch anywhere.', style: TextStyle(fontSize: AppTheme.fontSizeBody, color: AppTheme.textSecondary)),

              const SizedBox(height: AppTheme.spacingXxxl),

              // Error
              if (_error.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  margin: const EdgeInsets.only(bottom: AppTheme.spacingBase),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                  ),
                  child: Text(_error, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.error, fontSize: AppTheme.fontSizeSmall)),
                ),

              // Email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                style: const TextStyle(fontSize: AppTheme.fontSizeBodyLarge, color: AppTheme.text),
                decoration: InputDecoration(
                  hintText: 'Email',
                  prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20, color: AppTheme.textTertiary),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),

              // Password
              TextField(
                controller: _passwordController,
                obscureText: !_showPassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleLogin(),
                style: const TextStyle(fontSize: AppTheme.fontSizeBodyLarge, color: AppTheme.text),
                decoration: InputDecoration(
                  hintText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: AppTheme.textTertiary),
                  suffixIcon: IconButton(
                    icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20, color: AppTheme.textTertiary),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingSm),

              // Sign In button
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Sign In', style: TextStyle(fontSize: AppTheme.fontSizeBodyLarge, fontWeight: FontWeight.w700, color: Colors.white)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                          ],
                        ),
                ),
              ),

              // Forgot password
              TextButton(
                onPressed: () {},
                child: const Text('Forgot password?', style: TextStyle(fontSize: AppTheme.fontSizeBody, color: AppTheme.primary)),
              ),

              const SizedBox(height: AppTheme.spacingXxl),

              // Sign Up
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?", style: TextStyle(fontSize: AppTheme.fontSizeBody, color: AppTheme.textSecondary)),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/register'),
                    child: const Text(' Sign Up', style: TextStyle(fontSize: AppTheme.fontSizeBody, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

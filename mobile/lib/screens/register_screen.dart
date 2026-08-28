import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _showPassword = false;
  bool _loading = false;
  String _error = '';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }

    setState(() { _loading = true; _error = ''; });
    try {
      await AuthService.register(email, password, name);
      if (mounted) Navigator.pushReplacementNamed(context, '/main');
    } catch (e) {
      setState(() => _error = 'Registration failed.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXl, vertical: AppTheme.spacingXxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.08),

              // Brand
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  boxShadow: [
                    BoxShadow(color: AppTheme.primary.withOpacity(0.35), blurRadius: 20, spreadRadius: 2),
                  ],
                ),
                child: const Center(
                  child: Text('P', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              const Text('Create Account', style: TextStyle(fontSize: AppTheme.fontSizeHeading, fontWeight: FontWeight.w800, color: AppTheme.text, letterSpacing: -0.5)),
              const SizedBox(height: AppTheme.spacingXs),
              const Text('Join PeerPlay today', style: TextStyle(fontSize: AppTheme.fontSizeBody, color: AppTheme.textSecondary)),

              const SizedBox(height: AppTheme.spacingXxl),

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

              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                style: const TextStyle(fontSize: AppTheme.fontSizeBodyLarge, color: AppTheme.text),
                decoration: const InputDecoration(
                  hintText: 'Display Name',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20, color: AppTheme.textTertiary),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                style: const TextStyle(fontSize: AppTheme.fontSizeBodyLarge, color: AppTheme.text),
                decoration: const InputDecoration(
                  hintText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline_rounded, size: 20, color: AppTheme.textTertiary),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),

              TextField(
                controller: _passwordController,
                obscureText: !_showPassword,
                textInputAction: TextInputAction.next,
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
              const SizedBox(height: AppTheme.spacingMd),

              TextField(
                controller: _confirmController,
                obscureText: !_showPassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleRegister(),
                style: const TextStyle(fontSize: AppTheme.fontSizeBodyLarge, color: AppTheme.text),
                decoration: const InputDecoration(
                  hintText: 'Confirm Password',
                  prefixIcon: Icon(Icons.lock_outline_rounded, size: 20, color: AppTheme.textTertiary),
                ),
              ),
              const SizedBox(height: AppTheme.spacingSm),

              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Create Account', style: TextStyle(fontSize: AppTheme.fontSizeBodyLarge, fontWeight: FontWeight.w700, color: Colors.white)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: AppTheme.spacingXxl),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account?', style: TextStyle(fontSize: AppTheme.fontSizeBody, color: AppTheme.textSecondary)),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(' Sign In', style: TextStyle(fontSize: AppTheme.fontSizeBody, fontWeight: FontWeight.w700, color: AppTheme.primary)),
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

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

    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await AuthService.register(email, password, name);
      if (mounted) Navigator.pushReplacementNamed(context, '/main');
    } catch (e) {
      final msg = e.toString();
      String friendly = 'Registration failed. Please try again.';
      if (msg.contains('409')) friendly = 'An account with this email already exists';
      else if (msg.contains('400')) friendly = 'Please check your input';
      else if (msg.contains('500')) friendly = 'Server error. Try again later.';
      else if (msg.contains('Connection') || msg.contains('timeout')) friendly = 'No connection to server';
      setState(() => _error = friendly);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.1),

              Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(AppTheme.rMd),
                  ),
                  child: const Center(
                    child: Text('P', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.xxl),
              const Center(
                child: Text('Create Account', style: TextStyle(fontSize: AppTheme.heading, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              ),
              const SizedBox(height: AppTheme.sm),
              const Center(
                child: Text('Start streaming for free', style: TextStyle(fontSize: AppTheme.body, color: AppTheme.textSecondary)),
              ),

              const SizedBox(height: AppTheme.xxxl),

              if (_error.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.md),
                  margin: const EdgeInsets.only(bottom: AppTheme.base),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.rSm),
                  ),
                  child: Text(_error, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.primary, fontSize: AppTheme.small)),
                ),

              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(hintText: 'Display name', prefixIcon: Icon(Icons.person_outline_rounded, size: 20, color: AppTheme.textMuted)),
              ),
              const SizedBox(height: AppTheme.md),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(hintText: 'Email address', prefixIcon: Icon(Icons.mail_outline_rounded, size: 20, color: AppTheme.textMuted)),
              ),
              const SizedBox(height: AppTheme.md),

              TextField(
                controller: _passwordController,
                obscureText: !_showPassword,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: AppTheme.textMuted),
                  suffixIcon: IconButton(
                    icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20, color: AppTheme.textMuted),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.md),

              TextField(
                controller: _confirmController,
                obscureText: !_showPassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleRegister(),
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(hintText: 'Confirm password', prefixIcon: Icon(Icons.lock_outline_rounded, size: 20, color: AppTheme.textMuted)),
              ),

              const SizedBox(height: AppTheme.xl),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Create Account', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),

              const SizedBox(height: AppTheme.xxl),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account?', style: TextStyle(color: AppTheme.textSecondary, fontSize: AppTheme.body)),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(' Sign In', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: AppTheme.body)),
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

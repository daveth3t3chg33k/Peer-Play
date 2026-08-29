import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Section header — clean label with no icons
class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.base),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: AppTheme.subtitle,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

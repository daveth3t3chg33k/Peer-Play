import 'package:flutter/material.dart';
import '../config/theme.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  const EmptyState({super.key, required this.icon, required this.title, required this.description, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppTheme.textMuted),
            const SizedBox(height: AppTheme.md),
            Text(title, style: const TextStyle(fontSize: AppTheme.subtitle, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: AppTheme.xs),
            Text(description, textAlign: TextAlign.center, style: const TextStyle(fontSize: AppTheme.body, color: AppTheme.textSecondary)),
            if (action != null) ...[
              const SizedBox(height: AppTheme.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../config/theme.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              title,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeSubtitle,
                fontWeight: FontWeight.w700,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXs),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeBody,
                color: AppTheme.textSecondary,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: AppTheme.spacingXl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

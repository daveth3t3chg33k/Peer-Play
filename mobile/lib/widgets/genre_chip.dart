import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Genre chip — clean, minimal filter chip
class GenreChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const GenreChip({super.key, required this.label, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        margin: const EdgeInsets.only(right: AppTheme.sm),
        decoration: BoxDecoration(
          color: selected ? AppTheme.textPrimary : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.rRound),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppTheme.small,
            fontWeight: FontWeight.w600,
            color: selected ? AppTheme.background : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Vault screen — download management, clean minimal layout
class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(AppTheme.base, AppTheme.xxl, AppTheme.base, AppTheme.sm),
            child: Text('Downloads', style: TextStyle(fontSize: AppTheme.heading, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.5)),
          ),

          // Storage indicator
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppTheme.base),
            padding: const EdgeInsets.all(AppTheme.base),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(AppTheme.rMd)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Storage', style: TextStyle(fontSize: AppTheme.body, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: AppTheme.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: const LinearProgressIndicator(value: 0, backgroundColor: AppTheme.surfaceElevated, valueColor: AlwaysStoppedAnimation(AppTheme.textPrimary), minHeight: 4),
                ),
                const SizedBox(height: AppTheme.sm),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0 MB used', style: TextStyle(fontSize: AppTheme.caption, color: AppTheme.textSecondary)),
                    Text('16 GB available', style: TextStyle(fontSize: AppTheme.caption, color: AppTheme.textMuted)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.xxxl),

          // Empty state
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.download_rounded, size: 44, color: AppTheme.textMuted),
                const SizedBox(height: AppTheme.md),
                const Text('No Downloads', style: TextStyle(fontSize: AppTheme.subtitle, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                const SizedBox(height: AppTheme.xs),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppTheme.xxxl),
                  child: Text(
                    'Movies you download will appear here for offline viewing.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: AppTheme.body, color: AppTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: AppTheme.xl),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.surfaceElevated),
                  child: const Text('Browse Movies', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

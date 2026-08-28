import 'package:flutter/material.dart';
import '../config/theme.dart';

class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Padding(
            padding: EdgeInsets.fromLTRB(AppTheme.spacingBase, AppTheme.spacingXxl, AppTheme.spacingBase, AppTheme.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My Vault', style: TextStyle(fontSize: AppTheme.fontSizeHeading, fontWeight: FontWeight.w800, color: AppTheme.text, letterSpacing: -0.5)),
                SizedBox(height: AppTheme.spacingXs),
                Text('Downloaded for offline viewing', style: TextStyle(fontSize: AppTheme.fontSizeBody, color: AppTheme.textSecondary)),
              ],
            ),
          ),

          // Storage card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingBase),
            padding: const EdgeInsets.all(AppTheme.spacingBase),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.storage_rounded, size: 18, color: AppTheme.primary),
                    const SizedBox(width: AppTheme.spacingSm),
                    const Text('Storage', style: TextStyle(fontSize: AppTheme.fontSizeBody, fontWeight: FontWeight.w600, color: AppTheme.text)),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingSm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: 0,
                    backgroundColor: AppTheme.surfaceLight,
                    valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0 MB used', style: TextStyle(fontSize: AppTheme.fontSizeCaption, color: AppTheme.textSecondary)),
                    Text('16 GB available', style: TextStyle(fontSize: AppTheme.fontSizeCaption, color: AppTheme.textTertiary)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacingXxl),

          // Empty state
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('📥', style: TextStyle(fontSize: 48)),
                const SizedBox(height: AppTheme.spacingSm),
                const Text('No Downloads Yet', style: TextStyle(fontSize: AppTheme.fontSizeSubtitle, fontWeight: FontWeight.w700, color: AppTheme.text)),
                const SizedBox(height: AppTheme.spacingXs),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingXxxl),
                  child: Text(
                    'Movies you download will appear here. Watch them anytime, even offline.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: AppTheme.fontSizeBody, color: AppTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXl),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.movie_rounded, color: Colors.white, size: 16),
                  label: const Text('Browse Movies', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: AppTheme.fontSizeBodyLarge)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                  ),
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

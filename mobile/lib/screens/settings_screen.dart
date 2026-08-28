import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoDl = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(AppTheme.spacingBase, AppTheme.spacingXxl, AppTheme.spacingBase, AppTheme.spacingMd),
            child: Text('Settings', style: TextStyle(fontSize: AppTheme.fontSizeHeading, fontWeight: FontWeight.w800, color: AppTheme.text, letterSpacing: -0.5)),
          ),

          // Account
          _buildSection('Account', [
            _buildRow(Icons.person_outline_rounded, AppTheme.primary, 'Profile', value: 'Edit', onTap: () {}),
            _buildDivider(),
            _buildRow(Icons.language_rounded, AppTheme.accentBlue, 'Email', value: 'user@email.com'),
            _buildDivider(),
            _buildRow(Icons.logout_rounded, AppTheme.error, 'Sign Out', onTap: () async {
              await AuthService.logout();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            }),
          ]),

          // Downloads
          _buildSection('Downloads', [
            _buildRow(Icons.download_rounded, AppTheme.accent, 'Auto-download on WiFi',
              trailing: Switch(
                value: _autoDl,
                onChanged: (v) => setState(() => _autoDl = v),
                activeColor: AppTheme.primary,
                activeTrackColor: AppTheme.primaryDark,
                inactiveTrackColor: AppTheme.surfaceLight,
                thumbColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected) ? AppTheme.primary : AppTheme.textTertiary),
              ),
            ),
            _buildDivider(),
            _buildRow(Icons.movie_rounded, AppTheme.accentPurple, 'Download Quality', value: '1080p'),
            _buildDivider(),
            _buildRow(Icons.download_rounded, AppTheme.textTertiary, 'Clear Cache', value: '0 MB'),
          ]),

          // Playback
          _buildSection('Playback', [
            _buildRow(Icons.play_circle_outline_rounded, AppTheme.accent, 'Auto-play Next', value: 'On'),
          ]),

          // About
          _buildSection('About', [
            _buildRow(Icons.info_outline_rounded, AppTheme.accentBlue, 'Version', value: '1.0.0'),
            _buildDivider(),
            _buildRow(Icons.shield_rounded, AppTheme.primary, 'Privacy Policy'),
            _buildDivider(),
            _buildRow(Icons.description_rounded, AppTheme.textTertiary, 'Terms of Service'),
            _buildDivider(),
            _buildRow(Icons.balance_rounded, AppTheme.textTertiary, 'Open Source Licenses'),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingBase),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppTheme.spacingLg),
          Text(
            title.toUpperCase(),
            style: const TextStyle(fontSize: AppTheme.fontSizeCaption, fontWeight: FontWeight.w700, color: AppTheme.textTertiary, letterSpacing: 1),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              border: Border.all(color: AppTheme.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(IconData icon, Color iconColor, String label, {String? value, Widget? trailing, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingBase, vertical: AppTheme.spacingMd + 2),
        child: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: AppTheme.fontSizeBodyLarge, fontWeight: FontWeight.w500, color: AppTheme.text)),
            ),
            if (trailing != null) trailing,
            if (trailing == null && value != null)
              Text(value, style: const TextStyle(fontSize: AppTheme.fontSizeBody, color: AppTheme.textTertiary)),
            if (trailing == null)
              const SizedBox(width: AppTheme.spacingXs),
            if (trailing == null)
              const Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 0.5, color: AppTheme.border, margin: const EdgeInsets.only(left: 52));
  }
}

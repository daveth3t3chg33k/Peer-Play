import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';

/// Settings screen — clean grouped list layout
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
            padding: EdgeInsets.fromLTRB(AppTheme.base, AppTheme.xxl, AppTheme.base, AppTheme.md),
            child: Text('Settings', style: TextStyle(fontSize: AppTheme.heading, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.5)),
          ),

          _buildSection('Account', [
            _buildRow(Icons.person_outline_rounded, 'Profile', trailing: const Text('Edit', style: TextStyle(color: AppTheme.textSecondary, fontSize: AppTheme.body))),
            _buildDivider(),
            _buildRow(Icons.mail_outline_rounded, 'Email', trailing: const Text('user@email.com', style: TextStyle(color: AppTheme.textSecondary, fontSize: AppTheme.body))),
            _buildDivider(),
            _buildRow(Icons.logout_rounded, 'Sign Out', trailing: null, onTap: () async {
              await AuthService.logout();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            }, iconColor: AppTheme.primary),
          ]),

          _buildSection('Downloads', [
            _buildRow(Icons.download_rounded, 'Auto-download on WiFi', trailing: Switch(
              value: _autoDl,
              onChanged: (v) => setState(() => _autoDl = v),
              activeColor: AppTheme.textPrimary,
              activeTrackColor: AppTheme.surfaceElevated,
              inactiveTrackColor: AppTheme.surface,
              thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? AppTheme.textPrimary : AppTheme.textMuted),
            )),
            _buildDivider(),
            _buildRow(Icons.high_quality_rounded, 'Download Quality', trailing: const Text('1080p', style: TextStyle(color: AppTheme.textSecondary, fontSize: AppTheme.body))),
            _buildDivider(),
            _buildRow(Icons.delete_outline_rounded, 'Clear Cache', trailing: const Text('0 MB', style: TextStyle(color: AppTheme.textSecondary, fontSize: AppTheme.body))),
          ]),

          _buildSection('Playback', [
            _buildRow(Icons.play_circle_outline_rounded, 'Auto-play Next', trailing: const Text('On', style: TextStyle(color: AppTheme.textSecondary, fontSize: AppTheme.body))),
          ]),

          _buildSection('About', [
            _buildRow(Icons.info_outline_rounded, 'Version', trailing: const Text('1.0.0', style: TextStyle(color: AppTheme.textSecondary, fontSize: AppTheme.body))),
            _buildDivider(),
            _buildRow(Icons.shield_outlined, 'Privacy Policy'),
            _buildDivider(),
            _buildRow(Icons.description_outlined, 'Terms of Service'),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppTheme.lg),
          Text(title.toUpperCase(), style: TextStyle(fontSize: AppTheme.caption, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 1)),
          const SizedBox(height: AppTheme.sm),
          Container(
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(AppTheme.rMd)),
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(IconData icon, String label, {Widget? trailing, VoidCallback? onTap, Color? iconColor}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.base, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? AppTheme.textSecondary),
            const SizedBox(width: AppTheme.md),
            Expanded(child: Text(label, style: const TextStyle(fontSize: AppTheme.bodyLg, fontWeight: FontWeight.w500, color: AppTheme.textPrimary))),
            if (trailing != null) trailing,
            if (trailing != null) const SizedBox(width: AppTheme.xs),
            if (trailing != null) const Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 0.5, color: AppTheme.divider, margin: const EdgeInsets.only(left: 44));
  }
}

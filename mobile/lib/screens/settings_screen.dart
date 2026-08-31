import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/movie.dart';
import '../services/auth_service.dart';

/// Settings screen — clean grouped list layout, reacts to auth state.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoDl = false;
  User? _user;
  bool _authChecked = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getCurrentUser();
    if (mounted) setState(() { _user = user; _authChecked = true; });
  }

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

          // Account section — shows login/register or profile based on auth state
          _buildSection('Account', _authChecked
            ? (_user != null ? _buildAuthenticatedAccount() : _buildUnauthenticatedAccount())
            : [_buildRow(Icons.hourglass_empty_rounded, 'Loading...')]
          ),

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

  List<Widget> _buildAuthenticatedAccount() {
    return [
      _buildRow(Icons.person_outline_rounded, 'Profile', trailing: Text(_user?.displayName ?? 'User', style: const TextStyle(color: AppTheme.textSecondary, fontSize: AppTheme.body))),
      _buildDivider(),
      _buildRow(Icons.mail_outline_rounded, 'Email', trailing: Text(_user?.email ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: AppTheme.body), overflow: TextOverflow.ellipsis)),
      _buildDivider(),
      _buildRow(Icons.logout_rounded, 'Sign Out', trailing: null, onTap: () => _showLogoutConfirmation(), iconColor: AppTheme.primary),
    ];
  }

  List<Widget> _buildUnauthenticatedAccount() {
    return [
      _buildRow(Icons.login_rounded, 'Sign In', trailing: null, onTap: () async {
        await Navigator.pushNamed(context, '/login');
        // Refresh auth state after returning from login
        _loadUser();
      }, iconColor: AppTheme.primary),
      _buildDivider(),
      _buildRow(Icons.person_add_outlined, 'Create Account', trailing: null, onTap: () async {
        await Navigator.pushNamed(context, '/register');
        // Refresh auth state after returning from register
        _loadUser();
      }),
      const SizedBox(height: AppTheme.sm),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.base),
        child: Text(
          'Sign in to save bookmarks, watch history, and sync across devices.',
          style: TextStyle(fontSize: AppTheme.small, color: AppTheme.textMuted, height: 1.4),
        ),
      ),
    ];
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

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.rMd)),
        title: const Text('Sign Out', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: const Text(
          'Are you sure you want to sign out? You will need to sign in again to access bookmarks and watch history.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: AppTheme.body, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.logout();
              if (mounted) setState(() => _user = null);
            },
            child: const Text('Sign Out', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 0.5, color: AppTheme.divider, margin: const EdgeInsets.only(left: 44));
  }
}

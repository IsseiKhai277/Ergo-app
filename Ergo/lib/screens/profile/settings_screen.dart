import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: Size.zero,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService.signOut();
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;

    try {
      await AuthService.sendPasswordResetEmail(user!.email!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Password reset email sent to ${user.email}'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Account Section ──────────────────────────────────────────────
          _buildSectionLabel('Account'),
          const SizedBox(height: 8),
          _buildSettingsCard([
            _buildTile(
              icon: Icons.lock_outline_rounded,
              iconColor: AppColors.primary,
              title: 'Change Password',
              subtitle: 'Send reset link to your email',
              onTap: () => _changePassword(context),
            ),
            const Divider(height: 1, indent: 56),
            _buildTile(
              icon: Icons.logout_rounded,
              iconColor: AppColors.error,
              title: 'Logout',
              subtitle: 'Sign out of your account',
              titleColor: AppColors.error,
              onTap: () => _logout(context),
            ),
          ]),
          const SizedBox(height: 20),

          // ── Notifications Section ─────────────────────────────────────────
          _buildSectionLabel('Notifications'),
          const SizedBox(height: 8),
          _buildSettingsCard([
            _buildToggleTile(
              icon: Icons.notifications_outlined,
              iconColor: const Color(0xFFF59E0B),
              title: 'Push Notifications',
              subtitle: 'Receive alerts for new messages and jobs',
              initialValue: true,
            ),
            const Divider(height: 1, indent: 56),
            _buildToggleTile(
              icon: Icons.email_outlined,
              iconColor: AppColors.accent,
              title: 'Email Notifications',
              subtitle: 'Receive email updates',
              initialValue: true,
            ),
          ]),
          const SizedBox(height: 20),

          // ── Privacy Section ───────────────────────────────────────────────
          _buildSectionLabel('Privacy'),
          const SizedBox(height: 8),
          _buildSettingsCard([
            _buildToggleTile(
              icon: Icons.visibility_outlined,
              iconColor: const Color(0xFF8B5CF6),
              title: 'Profile Visibility',
              subtitle: 'Allow others to find your profile',
              initialValue: true,
            ),
            const Divider(height: 1, indent: 56),
            _buildToggleTile(
              icon: Icons.location_on_outlined,
              iconColor: const Color(0xFFEF4444),
              title: 'Show Location',
              subtitle: 'Display your city on your profile',
              initialValue: false,
            ),
          ]),
          const SizedBox(height: 20),

          // ── App Info ──────────────────────────────────────────────────────
          _buildSectionLabel('App'),
          const SizedBox(height: 8),
          _buildSettingsCard([
            _buildTile(
              icon: Icons.info_outline_rounded,
              iconColor: AppColors.textSecondary,
              title: 'About Ergo',
              subtitle: 'Version 1.0.0',
              onTap: () {},
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textHint,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Color? titleColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: titleColor ?? AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppColors.textHint, size: 20),
      onTap: onTap,
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool initialValue,
  }) {
    return _ToggleTile(
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      initialValue: initialValue,
    );
  }
}

// ─── Stateful toggle helper ──────────────────────────────────────────────────
class _ToggleTile extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool initialValue;

  const _ToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.initialValue,
  });

  @override
  State<_ToggleTile> createState() => _ToggleTileState();
}

class _ToggleTileState extends State<_ToggleTile> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: widget.iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(widget.icon, color: widget.iconColor, size: 20),
      ),
      title: Text(
        widget.title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        widget.subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: Switch(
        value: _value,
        onChanged: (v) => setState(() => _value = v),
        activeColor: AppColors.primary,
      ),
    );
  }
}

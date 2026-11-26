import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/di/injection.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_card.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/domain/auth_repository.dart';
import '../../auth/domain/phone_checks.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../auth/presentation/auth_state.dart';
import '../../auth/presentation/forgot_password_cubit.dart';
import '../../auth/presentation/forgot_password_state.dart';

// Profile: who you are, your orders and cards, and sign out (CUS-6).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ForgotPasswordCubit>(
      create: (_) => sl<ForgotPasswordCubit>(),
      // Google users have no password here, so we hide that row.
      child: ProfileView(
        canChangePassword: !sl<AuthRepository>().isGoogleUser,
      ),
    );
  }
}

// Public so widget tests can give it cubits of their own.
class ProfileView extends StatelessWidget {
  const ProfileView({super.key, required this.canChangePassword});

  final bool canChangePassword;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ForgotPasswordCubit, ForgotPasswordState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: _onResetChanged,
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, auth) {
          final user = auth.user;

          return Scaffold(
            appBar: AppBar(title: const Text('Profile')),
            body: user == null
                ? const SizedBox.shrink()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      _Header(user: user),
                      const SizedBox(height: 20),
                      const _SectionTitle('Account'),
                      _MenuCard(
                        rows: [
                          _Row(
                            icon: Icons.edit_rounded,
                            title: 'Edit name and phone',
                            onTap: () => context.push(AppRoutes.editProfile),
                          ),
                          if (canChangePassword)
                            _Row(
                              icon: Icons.lock_reset_rounded,
                              title: 'Change password',
                              onTap: () => _confirmReset(context, user.email),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const _SectionTitle('Orders and payment'),
                      _MenuCard(
                        rows: [
                          _Row(
                            icon: Icons.receipt_long_rounded,
                            title: 'My orders',
                            // My orders is a tab, so switch to it.
                            onTap: () => context.go(AppRoutes.myOrders),
                          ),
                          _Row(
                            icon: Icons.credit_card_rounded,
                            title: 'My cards',
                            onTap: () => context.push(AppRoutes.myCards),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const _SectionTitle('App'),
                      _MenuCard(
                        rows: [
                          _Row(
                            icon: Icons.settings_rounded,
                            title: 'App settings',
                            subtitle: 'Animations, test cards, and About',
                            onTap: () => context.push(AppRoutes.settings),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.dangerRed,
                          backgroundColor: AppTheme.dangerBg,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () => _confirmSignOut(context),
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Sign out'),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  void _onResetChanged(BuildContext context, ForgotPasswordState state) {
    final message = switch (state.status) {
      ForgotPasswordStatus.sent =>
        'We sent a reset link to your email. Please check your inbox.',
      ForgotPasswordStatus.failure =>
        state.errorMessage ?? 'Please try again.',
      ForgotPasswordStatus.initial || ForgotPasswordStatus.sending => null,
    };
    if (message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmReset(BuildContext context, String email) async {
    final cubit = context.read<ForgotPasswordCubit>();
    final yes = await _ask(
      context,
      title: 'Change password?',
      message: 'We will send a link to $email. Open it to set a new '
          'password.',
      yesText: 'Send link',
    );
    if (yes) cubit.sendReset(email);
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final auth = context.read<AuthCubit>();
    final yes = await _ask(
      context,
      title: 'Sign out?',
      message: 'You can sign in again any time.',
      yesText: 'Sign out',
      danger: true,
    );
    if (yes) auth.signOut();
  }

  Future<bool> _ask(
    BuildContext context, {
    required String title,
    required String message,
    required String yesText,
    bool danger = false,
  }) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            // The app theme makes FilledButton full width, so we set a size.
            style: FilledButton.styleFrom(
              minimumSize: const Size(88, 40),
              backgroundColor: danger ? AppTheme.dangerRed : null,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(yesText),
          ),
        ],
      ),
    );
    return yes ?? false;
  }
}

// Who you are, in a soft orange card at the top.
class _Header extends StatelessWidget {
  const _Header({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final name = user.name.trim();
    final letter = name.isEmpty ? '?' : name[0].toUpperCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.softOrange,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppTheme.brandOrange,
            child: Text(
              letter,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'No name' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.deepOrange),
                ),
                if (user.phone.isNotEmpty)
                  Text(
                    PhoneChecks.format(user.phone),
                    style: const TextStyle(color: AppTheme.deepOrange),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Label(
                      text: _roleText(user.role),
                      color: AppTheme.deepOrange,
                      background: Colors.white,
                    ),
                    if (user.phone.isEmpty)
                      const _Label(
                        text: 'Phone not added',
                        color: AppTheme.dangerRed,
                        background: AppTheme.dangerBg,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _roleText(UserRole role) {
    return switch (role) {
      UserRole.customer => 'Customer',
      UserRole.restaurant => 'Restaurant owner',
      UserRole.admin => 'Admin',
      UserRole.rider => 'Rider',
    };
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// A white card that holds a group of rows, with thin lines between them.
class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 58),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            SectionIcon(icon: icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({
    required this.text,
    required this.color,
    required this.background,
  });

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/di/injection.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
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
                      const SizedBox(height: 24),
                      const _SectionTitle('Account'),
                      _Row(
                        icon: Icons.edit_outlined,
                        title: 'Edit name and phone',
                        onTap: () => context.push(AppRoutes.editProfile),
                      ),
                      if (canChangePassword)
                        _Row(
                          icon: Icons.lock_reset_outlined,
                          title: 'Change password',
                          onTap: () => _confirmReset(context, user.email),
                        ),
                      const SizedBox(height: 16),
                      const _SectionTitle('Orders and payment'),
                      _Row(
                        icon: Icons.receipt_long_outlined,
                        title: 'My orders',
                        onTap: () => context.push(AppRoutes.myOrders),
                      ),
                      _Row(
                        icon: Icons.credit_card_outlined,
                        title: 'My cards',
                        onTap: () => context.push(AppRoutes.myCards),
                      ),
                      const SizedBox(height: 16),
                      const _SectionTitle('App'),
                      _Row(
                        icon: Icons.settings_outlined,
                        title: 'App settings',
                        subtitle: 'Animations, test cards, and About',
                        onTap: () => context.push(AppRoutes.settings),
                      ),
                      const SizedBox(height: 32),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade200),
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: () => _confirmSignOut(context),
                        icon: const Icon(Icons.logout),
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
              backgroundColor: danger ? Colors.red.shade700 : null,
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

class _Header extends StatelessWidget {
  const _Header({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final grey = Colors.grey.shade600;
    final name = user.name.trim();
    final letter = name.isEmpty ? '?' : name[0].toUpperCase();

    return Column(
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: AppTheme.brandOrange,
          child: Text(
            letter,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          name.isEmpty ? 'No name' : name,
          textAlign: TextAlign.center,
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          user.email,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: grey),
        ),
        const SizedBox(height: 6),
        if (user.phone.isEmpty)
          _Label(
            text: 'Phone not added',
            color: Colors.red.shade700,
            background: Colors.red.shade50,
          )
        else
          Text(
            PhoneChecks.format(user.phone),
            style: textTheme.bodyMedium?.copyWith(color: grey),
          ),
        const SizedBox(height: 10),
        _Label(
          text: _roleText(user.role),
          color: AppTheme.brandOrange,
          background: const Color(0xFFFFF1EA),
        ),
      ],
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
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
            ),
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: AppTheme.brandOrange),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade500),
      onTap: onTap,
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
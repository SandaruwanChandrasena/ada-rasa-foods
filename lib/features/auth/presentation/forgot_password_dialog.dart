import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/di/injection.dart';
import 'forgot_password_cubit.dart';
import 'forgot_password_state.dart';

class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({super.key, this.initialEmail = ''});

  final String initialEmail;

  // Opens the pop-up. Each pop-up gets a fresh cubit.
  // It grows from 92% and fades in, with a soft ease. Closing is the same,
  // in reverse.
  static Future<void> show(BuildContext context, {String email = ''}) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, _, _) => _KeyboardGlide(
        child: BlocProvider(
          create: (_) => sl<ForgotPasswordCubit>(),
          child: ForgotPasswordDialog(initialEmail: email),
        ),
      ),
      transitionBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _send() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    context.read<ForgotPasswordCubit>().sendReset(_emailController.text);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ForgotPasswordCubit, ForgotPasswordState>(
      builder: (context, state) {
        // The form cross-fades into "Check your email", with no jump.
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: state.status == ForgotPasswordStatus.sent
              ? _buildSent(context)
              : _buildForm(context, state),
        );
      },
    );
  }

  Widget _buildSent(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('sent'),
      icon: const Icon(Icons.mark_email_read_outlined, size: 40),
      title: const Text('Check your email'),
      // Firebase does not tell us if the email has an account.
      content: const Text(
        'If this email has an account, we sent a reset link. '
        'Also check your Spam folder.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context, ForgotPasswordState state) {
    final isSending = state.status == ForgotPasswordStatus.sending;

    return AlertDialog(
      key: const ValueKey('form'),
      title: const Text('Reset password'),
      // Scrolls if the keyboard leaves too little room, so nothing is cut.
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Enter your email. We will send you a reset link.'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                enabled: !isSending,
                autofocus: widget.initialEmail.isEmpty,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.send,
                onFieldSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return 'Please enter your email.';
                  if (!email.contains('@') || !email.contains('.')) {
                    return 'This email address is not valid.';
                  }
                  return null;
                },
              ),
              if (state.status == ForgotPasswordStatus.failure) ...[
                const SizedBox(height: 12),
                Text(
                  state.errorMessage ?? 'Something went wrong.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: isSending ? null : _send,
          child: isSending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send link'),
        ),
      ],
    );
  }
}

// Moves the pop-up above the keyboard with a slow, soft glide.
// AlertDialog's own move is fast (100 ms), so we take it over here.
class _KeyboardGlide extends StatelessWidget {
  const _KeyboardGlide({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: keyboard),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      // The dialog no longer sees the keyboard, so it does not move twice.
      child: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: child,
      ),
    );
  }
}
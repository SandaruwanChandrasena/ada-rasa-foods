import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/round_icon_button.dart';
import 'auth_cubit.dart';
import 'auth_state.dart';
import 'auth_header.dart';
import 'google_sign_in_button.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _hidePassword = true;
  bool _hideConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    FocusScope.of(context).unfocus();
    context.read<AuthCubit>().register(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  void _goToSignIn() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.login);
    }
  }

  // Each part fades up one by one, [ms] after the page is ready.
  Widget _enter(int ms, Widget child, {double scaleFrom = 1}) {
    return FadeSlideIn(
      delay: Duration(milliseconds: ms),
      scaleFrom: scaleFrom,
      offset: scaleFrom == 1 ? const Offset(0, 16) : Offset.zero,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listenWhen: (previous, current) =>
          current.errorMessage != null &&
          current.errorMessage != previous.errorMessage,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.errorMessage!)));
      },
      builder: (context, state) {
        final isLoading = state.isLoading;
        final textTheme = Theme.of(context).textTheme;
        final colors = Theme.of(context).colorScheme;

        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              // Swipe the page down to close the keyboard.
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(bottom: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthHeader(
                      imagePath: 'assets/images/burger.jpg',
                      // Photo as big as sign in (255), behind the title.
                      height: 230,
                      photoHeight: 255,
                      // The round back button pops in.
                      topLeft: _enter(150, scaleFrom: 0.7, RoundIconButton(
                        tooltip: 'Back to sign in',
                        icon: Icons.arrow_back_rounded,
                        onPressed: isLoading ? null : _goToSignIn,
                      )),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _enter(220, Text(
                            'Create Account',
                            style: textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          )),
                          const SizedBox(height: 8),
                          _enter(290, Text(
                            'Join us and enjoy delicious food',
                            style: textTheme.bodyLarge?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _enter(360, TextFormField(
                            controller: _nameController,
                            enabled: !isLoading,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              prefixIcon: Icon(
                                Icons.person_rounded,
                                color: AppTheme.brandOrange,
                              ),
                            ),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? 'Please enter your name.'
                                    : null,
                          )),
                          const SizedBox(height: 16),
                          _enter(430, TextFormField(
                            controller: _emailController,
                            enabled: !isLoading,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email address',
                              prefixIcon: Icon(
                                Icons.email_rounded,
                                color: AppTheme.brandOrange,
                              ),
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty) return 'Please enter your email.';
                              if (!email.contains('@') || !email.contains('.')) {
                                return 'This email address is not valid.';
                              }
                              return null;
                            },
                          )),
                          const SizedBox(height: 16),
                          _enter(500, TextFormField(
                            controller: _passwordController,
                            enabled: !isLoading,
                            obscureText: _hidePassword,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(
                                Icons.lock_rounded,
                                color: AppTheme.brandOrange,
                              ),
                              suffixIcon: IconButton(
                                tooltip:
                                    _hidePassword ? 'Show password' : 'Hide password',
                                icon: Icon(
                                  _hidePassword
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                ),
                                onPressed: () =>
                                    setState(() => _hidePassword = !_hidePassword),
                              ),
                            ),
                            validator: (value) => (value == null || value.length < 6)
                                ? 'Use at least 6 characters.'
                                : null,
                          )),
                          const SizedBox(height: 16),
                          _enter(570, TextFormField(
                            controller: _confirmController,
                            enabled: !isLoading,
                            obscureText: _hideConfirm,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Confirm password',
                              prefixIcon: const Icon(
                                Icons.lock_rounded,
                                color: AppTheme.brandOrange,
                              ),
                              suffixIcon: IconButton(
                                tooltip:
                                    _hideConfirm ? 'Show password' : 'Hide password',
                                icon: Icon(
                                  _hideConfirm
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                ),
                                onPressed: () =>
                                    setState(() => _hideConfirm = !_hideConfirm),
                              ),
                            ),
                            // Must match the password field.
                            validator: (value) => value != _passwordController.text
                                ? 'Passwords do not match.'
                                : null,
                          )),
                          const SizedBox(height: 24),
                          _enter(640, FilledButton(
                            onPressed: isLoading ? null : _submit,
                            child: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Create Account',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(Icons.arrow_forward_rounded, size: 20),
                                    ],
                                  ),
                          )),
                          const SizedBox(height: 16),
                          _enter(700, Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'Or continue with',
                                  style:
                                      TextStyle(color: colors.onSurfaceVariant),
                                ),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          )),
                          const SizedBox(height: 16),
                          // Google makes the account if it is new.
                          _enter(760, GoogleSignInButton(
                            onPressed: isLoading
                                ? null
                                : () =>
                                    context.read<AuthCubit>().signInWithGoogle(),
                          )),
                          const SizedBox(height: 8),
                          // Wraps to 2 lines on big phone fonts.
                          _enter(820, Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text('Already have an account?'),
                              TextButton(
                                onPressed: isLoading ? null : _goToSignIn,
                                child: const Text('Sign In'),
                              ),
                            ],
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/app_router.dart';
import '../../../core/widgets/fade_slide_in.dart';
import 'auth_cubit.dart';
import 'auth_state.dart';
import 'auth_header.dart';

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
              padding: const EdgeInsets.only(bottom: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthHeader(
                      imagePath: 'assets/images/burger.jpg',
                      height: 240,
                      // The back button pops in.
                      topLeft: _enter(150, scaleFrom: 0.7, IconButton.filledTonal(
                        tooltip: 'Back to sign in',
                        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
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
                    const SizedBox(height: 32),
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
                              prefixIcon: Icon(Icons.person_outline),
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
                          )),
                          const SizedBox(height: 16),
                          _enter(500, TextFormField(
                            controller: _passwordController,
                            enabled: !isLoading,
                            obscureText: _hidePassword,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip:
                                    _hidePassword ? 'Show password' : 'Hide password',
                                icon: Icon(
                                  _hidePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
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
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip:
                                    _hideConfirm ? 'Show password' : 'Hide password',
                                icon: Icon(
                                  _hideConfirm
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
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
                          const SizedBox(height: 32),
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
                                      Text('Create Account'),
                                      SizedBox(width: 8),
                                      Icon(Icons.arrow_forward, size: 20),
                                    ],
                                  ),
                          )),
                          const SizedBox(height: 16),
                          _enter(710, Row(
                            mainAxisAlignment: MainAxisAlignment.center,
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
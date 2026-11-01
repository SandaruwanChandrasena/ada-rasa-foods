import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/domain/phone_checks.dart';
import '../../auth/presentation/auth_cubit.dart';
import 'edit_profile_cubit.dart';
import 'edit_profile_state.dart';

// Edit name and phone (CUS-6). Pops with true after a good save.
// [forCheckout] shows why the phone is needed, when opened from checkout.
class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key, this.forCheckout = false});

  final bool forCheckout;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<EditProfileCubit>(
      create: (_) => EditProfileCubit(sl()),
      child: EditProfileView(forCheckout: forCheckout),
    );
  }
}

// Public so widget tests can give it cubits of their own.
class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key, this.forCheckout = false});

  final bool forCheckout;

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthCubit>().state.user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(
      text: PhoneChecks.format(user?.phone ?? ''),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _save() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = context.read<AuthCubit>().state.user;
    if (user == null) return;

    context.read<EditProfileCubit>().save(
          user: user,
          name: _nameController.text,
          phone: _phoneController.text,
        );
  }

  void _onChanged(BuildContext context, EditProfileState state) {
    final messenger = ScaffoldMessenger.of(context);

    switch (state.status) {
      case EditProfileStatus.saved:
        final user = state.user;
        if (user == null) return;
        // The new name and phone show everywhere at once.
        context.read<AuthCubit>().updateUser(user);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Profile saved.')));
        Navigator.of(context).pop(true);
      case EditProfileStatus.failure:
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(state.errorMessage ?? 'Please try again.')),
          );
      case EditProfileStatus.editing:
      case EditProfileStatus.saving:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = context.read<AuthCubit>().state.user?.email ?? '';

    return BlocConsumer<EditProfileCubit, EditProfileState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: _onChanged,
      builder: (context, state) {
        final saving = state.isSaving;

        return PopScope(
          // Back is blocked while saving, so the result is never lost.
          canPop: !saving,
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                widget.forCheckout ? 'Add your phone' : 'Edit profile',
              ),
            ),
            body: GestureDetector(
              // Tap outside a box to close the keyboard.
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: Form(
                key: _formKey,
                child: ListView(
                  // Swipe the page down to close the keyboard.
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    if (widget.forCheckout) ...[
                      const _InfoBox(
                        'Add your phone number so the restaurant can '
                        'call you about your order.',
                      ),
                      const SizedBox(height: 20),
                    ],
                    TextFormField(
                      controller: _nameController,
                      enabled: !saving,
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
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      enabled: !saving,
                      autofocus: widget.forCheckout,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _save(),
                      // Only numbers, spaces, and dashes, and at most 10
                      // digits, can be typed.
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9 \-]'),
                        ),
                        const _MaxDigitsFormatter(PhoneChecks.length),
                        LengthLimitingTextInputFormatter(13),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        hintText: '071 234 5678',
                        helperText: 'The restaurant may call you about '
                            'your order.',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (value) => PhoneChecks.error(value ?? ''),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: email,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        helperText: 'Your email cannot be changed.',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: saving ? null : _save,
                      child: saving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save'),
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

class _InfoBox extends StatelessWidget {
  const _InfoBox(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1EA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_in_talk_outlined, color: AppTheme.brandOrange),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

// Stops typing after [maxDigits] digits. Spaces and dashes do not count.
class _MaxDigitsFormatter extends TextInputFormatter {
  const _MaxDigitsFormatter(this.maxDigits);

  final int maxDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = PhoneChecks.digitsOnly(newValue.text).length;
    return digits > maxDigits ? oldValue : newValue;
  }
}
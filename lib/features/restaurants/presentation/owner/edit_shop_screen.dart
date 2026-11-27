import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/phone_checks.dart';
import '../../domain/restaurant.dart';
import 'edit_shop_cubit.dart';

// The owner's Edit shop page: name, cuisine, phone and description.
class EditShopScreen extends StatelessWidget {
  const EditShopScreen({super.key, required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<EditShopCubit>(
      create: (_) => EditShopCubit(sl(), restaurant),
      child: const EditShopView(),
    );
  }
}

// The page itself. Public, so tests can give it a cubit.
class EditShopView extends StatefulWidget {
  const EditShopView({super.key});

  @override
  State<EditShopView> createState() => _EditShopViewState();
}

class _EditShopViewState extends State<EditShopView> {
  late final EditShopState _start = context.read<EditShopCubit>().state;
  late final _name = TextEditingController(text: _start.name);
  late final _cuisine = TextEditingController(text: _start.cuisine);
  late final _phone = TextEditingController(text: _start.phone);
  late final _description = TextEditingController(text: _start.description);

  @override
  void dispose() {
    _name.dispose();
    _cuisine.dispose();
    _phone.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditShopCubit>();

    return BlocConsumer<EditShopCubit, EditShopState>(
      listenWhen: (previous, current) =>
          previous.noticeId != current.noticeId ||
          previous.status != current.status,
      listener: (context, state) {
        final notice = state.notice;
        if (notice != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(notice)));
        }
        if (state.status == EditShopStatus.saved) {
          final navigator = Navigator.of(context);
          if (navigator.canPop()) navigator.pop();
        }
      },
      builder: (context, state) {
        final errors = state.showErrors;
        final busy = state.isSaving;

        return PopScope(
          // Leaving halfway would hide whether the save worked.
          canPop: !busy,
          child: Scaffold(
            appBar: AppBar(title: const Text('Edit shop')),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                TextField(
                  controller: _name,
                  enabled: !busy,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Shop name',
                    prefixIcon: const _FieldIcon(Icons.storefront_rounded),
                    errorText: errors ? state.nameError : null,
                  ),
                  onChanged: cubit.nameChanged,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _cuisine,
                  enabled: !busy,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Cuisine',
                    hintText: 'Sri Lankan',
                    prefixIcon: const _FieldIcon(Icons.restaurant_rounded),
                    errorText: errors ? state.cuisineError : null,
                  ),
                  onChanged: cubit.cuisineChanged,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phone,
                  enabled: !busy,
                  keyboardType: TextInputType.phone,
                  // Only numbers, spaces and dashes, and at most 10 digits,
                  // can be typed. Sri Lankan numbers have 10 digits.
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9 \-]')),
                    const _MaxDigitsFormatter(PhoneChecks.length),
                    LengthLimitingTextInputFormatter(13),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Phone (optional)',
                    hintText: '071 234 5678',
                    prefixIcon: const _FieldIcon(Icons.phone_rounded),
                    errorText: errors ? state.phoneError : null,
                  ),
                  onChanged: cubit.phoneChanged,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _description,
                  enabled: !busy,
                  maxLength: EditShopState.maxDescription,
                  maxLines: 3,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    prefixIcon: const _FieldIcon(Icons.notes_rounded),
                    errorText: errors ? state.descriptionError : null,
                  ),
                  onChanged: cubit.descriptionChanged,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: state.original.address,
                  enabled: false,
                  maxLines: 2,
                  minLines: 1,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    helperText: 'Ask the admin to change the address.',
                    // Grey, because the owner can't change it.
                    prefixIcon: Icon(
                      Icons.location_on_rounded,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: busy ? null : cubit.save,
                  child: busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, size: 20),
                            SizedBox(width: 6),
                            Text('Save'),
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Blocks a key press that would make more than maxDigits digits.
// Spaces and dashes don't count, so "071 234 5678" fits.
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

// An orange rounded icon at the start of a text box.
class _FieldIcon extends StatelessWidget {
  const _FieldIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: AppTheme.brandOrange);
  }
}
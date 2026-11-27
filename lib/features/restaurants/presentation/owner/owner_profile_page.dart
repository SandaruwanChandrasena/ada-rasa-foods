import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../auth/domain/app_user.dart';
import '../../../auth/domain/phone_checks.dart';
import '../../../auth/presentation/auth_cubit.dart';
import 'my_restaurant_cubit.dart';
import 'restaurant_photo_card.dart';

// The owner's Profile tab: restaurant photo, Shop details, Open switch,
// Your account, and Sign out.
class OwnerProfilePage extends StatelessWidget {
  const OwnerProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit cubit) => cubit.state.user);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const RestaurantPhotoCard(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const OpenForOrdersCard(),
                if (user != null) ...[
                  const SizedBox(height: 24),
                  const SectionTitle('Your account'),
                  const SizedBox(height: 10),
                  _AccountRows(user: user),
                ],
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
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final auth = context.read<AuthCubit>();
    final yes = await askOwner(
      context,
      title: 'Sign out?',
      message: 'You can sign in again any time.',
      yesText: 'Sign out',
      danger: true,
    );
    if (yes) auth.signOut();
  }
}

// A yes or no question. Gives false for Cancel or a tap outside.
Future<bool> askOwner(
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

// "Open for orders" with a switch (RES-4). Closing asks first.
class OpenForOrdersCard extends StatelessWidget {
  const OpenForOrdersCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MyRestaurantCubit>().state;
    final restaurant = state.restaurant;
    if (state.view != MyRestaurantView.loaded || restaurant == null) {
      return const SizedBox.shrink();
    }

    final open = restaurant.isOpen;

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            const SectionIcon(icon: Icons.storefront_rounded),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    open ? 'Open for orders' : 'Closed',
                    style: TextStyle(
                      color: open ? AppTheme.textDark : AppTheme.dangerRed,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    open ? 'Customers can order.' : 'Customers cannot order.',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (state.isSaving)
              const SizedBox(
                width: 48,
                height: 32,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              Switch(
                value: open,
                onChanged: state.canSwitch
                    ? (value) => _onChanged(context, value)
                    : null,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _onChanged(BuildContext context, bool open) async {
    final cubit = context.read<MyRestaurantCubit>();
    if (open) {
      await cubit.setOpen(true);
      return;
    }
    final yes = await askOwner(
      context,
      title: 'Close now?',
      message: 'Customers cannot order until you open again.',
      yesText: 'Close',
      danger: true,
    );
    if (yes) await cubit.setOpen(false);
  }
}

// The owner's name, email and phone, as rows like Shop details.
// They can't be changed here, so the rows have no ">".
class _AccountRows extends StatelessWidget {
  const _AccountRows({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final name = user.name.trim();

    return RowsCard(
      children: [
        InfoRow(
          icon: Icons.person_rounded,
          label: name.isEmpty ? 'No name' : name,
          value: 'Restaurant owner',
        ),
        InfoRow(
          icon: Icons.email_rounded,
          label: 'Email',
          value: user.email,
        ),
        if (user.phone.isNotEmpty)
          InfoRow(
            icon: Icons.smartphone_rounded,
            label: 'Your phone',
            value: PhoneChecks.format(user.phone),
          ),
      ],
    );
  }
}
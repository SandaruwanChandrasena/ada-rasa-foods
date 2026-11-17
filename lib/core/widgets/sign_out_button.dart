import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/presentation/auth_cubit.dart';
import 'round_icon_button.dart';

// The round Sign out button for the top bar, shared by every role.
class SignOutButton extends StatelessWidget {
  const SignOutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return RoundIconButton(
      tooltip: 'Sign out',
      icon: Icons.logout_rounded,
      onPressed: () => context.read<AuthCubit>().signOut(),
    );
  }
}
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/presentation/cubit/auth_cubit.dart';

// Temporary home for each role, until the real home screens are built.
class RoleHomePlaceholder extends StatelessWidget {
  const RoleHomePlaceholder({
    super.key,
    required this.title,
    required this.nextStep,
  });

  final String title;
  final String nextStep;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.user;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthCubit>().signOut(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hello, ${user?.name ?? ''}',
                style: textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(user?.email ?? '', textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Chip(label: Text('Role: ${user?.role.name ?? '-'}')),
              const SizedBox(height: 24),
              Text(
                nextStep,
                style: textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
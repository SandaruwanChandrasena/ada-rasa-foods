import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'core/di/injection.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/domain/user_role.dart';
import 'features/auth/presentation/auth_cubit.dart';
import 'features/auth/presentation/auth_state.dart';
import 'features/cart/presentation/cart_cubit.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initDependencies();

  // Not awaited: the splash screen shows until this finishes.
  unawaited(
    sl<AuthCubit>().checkSession(
      minSplashTime: const Duration(milliseconds: 1500),
    ),
  );

  runApp(const AdaRasaApp());
}

class AdaRasaApp extends StatelessWidget {
  const AdaRasaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Shares the one AuthCubit and the one CartCubit with every screen.
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: sl<AuthCubit>()),
        BlocProvider<CartCubit>.value(value: sl<CartCubit>()),
      ],
      child: BlocListener<AuthCubit, AuthState>(
        listenWhen: (previous, current) =>
            _cartUserId(previous) != _cartUserId(current),
        // Loads the cart of the customer who signed in.
        listener: (context, state) =>
            context.read<CartCubit>().setUser(_cartUserId(state)),
        child: MaterialApp.router(
          title: 'Ada Rasa',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          routerConfig: sl<GoRouter>(),
        ),
      ),
    );
  }
}

// Only customers have a cart.
String? _cartUserId(AuthState state) {
  final user = state.user;
  if (user == null || user.role != UserRole.customer) return null;
  return user.uid;
}
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
import 'features/cart/presentation/cart_state.dart';
import 'features/profile/presentation/reduce_animations_cubit.dart';
import 'features/profile/presentation/settings_screen.dart';
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

// Lets the app show a message bar on any screen.
final GlobalKey<ScaffoldMessengerState> _messengerKey =
    GlobalKey<ScaffoldMessengerState>();

class AdaRasaApp extends StatelessWidget {
  const AdaRasaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Shares the one AuthCubit, CartCubit, and animation switch with every
    // screen.
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: sl<AuthCubit>()),
        BlocProvider<CartCubit>.value(value: sl<CartCubit>()),
        BlocProvider<ReduceAnimationsCubit>.value(
          value: sl<ReduceAnimationsCubit>(),
        ),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<AuthCubit, AuthState>(
            listenWhen: (previous, current) =>
                _cartUserId(previous) != _cartUserId(current),
            // Loads the cart of the customer who signed in.
            listener: (context, state) =>
                context.read<CartCubit>().setUser(_cartUserId(state)),
          ),
          BlocListener<CartCubit, CartState>(
            listenWhen: (previous, current) =>
                previous.noticeId != current.noticeId,
            // Cart messages, like "Dolphin Kottu is not available now."
            listener: (context, state) {
              final notice = state.notice;
              if (notice == null) return;
              _messengerKey.currentState
                ?..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(notice),
                    duration: const Duration(seconds: 5),
                  ),
                );
            },
          ),
        ],
        child: MaterialApp.router(
          title: 'Ada Rasa',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          scaffoldMessengerKey: _messengerKey,
          routerConfig: sl<GoRouter>(),
          // Icon sizes follow the phone width, and the in-app
          // "Reduce animations" switch works on every screen.
          builder: (context, child) => AppThemeByWidth(
            child: ReduceAnimationsScope(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
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
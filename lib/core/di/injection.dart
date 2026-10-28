import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../features/auth/data/auth_remote_data_source.dart';
import '../../features/auth/data/auth_repository_impl.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/auth/presentation/auth_cubit.dart';
import '../../features/auth/presentation/forgot_password_cubit.dart';
import '../../features/menu/data/menu_repository_impl.dart';
import '../../features/menu/domain/menu_repository.dart';
import '../../features/restaurants/data/restaurant_repository_impl.dart';
import '../../features/restaurants/domain/restaurant_repository.dart';
import '../../features/restaurants/presentation/restaurant_list_cubit.dart';
import '../router/app_router.dart';

// sl = service locator. One place that creates and connects everything.
final GetIt sl = GetIt.instance;

Future<void> initDependencies() async {
  // Firebase and Google
  sl.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);
  sl.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);

  // Must run once before any Google sign-in.
  await GoogleSignIn.instance.initialize();
  sl.registerLazySingleton<GoogleSignIn>(() => GoogleSignIn.instance);

  // Auth feature
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSource(
      auth: sl(),
      firestore: sl(),
      googleSignIn: sl(),
    ),
  );
  sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl()));
  sl.registerLazySingleton<AuthCubit>(() => AuthCubit(sl()));

  // Factory: a new cubit each time the pop-up opens.
  sl.registerFactory<ForgotPasswordCubit>(() => ForgotPasswordCubit(sl()));

  // Restaurants and menu
  sl.registerLazySingleton<RestaurantRepository>(
    () => RestaurantRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<MenuRepository>(() => MenuRepositoryImpl(sl()));

  // Factory: a new cubit each time the customer home opens.
  sl.registerFactory<RestaurantListCubit>(() => RestaurantListCubit(sl()));

  // Router
  sl.registerLazySingleton<GoRouter>(() => createRouter(sl()));
}
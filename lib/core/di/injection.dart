import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
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

  // Router
  sl.registerLazySingleton<GoRouter>(() => createRouter(sl()));
}
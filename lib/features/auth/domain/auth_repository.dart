import 'app_user.dart';

// All methods throw AuthFailure on error.
abstract class AuthRepository {
  Future<AppUser?> getCurrentUser();

  // Returns null when the user closes the Google picker.
  Future<AppUser?> signInWithGoogle();

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  });

  // New accounts are always customers (AUTH-2).
  Future<AppUser> registerWithEmail({
    required String name,
    required String email,
    required String password,
  });

  // Firebase emails a reset link to this address (AUTH-3).
  Future<void> sendPasswordReset(String email);

  Future<void> signOut();
}
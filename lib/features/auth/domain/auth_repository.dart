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

  // Saves a new name and phone (CUS-6). Gives the updated user.
  // The phone is saved as digits only, like "0712345678".
  Future<AppUser> updateProfile({
    required AppUser user,
    required String name,
    required String phone,
  });

  // True when the user signed in with Google (no password to change).
  bool get isGoogleUser;

  Future<void> signOut();
}
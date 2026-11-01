import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/app_user.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_repository.dart';
import '../domain/phone_checks.dart';
import 'auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote);

  final AuthRemoteDataSource _remote;

  @override
  Future<AppUser?> getCurrentUser() {
    return _run(() async {
      final user = _remote.currentUser;
      if (user == null) return null;

      final profile = await _remote.getOrCreateProfile(user);
      return profile.toEntity();
    });
  }

  @override
  Future<AppUser?> signInWithGoogle() {
    return _run(() async {
      final user = await _remote.signInWithGoogle();
      if (user == null) return null;

      return _loadProfileOrSignOut(user);
    });
  }

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _run(() async {
      final user = await _remote.signInWithEmail(
        email: email,
        password: password,
      );
      if (user == null) throw const AuthFailure('Sign-in failed.');

      return _loadProfileOrSignOut(user);
    });
  }

  @override
  Future<AppUser> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) {
    return _run(() async {
      final user = await _remote.registerWithEmail(
        name: name,
        email: email,
        password: password,
      );
      if (user == null) throw const AuthFailure('Sign-up failed.');

      return _loadProfileOrSignOut(user, name: name);
    });
  }

  @override
  Future<void> sendPasswordReset(String email) {
    return _run(() => _remote.sendPasswordReset(email.trim()));
  }

  @override
  Future<AppUser> updateProfile({
    required AppUser user,
    required String name,
    required String phone,
  }) {
    return _run(() async {
      final cleanName = name.trim();
      final digits = PhoneChecks.digitsOnly(phone);

      // The form checks too. This is the last safety check.
      if (cleanName.isEmpty) {
        throw const AuthFailure('Please enter your name.');
      }
      final phoneError = PhoneChecks.error(phone);
      if (phoneError != null) throw AuthFailure(phoneError);

      await _remote.updateProfile(
        uid: user.uid,
        name: cleanName,
        phone: digits,
      );

      return AppUser(
        uid: user.uid,
        name: cleanName,
        email: user.email,
        phone: digits,
        role: user.role,
        restaurantId: user.restaurantId,
      );
    });
  }

  @override
  bool get isGoogleUser => _remote.isGoogleUser;

  @override
  Future<void> signOut() {
    return _run(_remote.signOut);
  }

  // If the profile fails, sign out, so the user is never half signed in.
  Future<AppUser> _loadProfileOrSignOut(User user, {String? name}) async {
    try {
      final profile = await _remote.getOrCreateProfile(user, name: name);
      return profile.toEntity();
    } catch (_) {
      await _remote.signOut();
      rethrow;
    }
  }

  // Turns every error into an AuthFailure with a simple message.
  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthFailure {
      rethrow;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException: ${e.code} ${e.message}');
      throw AuthFailure(_authMessage(e.code));
    } on FirebaseException catch (e) {
      debugPrint('FirebaseException: ${e.code} ${e.message}');
      throw AuthFailure(_firestoreMessage(e.code));
    } on GoogleSignInException catch (e) {
      debugPrint('GoogleSignInException: ${e.code} ${e.description}');
      throw AuthFailure(_googleMessage(e.code));
    } catch (e) {
      debugPrint('Unknown auth error: $e');
      throw const AuthFailure('Something went wrong. Please try again.');
    }
  }

  String _authMessage(String code) {
    return switch (code) {
      'invalid-email' => 'This email address is not valid.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' =>
        'Email or password is wrong.',
      'email-already-in-use' =>
        'An account already uses this email. Please sign in.',
      'weak-password' => 'Password is too weak. Use at least 6 characters.',
      'user-disabled' => 'This account is turned off.',
      'too-many-requests' => 'Too many tries. Please wait and try again.',
      'network-request-failed' => 'No internet connection. Please try again.',
      'account-exists-with-different-credential' =>
        'This email already uses another sign-in method.',
      _ => 'Sign-in failed. Please try again.',
    };
  }

  String _firestoreMessage(String code) {
    return switch (code) {
      'permission-denied' =>
        'The database blocked this request. Check the Firestore rules.',
      'unavailable' => 'No internet connection. Please try again.',
      'not-found' => 'Your profile was not found. Please sign in again.',
      _ => 'Could not load your profile. Please try again.',
    };
  }

  String _googleMessage(GoogleSignInExceptionCode code) {
    return switch (code) {
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        'Google sign-in is not set up correctly. Check the SHA-1 key in Firebase.',
      _ => 'Google sign-in failed. Please try again.',
    };
  }
}
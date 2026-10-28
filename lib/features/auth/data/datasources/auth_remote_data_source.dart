import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../domain/entities/user_role.dart';
import '../models/app_user_model.dart';

// The only auth file that calls Firebase and Google.
class AuthRemoteDataSource {
  AuthRemoteDataSource({
    required this._auth,
    required this._firestore,
    required this._googleSignIn,
  });

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  User? get currentUser => _auth.currentUser;

  // Returns null when the user closes the Google picker.
  Future<User?> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      final credential = GoogleAuthProvider.credential(idToken: idToken);

      final result = await _auth.signInWithCredential(credential);
      return result.user;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return result.user;
  }

  Future<User?> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await result.user?.updateDisplayName(name);
    return result.user;
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  // Reads users/{uid}. Creates it as a customer if it does not exist yet.
  Future<AppUserModel> getOrCreateProfile(User user, {String? name}) async {
    final doc = _users.doc(user.uid);
    final snapshot = await doc.get();
    final data = snapshot.data();

    if (data != null) {
      return AppUserModel.fromMap(user.uid, data);
    }

    final profileName = name ?? user.displayName ?? '';
    final email = user.email ?? '';

    await doc.set(
      AppUserModel.newCustomerMap(name: profileName, email: email),
    );

    return AppUserModel(
      uid: user.uid,
      name: profileName,
      email: email,
      role: UserRole.customer,
    );
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Not a Google user. We still sign out from Firebase.
    }
    await _auth.signOut();
  }
}
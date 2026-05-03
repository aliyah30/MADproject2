import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Current user
  User? get currentUser => _auth.currentUser;

  // Sign up with email/password and create Firestore profile
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await cred.user!.updateDisplayName(displayName);

    // Create user profile document in Firestore
    final userModel = UserModel(
      uid: cred.user!.uid,
      displayName: displayName,
      email: email,
      createdAt: DateTime.now(),
    );
    await _db
        .collection('users')
        .doc(cred.user!.uid)
        .set(userModel.toMap());

    return cred;
  }

  // Sign in with email/password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Google Sign-In
  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.authenticate();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    final cred = await _auth.signInWithCredential(credential);

    // Create Firestore profile if new user
    final doc =
        await _db.collection('users').doc(cred.user!.uid).get();
    if (!doc.exists) {
      final userModel = UserModel(
        uid: cred.user!.uid,
        displayName: cred.user!.displayName ?? 'Traveler',
        email: cred.user!.email ?? '',
        avatarUrl: cred.user!.photoURL,
        createdAt: DateTime.now(),
      );
      await _db
          .collection('users')
          .doc(cred.user!.uid)
          .set(userModel.toMap());
    }

    return cred;
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Password reset
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum UserRole { worker, client }

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ─── Stream ──────────────────────────────────────────────────────────────
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static User? get currentUser => _auth.currentUser;

  // ─── Sign Up with Email & Password ───────────────────────────────────────
  static Future<UserCredential> signUpWithEmail({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    await credential.user?.updateDisplayName(fullName.trim());

    // Create Firestore profile document
    await _createUserProfile(
      uid: credential.user!.uid,
      fullName: fullName.trim(),
      email: email.trim(),
      role: role,
      photoUrl: credential.user?.photoURL,
    );

    return credential;
  }

  // ─── Sign In with Email & Password ───────────────────────────────────────
  static Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // ─── Google Sign-In ───────────────────────────────────────────────────────
  static Future<UserCredential?> signInWithGoogle({
    required UserRole role,
  }) async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // User cancelled

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);

    // Create profile only if new user
    if (userCredential.additionalUserInfo?.isNewUser == true) {
      await _createUserProfile(
        uid: userCredential.user!.uid,
        fullName: userCredential.user?.displayName ?? 'User',
        email: userCredential.user?.email ?? '',
        role: role,
        photoUrl: userCredential.user?.photoURL,
      );
    }

    return userCredential;
  }

  // ─── Forgot Password ─────────────────────────────────────────────────────
  static Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ─── Sign Out ─────────────────────────────────────────────────────────────
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ─── Firestore Helpers ────────────────────────────────────────────────────
  static Future<void> _createUserProfile({
    required String uid,
    required String fullName,
    required String email,
    required UserRole role,
    String? photoUrl,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'role': role.name, // 'worker' or 'client'
      'photoUrl': photoUrl ?? '',
      'phoneNumber': '',
      'bio': '',
      'skills': [],
      'resumeUrl': '',
      'rating': 0.0,
      'reviewCount': 0,
      'verified': false,
      'profileComplete': false,
      'isProfileComplete': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  // ─── Error Messages ───────────────────────────────────────────────────────
  static String getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'invalid-credential':
        return 'Invalid email or password. Please try again.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}

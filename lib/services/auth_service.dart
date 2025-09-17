import 'package:firebase_auth/firebase_auth.dart';
// import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Google Sign-In temporarily disabled due to API compatibility issues
  // final GoogleSignIn? _googleSignIn = kIsWeb ? null : GoogleSignIn(
  //   scopes: ['email', 'profile'],
  // );

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      // Handle both FirebaseAuthException and web-specific exceptions
      if (e is FirebaseAuthException) {
        throw _handleAuthException(e);
      } else {
        // Handle web-specific errors
        throw 'Authentication failed: ${e.toString()}';
      }
    }
  }

  // Register with email and password
  Future<User?> registerWithEmailPassword(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      // Handle both FirebaseAuthException and web-specific exceptions
      if (e is FirebaseAuthException) {
        throw _handleAuthException(e);
      } else {
        // Handle web-specific errors
        throw 'Registration failed: ${e.toString()}';
      }
    }
  }


  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web implementation
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        final UserCredential credential = await _auth.signInWithPopup(googleProvider);
        return credential.user;
      } else {
        // Mobile Google Sign-In implementation temporarily disabled
        throw UnimplementedError('Google Sign-In is temporarily disabled.');
      }
    } catch (e) {
      // Handle both FirebaseAuthException and web-specific exceptions
      if (e is FirebaseAuthException) {
        throw _handleAuthException(e);
      } else {
        throw 'Google Sign-In failed: ${e.toString()}';
      }
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      // Handle both FirebaseAuthException and web-specific exceptions
      if (e is FirebaseAuthException) {
        throw _handleAuthException(e);
      } else {
        throw 'Password reset failed: ${e.toString()}';
      }
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
      // Continue with sign out even if there's an error
      await _auth.signOut();
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'Email is already registered.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'An error occurred: ${e.message}';
    }
  }
}
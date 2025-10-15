import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _auth = FirebaseAuth.instance;

  Stream<User?> get onAuthStateChanged => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInAnonymously() async {
    try {
      return await _auth.signInAnonymously();
    } catch (e) {
      throw Exception('Anonymous sign-in failed: $e');
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // Request openid/email/profile and provide the server client id so
        // Android returns an idToken usable by Firebase.
        final googleSignIn = GoogleSignIn(
          scopes: <String>['email', 'profile', 'openid'],
          serverClientId:
              '99046813039-8q2tkobklp0qpik97hj0lj479sghln4c.apps.googleusercontent.com',
        );

        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          throw Exception('Google sign-in aborted by user.');
        }

        final googleAuth = await googleUser.authentication;

        // Debug output: print tokens so you can verify what's returned.
        // Remove or guard these prints in production.
        // ignore: avoid_print
        print('Google accessToken: ${googleAuth.accessToken}');
        // ignore: avoid_print
        print('Google idToken: ${googleAuth.idToken}');

        if (googleAuth.accessToken == null || googleAuth.idToken == null) {
          throw Exception('Missing Google authentication tokens.');
        }

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        return await _auth.signInWithCredential(credential);
      } else {
        final provider = GoogleAuthProvider();
        return await _auth.signInWithProvider(provider);
      }
    } catch (e) {
      throw Exception('Google sign-in failed: $e');
    }
  }

  Future<void> reauthenticateWithGoogle() async {
    final googleSignIn = GoogleSignIn(
      scopes: <String>['email', 'profile', 'openid'],
      serverClientId:
          '99046813039-8q2tkobklp0qpik97hj0lj479sghln4c.apps.googleusercontent.com',
    );
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) throw Exception('Reauth aborted');

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    await _auth.currentUser?.reauthenticateWithCredential(credential);
  }

  Future<void> linkWithGoogle() async {
    final googleSignIn = GoogleSignIn(
      scopes: <String>['email', 'profile', 'openid'],
      serverClientId:
          '99046813039-8q2tkobklp0qpik97hj0lj479sghln4c.apps.googleusercontent.com',
    );
    final googleUser = await googleSignIn.signIn();
    final googleAuth = await googleUser?.authentication;
    
    if (googleAuth == null) throw Exception("Google auth failed");

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    await _auth.currentUser?.linkWithCredential(credential);
  }

  Future<void> signOut() async {
    try {
      final user = _auth.currentUser;
      final isGoogleSignIn = user?.providerData.any((info) => info.providerId == 'google.com') ?? false;

      if (isGoogleSignIn) {
        try {
          final googleSignIn = GoogleSignIn(
            scopes: <String>['email', 'profile', 'openid'],
            serverClientId:
                '99046813039-8q2tkobklp0qpik97hj0lj479sghln4c.apps.googleusercontent.com',
          );
          await googleSignIn.signOut();
        } catch (_) {
          // Ignore Google sign-out error
        }
      }

      await _auth.signOut();
    } catch (e) {
      throw Exception('Sign-out failed: $e');
    }
  }

  Future<void> deleteAccount() async {
    await _auth.currentUser?.delete();
  }

  // Email/Password Authentication
  Future<UserCredential> signInWithEmailPassword(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No account found with this email.');
        case 'wrong-password':
          throw Exception('Incorrect password.');
        case 'invalid-email':
          throw Exception('Invalid email address.');
        case 'user-disabled':
          throw Exception('This account has been disabled.');
        default:
          throw Exception('Sign-in failed: ${e.message}');
      }
    } catch (e) {
      throw Exception('Sign-in failed: $e');
    }
  }

  Future<UserCredential> registerWithEmailPassword(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception('An account already exists with this email.');
        case 'invalid-email':
          throw Exception('Invalid email address.');
        case 'weak-password':
          throw Exception('Password is too weak. Use at least 6 characters.');
        default:
          throw Exception('Registration failed: ${e.message}');
      }
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No account found with this email.');
        case 'invalid-email':
          throw Exception('Invalid email address.');
        default:
          throw Exception('Failed to send reset email: ${e.message}');
      }
    } catch (e) {
      throw Exception('Failed to send reset email: $e');
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await _auth.currentUser?.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception('Please sign in again to change your password.');
      }
      throw Exception('Failed to update password: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update password: $e');
    }
  }
}
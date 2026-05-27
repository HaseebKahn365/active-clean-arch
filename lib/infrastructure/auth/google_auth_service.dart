import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class GoogleAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _initialized = false;

  Future<User?> signInWithGoogle() async {
    try {
      if (!_initialized) {
        await _googleSignIn.initialize();
        _initialized = true;
      }

      // 1. Trigger the Google Authentication flow
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate(
        scopeHint: const ['email', 'profile', 'openid'],
      );

      // 2. Obtain the auth details from the request
      final googleAuth = googleUser.authentication;
      final authz = await googleUser.authorizationClient.authorizeScopes(const ['email', 'profile', 'openid']);

      // 3. Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: authz.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Once signed in, return the UserCredential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      debugPrint('Google Sign-In Successful: ${userCredential.user?.uid}');
      return userCredential.user;
    } catch (e) {
      debugPrint('Error during Google Sign-In: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}

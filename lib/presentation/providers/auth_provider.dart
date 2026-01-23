import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../infrastructure/auth/google_auth_service.dart';

class AppAuthProvider extends ChangeNotifier {
  final GoogleAuthService _googleAuthService;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;

  User? get user => _user;
  String? get userId => _user?.uid;
  bool get isAuthenticated => _user != null;

  AppAuthProvider(this._googleAuthService) {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<void> signInWithGoogle() async {
    await _googleAuthService.signInWithGoogle();
  }

  Future<void> signOut() async {
    await _googleAuthService.signOut();
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AppAuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;

  User? get user => _user;
  String? get userId => _user?.uid;
  bool get isAuthenticated => _user != null;

  AppAuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  // Simplified for Phase 7 demonstration
  Future<void> signInAnonymously() async {
    await _auth.signInAnonymously();
  }
}

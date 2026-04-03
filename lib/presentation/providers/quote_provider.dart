import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuoteProvider with ChangeNotifier {
  static const String _kQuoteKey = 'project_quote';
  static const String _kDefaultQuote = 'PROJECT STEEP: LOOK AND GO UP';

  String _quote = _kDefaultQuote;
  final SharedPreferences _prefs;

  QuoteProvider(this._prefs) {
    _quote = _prefs.getString(_kQuoteKey) ?? _kDefaultQuote;
  }

  String get quote => _quote;

  Future<void> updateQuote(String newQuote) async {
    _quote = newQuote;
    await _prefs.setString(_kQuoteKey, newQuote);
    notifyListeners();
  }
}

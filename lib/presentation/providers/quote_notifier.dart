import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/di/injection_container.dart';

class QuoteNotifier extends Notifier<String> {
  static const String _kQuoteKey = 'project_quote';
  static const String _kDefaultQuote = 'PROJECT STEEP: LOOK AND GO UP';

  late SharedPreferences _prefs;

  @override
  String build() {
    _prefs = sl<SharedPreferences>();
    return _prefs.getString(_kQuoteKey) ?? _kDefaultQuote;
  }

  Future<void> updateQuote(String newQuote) async {
    state = newQuote;
    await _prefs.setString(_kQuoteKey, newQuote);
  }
}

final quoteNotifierProvider = NotifierProvider<QuoteNotifier, String>(QuoteNotifier.new);

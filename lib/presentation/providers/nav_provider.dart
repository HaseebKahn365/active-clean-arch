import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppTab { home, stats, agent }

final currentTabProvider = StateProvider<AppTab>((ref) => AppTab.home);

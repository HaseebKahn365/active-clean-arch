import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:active/main.dart';

void main() {
  testWidgets('shows home tab by default and navigates via bottom nav', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    expect(find.text('Home'), findsWidgets);

    await tester.tap(find.text('Stats').last);
    await tester.pumpAndSettle();
    expect(find.text('Stats'), findsWidgets);

    await tester.tap(find.text('Agent').last);
    await tester.pumpAndSettle();
    expect(find.text('Agent'), findsWidgets);
  });
}

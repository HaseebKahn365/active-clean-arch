import 'package:flutter_test/flutter_test.dart';

import 'package:active/main.dart';

void main() {
  testWidgets('shows hello text', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('hello'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AtlasApp());
    expect(find.text('ATLAS AI'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();
  });
}

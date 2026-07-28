import 'package:flutter_test/flutter_test.dart';
import 'package:aizawl_gym/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AizawlGymApp());
    expect(find.text('Aizawl Gym'), findsOneWidget);
  });
}

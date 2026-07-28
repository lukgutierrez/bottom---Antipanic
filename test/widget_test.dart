import 'package:flutter_test/flutter_test.dart';
import 'package:app_tes/app.dart';

void main() {
  testWidgets('App renders panic home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('BOTÓN ANTIPÁNICO'), findsOneWidget);
  });
}
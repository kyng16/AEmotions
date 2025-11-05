import 'package:flutter_test/flutter_test.dart';
import 'package:app_emotions/main.dart';

void main() {
  testWidgets('App renders without errors', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    // Expect the MaterialApp root to be present and the app title text on the AppBar.
    expect(find.byType(MyApp), findsOneWidget);
    expect(find.text('AppEmotions'), findsOneWidget);
  });
}

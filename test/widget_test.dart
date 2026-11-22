import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:offline_ai/main.dart';

void main() {
  testWidgets('shows offline welcome and model setup', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const HyperAIApp());
    await tester.pumpAndSettle();
    expect(find.textContaining('offline'), findsWidgets);
    expect(find.textContaining('Load your local model'), findsOneWidget);
  });
}

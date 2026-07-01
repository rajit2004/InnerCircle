import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows login screen when no session is saved', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const InnerCircleApp());
    await tester.pump();

    expect(find.text('InnerCircle Login'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}

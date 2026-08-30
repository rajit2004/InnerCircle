import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows onboarding screen when no session is saved', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const InnerCircleApp());
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('Someone who\nunderstands'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('shows login screen after onboarding is seen', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarding_seen': true});

    await tester.pumpWidget(const InnerCircleApp());
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });
}

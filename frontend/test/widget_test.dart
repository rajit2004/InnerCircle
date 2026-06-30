import 'package:frontend/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Counter test', (WidgetTester tester) async {
    await tester.pumpWidget(const InnerCircleApp());
    // ... your test logic
  });
}
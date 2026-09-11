import 'package:flutter_test/flutter_test.dart';

import 'package:ai_football_predictions/main.dart';

void main() {
  testWidgets('App loads and shows home screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AIScorecastApp());

    // Verify that the title is there.
    expect(find.text('AI Scorecast'), findsOneWidget);
  });
}

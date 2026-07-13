import 'package:flutter_test/flutter_test.dart';
import 'package:style_tone_ai/main.dart';

void main() {
  testWidgets('renders fallback when no cameras', (tester) async {
    cameras = [];
    await tester.pumpWidget(const MyApp(seenOnboarding: true));
    expect(find.text('No cameras available on this device.'), findsOneWidget);
  });
}

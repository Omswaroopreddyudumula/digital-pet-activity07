import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

// Change `digital_pet` to the `name:` in your pubspec.yaml if different.
import 'package:digital_pet/main.dart';

void main() {
  testWidgets('Feed updates meters and timers are cleaned up on dispose',
      (tester) async {
    await tester.pumpWidget(const DigitalPetApp());

    expect(find.text("Hi, I'm Pip!"), findsOneWidget);
    expect(find.text('50 / 100'), findsNWidgets(2));
    await tester.ensureVisible(find.text("Feed"));
    await tester.pump();

    await tester.tap(find.text('Feed'));
    await tester.pump(const Duration(milliseconds: 500));

    // Hunger 50 -> 40, happiness 50 -> 60.
    expect(find.text('40 / 100'), findsOneWidget);
    expect(find.text('60 / 100'), findsOneWidget);

    // Removing the screen must cancel every timer (no pending-timer error).
    await tester.pumpWidget(const SizedBox());
  });
}

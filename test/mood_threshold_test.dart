import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:digital_pet/main.dart';

// Mood boundaries required by the rubric: 29 / 30 / 70 / 71.
// Buttons move happiness in steps of 10, so 29 and 71 are set directly
// through the widget's immutable starting configuration.
void main() {
  final cases = [
    (29, 'Unhappy', Colors.red, 0.94),
    (30, 'Neutral', Colors.yellow, 1.0),
    (70, 'Neutral', Colors.yellow, 1.0),
    (71, 'Happy', Colors.green, 1.06),
  ];

  for (final (happiness, label, color, scale) in cases) {
    testWidgets('happiness $happiness -> $label, tint and scale match',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: DigitalPetScreen(initialHappiness: happiness)),
      );

      // Text label (mood is never signalled by color alone).
      expect(find.text('Mood: $label'), findsOneWidget);

      // ColorFiltered tint uses the same thresholds.
      final filtered = tester.widget<ColorFiltered>(find.byType(ColorFiltered));
      expect(filtered.colorFilter, ColorFilter.mode(color, BlendMode.modulate));

      // Size uses the same thresholds.
      final scaled = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scaled.scale, closeTo(scale, 0.0001));

      // Dispose the screen so its timers are cancelled.
      await tester.pumpWidget(const SizedBox());
    });
  }
}

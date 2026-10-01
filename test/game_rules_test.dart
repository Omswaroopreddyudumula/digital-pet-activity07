import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:digital_pet/main.dart';

// Covers the remaining rows of the Activity 07 test matrix using Flutter's
// fake clock, so 30-second ticks and the 3-minute win run instantly.

Future<void> pumpPet(
  WidgetTester tester, {
  int happiness = 50,
  int hunger = 50,
  bool reduceMotion = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      builder: reduceMotion
          ? (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              )
          : null,
      home: DigitalPetScreen(
        initialHappiness: happiness,
        initialHunger: hunger,
      ),
    ),
  );
}

Future<void> tapButton(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Finder meter(String name, int value) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == '$name $value out of 100',
    );

void expectMeters(int happiness, int hunger) {
  expect(meter('Happiness', happiness), findsOneWidget,
      reason: 'happiness should be $happiness');
  expect(meter('Hunger', hunger), findsOneWidget,
      reason: 'hunger should be $hunger');
}

bool isEnabled(WidgetTester tester, String label) => tester
    .widget<ButtonStyleButton>(find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    ))
    .enabled;

Future<void> disposePet(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox());

void main() {
  testWidgets('Feed at hunger 5 clamps to 0 and applies overfeed penalty',
      (tester) async {
    await pumpPet(tester, happiness: 50, hunger: 5);
    await tapButton(tester, 'Feed');
    expectMeters(30, 0);
    await disposePet(tester);
  });

  testWidgets('Feed at hunger 95 lowers hunger and raises happiness',
      (tester) async {
    await pumpPet(tester, happiness: 50, hunger: 95);
    await tapButton(tester, 'Feed');
    expectMeters(60, 85);
    await disposePet(tester);
  });

  testWidgets('Play at happiness 95 clamps happiness to 100', (tester) async {
    await pumpPet(tester, happiness: 95, hunger: 50);
    await tapButton(tester, 'Play');
    expectMeters(100, 55);
    await disposePet(tester);
  });

  testWidgets(
      'Above 80 for 2:59 then drop to 80 cancels the win; '
      'a fresh 3:00 streak wins', (tester) async {
    await pumpPet(tester, happiness: 90, hunger: 0);
    await tapButton(tester, 'Play'); // 100 / 5, streak starts
    expectMeters(100, 5);

    await tester.pump(const Duration(minutes: 2, seconds: 59));
    expectMeters(100, 30); // five hunger ticks
    await tapButton(tester, 'Feed'); // hunger 20 < 30 -> happiness 80
    expectMeters(80, 20);

    // Past the old 3:00 deadline: no win, streak cleared.
    await tester.pump(const Duration(seconds: 61));
    expect(find.text('You win!'), findsNothing);
    expect(find.text('Keep happiness above 80 for 3 minutes to win.'),
        findsOneWidget);

    // Next crossing above 80 starts a fresh timer.
    await tapButton(tester, 'Play'); // happiness 90
    await tester.pump(const Duration(minutes: 2, seconds: 59));
    expect(find.text('You win!'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('You win!'), findsOneWidget);
    await disposePet(tester);
  });

  testWidgets('Win at 3:00 stops the hunger timer and disables actions',
      (tester) async {
    await pumpPet(tester, happiness: 90, hunger: 0);
    await tapButton(tester, 'Play');
    await tester.pump(const Duration(minutes: 3));
    await tester.pump();
    expect(find.text('You win!'), findsOneWidget);

    final before = tester
        .widgetList<Text>(find.textContaining('/ 100'))
        .map((t) => t.data)
        .toList();
    await tester.pump(const Duration(seconds: 90));
    final after = tester
        .widgetList<Text>(find.textContaining('/ 100'))
        .map((t) => t.data)
        .toList();
    expect(after, before, reason: 'hunger must not tick after a win');

    expect(isEnabled(tester, 'Feed'), isFalse);
    expect(isEnabled(tester, 'Play'), isFalse);
    await disposePet(tester);
  });

  testWidgets('Hunger 95 -> 100 has no penalty; next tick costs 20 happiness',
      (tester) async {
    await pumpPet(tester, happiness: 50, hunger: 95);
    await tester.pump(const Duration(seconds: 30));
    expectMeters(50, 100);
    await tester.pump(const Duration(seconds: 30));
    expectMeters(30, 100);
    await disposePet(tester);
  });

  testWidgets('Hunger 100 and happiness 10 is game over; state is frozen',
      (tester) async {
    await pumpPet(tester, happiness: 30, hunger: 100);
    await tester.pump(const Duration(seconds: 30)); // overflow: happiness 10
    expectMeters(10, 100);
    expect(find.text('Game over'), findsOneWidget);
    expect(find.text('I need a rest.'), findsOneWidget);
    expect(isEnabled(tester, 'Feed'), isFalse);
    expect(isEnabled(tester, 'Play'), isFalse);

    await tester.pump(const Duration(minutes: 2));
    expectMeters(10, 100);
    await disposePet(tester);
  });

  testWidgets('Motion on: action bounce plays', (tester) async {
    await pumpPet(tester);
    await tapButton(tester, 'Feed');
    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, closeTo(1.12, 0.0001));
    expect(scale.duration, isNot(Duration.zero));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        closeTo(1.0, 0.0001));
    await disposePet(tester);
  });

  testWidgets('Reduced motion: no bounce, zero-duration animations',
      (tester) async {
    await pumpPet(tester, reduceMotion: true);
    await tapButton(tester, 'Feed');
    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, closeTo(1.0, 0.0001));
    expect(scale.duration, Duration.zero);
    for (final meterAnim in tester.widgetList<TweenAnimationBuilder<double>>(
        find.byType(TweenAnimationBuilder<double>))) {
      expect(meterAnim.duration, Duration.zero);
    }
    // Values and labels are still shown.
    expectMeters(60, 40);
    expect(find.text('Mood: Neutral'), findsOneWidget);
    await disposePet(tester);
  });
}

import 'dart:async';

import 'package:flutter/material.dart';

void main() => runApp(const DigitalPetApp());

class DigitalPetApp extends StatelessWidget {
  const DigitalPetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital Pet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const DigitalPetScreen(),
    );
  }
}

/// Immutable configuration: these starting values never change after the
/// widget is created. Everything that changes lives in the State object.
class DigitalPetScreen extends StatefulWidget {
  const DigitalPetScreen({
    super.key,
    this.initialName = 'Pip',
    this.initialHappiness = 50,
    this.initialHunger = 50,
  });

  final String initialName;
  final int initialHappiness;
  final int initialHunger;

  @override
  State<DigitalPetScreen> createState() => _DigitalPetScreenState();
}

class _DigitalPetScreenState extends State<DigitalPetScreen> {
  // PRODUCTION timings. Shorten only while testing (e.g. seconds: 5),
  // then restore these exact values before `flutter build apk --release`.
  static const Duration hungerInterval = Duration(seconds: 30);
  static const Duration winDuration = Duration(minutes: 3);
  static const Duration bounceDuration = Duration(milliseconds: 180);

  // ---- Mutable state (single source of truth) ----
  late String _petName;
  late int _happiness;
  late int _hunger;
  bool _gameOver = false;
  bool _hasWon = false;
  bool _isPaused = false;

  // Short-lived animation state only.
  double _bounce = 1.0;

  // ---- Owned resources (released in dispose) ----
  Timer? _hungerTimer;
  Timer? _highMoodTimer;
  Timer? _bounceTimer;
  final TextEditingController _nameController = TextEditingController();

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _petName = widget.initialName;
    _happiness = _clampMeter(widget.initialHappiness);
    _hunger = _clampMeter(widget.initialHunger);
    _nameController.text = _petName;
    _startHungerTimer();
  }

  @override
  void dispose() {
    _hungerTimer?.cancel();
    _highMoodTimer?.cancel();
    _bounceTimer?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Rules
  // ---------------------------------------------------------------------------
  int _clampMeter(int value) => value.clamp(0, 100).toInt();

  bool get _actionsEnabled => !_gameOver && !_hasWon && !_isPaused;

  // ---------------------------------------------------------------------------
  // Derived presentation: all computed from the same state, never stored.
  // Thresholds: >70 happy/green, 30–70 neutral/yellow, <30 unhappy/red.
  // ---------------------------------------------------------------------------
  String get _moodLabel {
    if (_happiness > 70) return 'Happy';
    if (_happiness >= 30) return 'Neutral';
    return 'Unhappy';
  }

  IconData get _moodIcon {
    if (_happiness > 70) return Icons.sentiment_very_satisfied;
    if (_happiness >= 30) return Icons.sentiment_neutral;
    return Icons.sentiment_very_dissatisfied;
  }

  Color get _moodColor {
    if (_happiness > 70) return Colors.green;
    if (_happiness >= 30) return Colors.yellow;
    return Colors.red;
  }

  double get _petScale {
    if (_happiness > 70) return 1.06;
    if (_happiness < 30) return 0.94;
    return 1.0;
  }

  String get _petMessage {
    if (_gameOver) return 'I need a rest.';
    if (_hasWon) return 'Best day ever!';
    if (_isPaused) return 'Taking a little break...';
    if (_hunger > 80) return "I'm starving!";
    if (_happiness <= 30) return 'Play with me?';
    return "Hi, I'm $_petName!";
  }

  String get _statusText {
    if (_gameOver) {
      return 'Game over: hunger hit 100 and happiness fell to 10 or below.';
    }
    if (_hasWon) return 'You won! Happiness stayed above 80 for 3 minutes.';
    if (_isPaused) return 'Paused: timers are stopped. Resume to continue.';
    if (_highMoodTimer != null) {
      return 'Happy streak running: keep happiness above 80!';
    }
    return 'Keep happiness above 80 for 3 minutes to win.';
  }

  // ---------------------------------------------------------------------------
  // Timers
  // ---------------------------------------------------------------------------

  /// Always cancels the previous timer first, so exactly one is ever active.
  void _startHungerTimer() {
    _hungerTimer?.cancel();
    _hungerTimer = Timer.periodic(hungerInterval, (timer) {
      if (!mounted || _gameOver || _hasWon || _isPaused) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_hunger + 5 > 100) {
          // Overflow tick: clamp hunger and penalize happiness.
          _hunger = 100;
          _happiness = _clampMeter(_happiness - 20);
        } else {
          // Includes 95 -> 100 with no penalty.
          _hunger += 5;
        }
      });
      _updateOutcome();
    });
  }

  void _cancelWinTimer() {
    _highMoodTimer?.cancel();
    _highMoodTimer = null;
  }

  /// Called after EVERY state transition (actions, ticks, reset, resume).
  void _updateOutcome() {
    if (_gameOver || _hasWon) return;

    if (_hunger == 100 && _happiness <= 10) {
      _cancelWinTimer();
      _hungerTimer?.cancel();
      _hungerTimer = null;
      setState(() => _gameOver = true);
      return;
    }

    // "Above 80" is strictly > 80. At 80 or below, clear the streak.
    if (_happiness <= 80 || _isPaused) {
      _cancelWinTimer();
      return;
    }

    // First crossing above 80 starts a fresh 3-minute one-shot timer.
    _highMoodTimer ??= Timer(winDuration, () {
      _highMoodTimer = null;
      if (!mounted || _gameOver || _isPaused || _happiness <= 80) return;
      _hungerTimer?.cancel();
      _hungerTimer = null;
      setState(() => _hasWon = true);
    });
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  void _feedPet() {
    if (!_actionsEnabled) return;
    final nextHunger = _clampMeter(_hunger - 10);
    // Overfeeding (resulting hunger < 30) makes the pet unhappy.
    final happinessChange = nextHunger < 30 ? -20 : 10;
    final nextHappiness = _clampMeter(_happiness + happinessChange);
    setState(() {
      _hunger = nextHunger;
      _happiness = nextHappiness;
    });
    _triggerBounce();
    _updateOutcome();
  }

  void _playWithPet() {
    if (!_actionsEnabled) return;
    final nextHappiness = _clampMeter(_happiness + 10);
    final nextHunger = _clampMeter(_hunger + 5);
    setState(() {
      _happiness = nextHappiness;
      _hunger = nextHunger;
    });
    _triggerBounce();
    _updateOutcome();
  }

  void _resetGame() {
    _cancelWinTimer();
    _bounceTimer?.cancel();
    setState(() {
      _happiness = _clampMeter(widget.initialHappiness);
      _hunger = _clampMeter(widget.initialHunger);
      _gameOver = false;
      _hasWon = false;
      _isPaused = false;
      _bounce = 1.0;
    });
    _startHungerTimer(); // cancels any old timer before starting one
    _updateOutcome();
  }

  /// Session controls (advanced feature): pause stops both timers;
  /// resume starts one fresh hunger timer and a fresh win streak.
  void _togglePause() {
    if (_gameOver || _hasWon) return;
    if (_isPaused) {
      setState(() => _isPaused = false);
      _startHungerTimer();
      _updateOutcome();
    } else {
      _hungerTimer?.cancel();
      _hungerTimer = null;
      _cancelWinTimer();
      setState(() => _isPaused = true);
    }
  }

  void _confirmName() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _petName = name);
    FocusScope.of(context).unfocus();
  }

  /// Visual polish: action bounce. Cancelling the previous timer means an
  /// old callback can never end a newer bounce.
  void _triggerBounce() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) return;
    _bounceTimer?.cancel();
    setState(() => _bounce = 1.12);
    _bounceTimer = Timer(bounceDuration, () {
      if (!mounted) return;
      setState(() => _bounce = 1.0);
    });
  }

  // ---------------------------------------------------------------------------
  // UI (reads state only; no side effects, no timers created here)
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    Duration motion(Duration d) => reduceMotion ? Duration.zero : d;

    return Scaffold(
      appBar: AppBar(title: const Text('Digital Pet')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  // ---- Name ----
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _confirmName(),
                          decoration: const InputDecoration(
                            labelText: 'Pet name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _confirmName,
                        child: const Text('Confirm'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(_petName, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),

                  // ---- Pet (mood tint + size + bounce) ----
                  Semantics(
                    image: true,
                    label: '$_petName looks $_moodLabel',
                    child: GestureDetector(
                      onTap: _actionsEnabled ? _triggerBounce : null,
                      child: AnimatedScale(
                        scale: _petScale * _bounce,
                        duration: motion(bounceDuration),
                        curve: Curves.easeOutBack,
                        child: SizedBox(
                          width: 200,
                          height: 200,
                          child: ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              _moodColor,
                              BlendMode.modulate,
                            ),
                            child: Image.asset(
                              'assets/pet.png',
                              fit: BoxFit.contain,
                              // Fallback keeps the app usable if the asset
                              // path is wrong; white is tinted by modulate.
                              errorBuilder: (context, error, stack) =>
                                  const Icon(Icons.pets,
                                      size: 160, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ---- Mood label + icon (never color alone) ----
                  AnimatedSwitcher(
                    duration: motion(const Duration(milliseconds: 300)),
                    child: Row(
                      key: ValueKey(_moodLabel),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_moodIcon),
                        const SizedBox(width: 6),
                        Text('Mood: $_moodLabel',
                            style: theme.textTheme.titleMedium),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ---- Speech bubble (derived, not stored) ----
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AnimatedSwitcher(
                      duration: motion(const Duration(milliseconds: 300)),
                      child: Text(
                        _petMessage,
                        key: ValueKey(_petMessage),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ---- Living meters ----
                  _MeterRow(
                    label: 'Happiness',
                    value: _happiness,
                    color: _moodColor,
                    duration: motion(const Duration(milliseconds: 400)),
                  ),
                  _MeterRow(
                    label: 'Hunger',
                    value: _hunger,
                    color: _hunger > 80 ? Colors.red : theme.colorScheme.primary,
                    duration: motion(const Duration(milliseconds: 400)),
                  ),
                  const SizedBox(height: 8),
                  Text(_statusText,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 16),

                  // ---- Controls ----
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: _actionsEnabled ? _feedPet : null,
                        icon: const Icon(Icons.restaurant),
                        label: const Text('Feed'),
                      ),
                      FilledButton.icon(
                        onPressed: _actionsEnabled ? _playWithPet : null,
                        icon: const Icon(Icons.sports_esports),
                        label: const Text('Play'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            (_gameOver || _hasWon) ? null : _togglePause,
                        icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                        label: Text(_isPaused ? 'Resume' : 'Pause'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _resetGame,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset'),
                      ),
                    ],
                  ),

                  // ---- Outcome ----
                  if (_gameOver || _hasWon) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: _hasWon
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              _hasWon ? 'You win!' : 'Game over',
                              style: theme.textTheme.headlineSmall
                                  ?.copyWith(color: Colors.black87),
                            ),
                            const SizedBox(height: 8),
                            FilledButton(
                              onPressed: _resetGame,
                              child: const Text('Restart'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Living meter: glides to the current value; the value itself always
/// comes from state passed in by the owner.
class _MeterRow extends StatelessWidget {
  const _MeterRow({
    required this.label,
    required this.value,
    required this.color,
    required this.duration,
  });

  final String label;
  final int value;
  final Color color;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $value out of 100',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text(label), Text('$value / 100')],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: value / 100),
                duration: duration,
                curve: Curves.easeOut,
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 10,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

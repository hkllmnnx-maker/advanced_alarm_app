import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models/dismiss_method.dart';
import 'ringing_controller.dart';
import 'ringing_payload.dart';
import 'services/math_puzzle.dart';
import 'widgets/big_action_button.dart';
import 'widgets/math_puzzle_dialog.dart';
import 'widgets/shake_to_dismiss_sheet.dart';

/// Full-screen "the alarm is ringing right now" experience.
///
/// Designed to:
///  * Be the entry point of a full-screen intent on Android (i.e. it
///    can appear over the lock screen).
///  * Show the current time (auto-updating every second) and the
///    alarm's label prominently.
///  * Render two large action buttons (Snooze / Dismiss).
///  * Delegate the *enforcement* of the dismiss method (math / shake)
///    to the [RingingController], so the screen itself stays simple
///    and stateless except for the bare minimum (current time tick).
///
/// Usage:
/// ```dart
/// final RingingResult result = await Navigator.of(context).push(
///   RingingScreen.route(RingingPayload(alarm: alarm)),
/// );
/// ```
class RingingScreen extends StatefulWidget {
  const RingingScreen({
    super.key,
    required this.payload,
    this.controllerFactory,
  });

  final RingingPayload payload;

  /// Optional factory for tests / DI. Defaults to a fresh
  /// [RingingController] built around the payload.
  final RingingController Function(RingingPayload payload)? controllerFactory;

  /// Builds a [MaterialPageRoute] that returns the [RingingResult]
  /// when the screen pops. Convenient for the alarm engine to await
  /// the user decision before snoozing / clearing the active fire.
  static Route<RingingResult> route(
    RingingPayload payload, {
    RingingController Function(RingingPayload payload)? controllerFactory,
  }) {
    return MaterialPageRoute<RingingResult>(
      fullscreenDialog: true,
      settings: RouteSettings(name: 'ringing/${payload.alarm.id}'),
      builder: (BuildContext context) => RingingScreen(
        payload: payload,
        controllerFactory: controllerFactory,
      ),
    );
  }

  @override
  State<RingingScreen> createState() => _RingingScreenState();
}

class _RingingScreenState extends State<RingingScreen>
    with TickerProviderStateMixin {
  late final RingingController _controller;
  late final AnimationController _pulse;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  bool _shakeSheetVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = (widget.controllerFactory ?? _defaultController)(widget.payload);
    _controller.addListener(_onControllerChanged);

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Immersive sticky so the system bars don't distract — but we
    // restore them in dispose() so the rest of the app isn't affected.
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );

    // Start the engine after the first frame so the screen is already
    // visible by the time audio kicks in (better UX, and gives the
    // wakelock a microsecond to take effect).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _controller.start();
      _controller.done.then(_onSessionDone);
    });

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  RingingController _defaultController(RingingPayload payload) {
    return RingingController(payload: payload);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pulse.dispose();
    _controller.removeListener(_onControllerChanged);
    // Disposing the controller also stops audio/vibration/wakelock,
    // guaranteeing no resource leaks regardless of how this screen
    // exits (back button, system kill, programmatic pop).
    _controller.dispose();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final RingingChallenge challenge = _controller.activeChallenge;

    if (challenge == RingingChallenge.mathPuzzle) {
      _showMathPuzzle();
    } else if (challenge == RingingChallenge.shake && !_shakeSheetVisible) {
      _showShakeSheet();
    }

    setState(() {});
  }

  Future<void> _onSessionDone(RingingResult result) async {
    if (!mounted) return;
    // Dismiss any open challenge UI before popping the screen so we
    // don't leave a stray dialog/sheet behind.
    if (Navigator.of(context).canPop()) {
      // We use rootNavigator: false so we only pop modals registered
      // on the current navigator (the math dialog / shake sheet).
      while (ModalRoute.of(context)?.isCurrent == false &&
          Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
    if (!mounted) return;
    Navigator.of(context).maybePop(result);
  }

  Future<void> _showMathPuzzle() async {
    // Loop: each "Submit" inside the dialog handles the wrong-answer
    // case itself, so the dialog only pops with `true` on success or
    // `false` on bail-out.
    final bool solved = await MathPuzzleDialog.show(
      context,
      difficulty: MathPuzzleDifficulty.medium,
    );
    if (!mounted) return;
    if (solved) {
      await _controller.submitMathAnswer(correct: true);
    } else {
      await _controller.cancelChallenge();
    }
  }

  Future<void> _showShakeSheet() async {
    _shakeSheetVisible = true;
    await ShakeToDismissSheet.show(
      context,
      builder: (BuildContext ctx) {
        // Rebuild on every controller tick so the progress bar updates
        // live without the sheet having to subscribe itself.
        return AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext _, Widget? __) {
            return ShakeToDismissSheet(
              shakeProgress: _controller.shakeProgress,
              shakesRequired: _controller.shakesRequired,
              onCancel: () {
                Navigator.of(ctx).pop();
              },
            );
          },
        );
      },
    );
    _shakeSheetVisible = false;
    if (!mounted) return;
    // If the user closed the sheet without finishing the shakes, fall
    // back to "still ringing" so they can try again or snooze.
    if (_controller.activeChallenge == RingingChallenge.shake &&
        _controller.phase != RingingPhase.finished) {
      await _controller.cancelChallenge();
    }
  }

  String _formatTime(DateTime t) {
    final String hh = t.hour.toString().padLeft(2, '0');
    final String mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _formatDate(DateTime t) {
    const List<String> weekdays = <String>[
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[t.weekday - 1]}, ${t.day} ${months[t.month - 1]}';
  }

  String _dismissHint(DismissMethod method) {
    switch (method) {
      case DismissMethod.tap:
        return 'Tap Dismiss to stop the alarm';
      case DismissMethod.mathPuzzle:
        return 'Solve a quick math puzzle to dismiss';
      case DismissMethod.shake:
        return 'Shake the phone vigorously to dismiss';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String label = widget.payload.alarm.label.isNotEmpty
        ? widget.payload.alarm.label
        : 'Alarm';

    return PopScope(
      // Disable back-button dismissal: the user must use the explicit
      // Snooze / Dismiss buttons so we can enforce the dismiss method.
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _AnimatedBackground(animation: _pulse),
            SafeArea(
              minimum: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: LayoutBuilder(
                builder: (BuildContext ctx, BoxConstraints constraints) {
                  // On very short viewports (small phones in landscape,
                  // tablet split-screen, widget tests …) the natural
                  // size of the column exceeds the available height.
                  // We fall back to a scrollable layout so nothing
                  // overflows — but on a normal portrait phone the
                  // column fits and the spacers do their job.
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                children: <Widget>[
                  const Spacer(flex: 2),
                  // Pulsing bell icon.
                  ScaleTransition(
                    scale: Tween<double>(begin: 0.92, end: 1.08).animate(
                      CurvedAnimation(
                        parent: _pulse,
                        curve: Curves.easeInOut,
                      ),
                    ),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.primary.withValues(alpha: 0.18),
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.alarm,
                        size: 64,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Live time.
                  Text(
                    _formatTime(_now),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 84,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 2,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(_now),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Alarm label.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _dismissHint(widget.payload.alarm.dismissMethod),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(flex: 3),
                  BigActionButton(
                    label: 'Snooze',
                    icon: Icons.snooze,
                    color: const Color(0xFF455A64),
                    onPressed: () async {
                      await _controller.snooze();
                    },
                  ),
                  const SizedBox(height: 16),
                  BigActionButton(
                    label: 'Dismiss',
                    icon: Icons.alarm_off,
                    color: cs.primary,
                    onPressed: () async {
                      await _controller.requestDismiss();
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedBackground extends StatelessWidget {
  const _AnimatedBackground({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? _) {
        final double t = Curves.easeInOut.transform(animation.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.4,
              colors: <Color>[
                Color.lerp(
                  primary.withValues(alpha: 0.35),
                  primary.withValues(alpha: 0.10),
                  t,
                )!,
                Colors.black,
              ],
              stops: const <double>[0.0, 1.0],
            ),
          ),
        );
      },
    );
  }
}

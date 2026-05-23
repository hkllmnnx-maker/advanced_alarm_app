import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../data/models/alarm.dart';
import '../data/models/dismiss_method.dart';
import 'audio/alarm_audio_player.dart';
import 'audio/alarm_vibrator.dart';
import 'ringing_payload.dart';
import 'services/shake_detector.dart';
import 'services/wakelock_guard.dart';

/// Possible outcomes of a ringing session.
///
/// The host (e.g. an `AlarmService`) can react to each outcome
/// differently — typically by snoozing or by clearing the active fire.
enum RingingResult {
  /// User dismissed the alarm successfully (with whatever challenge was
  /// configured satisfied).
  dismissed,

  /// User chose to snooze. The host should reschedule the alarm for
  /// `now + alarm.snoozeDurationMinutes`.
  snoozed,

  /// The session was force-stopped externally (e.g. another alarm took
  /// over, the host called [RingingController.cancel]).
  cancelled,
}

/// What is currently blocking dismissal — used by the UI to render the
/// correct challenge widget.
enum RingingChallenge {
  none,
  mathPuzzle,
  shake,
}

/// Top-level lifecycle state of a single ringing session.
enum RingingPhase {
  idle,
  ringing,
  challengeInProgress,
  finished,
}

/// Orchestrates every moving part of a single firing alarm:
///
///  * audio playback (with gradual volume rise, focus loss handling,
///    headphone-unplug detection),
///  * vibration,
///  * wakelock,
///  * dismiss challenge (math puzzle / shake) when the alarm requires
///    one,
///  * lifecycle observers that pause/resume audio when the OS pulls
///    the app into the background (so the alarm doesn't keep playing
///    after a process death — `_stopAll` is also called from `dispose`
///    no matter how the screen exits).
///
/// The controller is a [ChangeNotifier] so the UI can rebuild on every
/// state change, but it is *not* a singleton: a fresh instance is
/// created per ringing session and disposed when the screen closes.
class RingingController extends ChangeNotifier with WidgetsBindingObserver {
  RingingController({
    required this.payload,
    AlarmAudioPlayer? audioPlayer,
    AlarmVibrator? vibrator,
    ShakeDetector? shakeDetector,
    WakelockGuard? wakelock,
  })  : _audio = audioPlayer ?? AlarmAudioPlayer(),
        _vibrator = vibrator ?? AlarmVibrator(),
        _shake = shakeDetector ?? ShakeDetector(),
        _wakelock = wakelock ?? WakelockGuard();

  final RingingPayload payload;
  Alarm get alarm => payload.alarm;

  final AlarmAudioPlayer _audio;
  final AlarmVibrator _vibrator;
  final ShakeDetector _shake;
  final WakelockGuard _wakelock;

  RingingPhase _phase = RingingPhase.idle;
  RingingChallenge _challenge = RingingChallenge.none;
  RingingResult? _result;
  int _shakeProgress = 0;
  bool _disposed = false;
  bool _isPausedByLifecycle = false;

  /// Stream of "the session has ended" — surfaces [_result] exactly once
  /// so navigation logic doesn't have to listen to [notifyListeners].
  final Completer<RingingResult> _completer = Completer<RingingResult>();

  RingingPhase get phase => _phase;
  RingingChallenge get activeChallenge => _challenge;
  RingingResult? get result => _result;
  int get shakeProgress => _shakeProgress;
  int get shakesRequired => _shake.shakesRequired;
  bool get isFinished => _phase == RingingPhase.finished;

  /// Future that completes when the session ends, with the final
  /// [RingingResult].
  Future<RingingResult> get done => _completer.future;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Boots audio, vibration and the wakelock. Safe to call exactly once
  /// — subsequent calls are no-ops.
  Future<void> start() async {
    if (_phase != RingingPhase.idle || _disposed) return;
    _phase = RingingPhase.ringing;
    notifyListeners();

    WidgetsBinding.instance.addObserver(this);

    await _wakelock.acquire();
    await _vibrator.start().then((_) {
      // Don't fail the whole alarm if vibration died — log only.
      return;
    }).catchError((Object e, StackTrace st) {
      if (kDebugMode) {
        debugPrint('RingingController vibrator.start error: $e\n$st');
      }
    });

    if (!alarm.vibrate) {
      await _vibrator.stop();
    }

    try {
      await _audio.start(
        ringtonePath: alarm.ringtonePath,
        gradualVolumeRise: alarm.gradualVolumeIncrease,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('RingingController audio.start error: $e\n$st');
      }
      // Audio failure must NOT kill the ringing experience — the user
      // can still see the screen and dismiss it.
    }
  }

  /// User pressed the Snooze button. Stops all output and resolves
  /// [done] with [RingingResult.snoozed].
  Future<void> snooze() async {
    await _finish(RingingResult.snoozed);
  }

  /// User pressed the Dismiss button. If a challenge is required this
  /// only *requests* the challenge; the actual dismissal happens when
  /// the challenge is solved.
  Future<void> requestDismiss() async {
    if (_phase != RingingPhase.ringing) return;
    switch (alarm.dismissMethod) {
      case DismissMethod.tap:
        await _finish(RingingResult.dismissed);
        break;
      case DismissMethod.mathPuzzle:
        _challenge = RingingChallenge.mathPuzzle;
        _phase = RingingPhase.challengeInProgress;
        notifyListeners();
        break;
      case DismissMethod.shake:
        _challenge = RingingChallenge.shake;
        _phase = RingingPhase.challengeInProgress;
        _shakeProgress = 0;
        notifyListeners();
        _shake.start(
          onShakesComplete: () {
            _onChallengeSolved();
          },
          onProgress: (int count) {
            if (_disposed) return;
            _shakeProgress = count;
            notifyListeners();
          },
        );
        break;
    }
  }

  /// User aborted the challenge (closed the dialog or pressed Back).
  Future<void> cancelChallenge() async {
    if (_phase != RingingPhase.challengeInProgress) return;
    await _shake.stop();
    _challenge = RingingChallenge.none;
    _phase = RingingPhase.ringing;
    notifyListeners();
  }

  /// Reports the answer to the active math puzzle. When [correct] is
  /// true the alarm dismisses; otherwise the UI is expected to render a
  /// new puzzle (this controller does not generate puzzles — the dialog
  /// owns that).
  Future<void> submitMathAnswer({required bool correct}) async {
    if (_phase != RingingPhase.challengeInProgress) return;
    if (_challenge != RingingChallenge.mathPuzzle) return;
    if (!correct) {
      // The dialog handles "wrong answer" feedback and re-prompts.
      return;
    }
    await _onChallengeSolved();
  }

  /// External hard-cancel (e.g. a higher-priority alarm fires while
  /// this one is ringing). Tears everything down and resolves [done]
  /// with [RingingResult.cancelled].
  Future<void> cancel() async {
    await _finish(RingingResult.cancelled);
  }

  Future<void> _onChallengeSolved() async {
    await _shake.stop();
    await _finish(RingingResult.dismissed);
  }

  Future<void> _finish(RingingResult result) async {
    if (_phase == RingingPhase.finished || _disposed) return;
    _phase = RingingPhase.finished;
    _result = result;
    _challenge = RingingChallenge.none;
    notifyListeners();
    await _stopAllOutputs();
    if (!_completer.isCompleted) {
      _completer.complete(result);
    }
  }

  Future<void> _stopAllOutputs() async {
    // Order matters: stop audio first so a slow vibration cancel never
    // leaves the speaker blaring after the screen is gone.
    await _audio.stop();
    await _vibrator.stop();
    await _shake.stop();
    await _wakelock.release();
  }

  // ---------------------------------------------------------------------------
  // App lifecycle (incoming call, OS push to background, etc.)
  // ---------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_disposed) return;
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // Incoming call / system UI / process moved to background.
        // Stop audio so we don't keep playing under the call — but
        // KEEP vibration so the user knows the alarm is still pending.
        _isPausedByLifecycle = true;
        unawaited(_audio.stop());
        break;
      case AppLifecycleState.resumed:
        if (!_isPausedByLifecycle) return;
        _isPausedByLifecycle = false;
        if (_phase == RingingPhase.ringing ||
            _phase == RingingPhase.challengeInProgress) {
          unawaited(_audio.start(
            ringtonePath: alarm.ringtonePath,
            // On resume we skip the gradual ramp so the user gets the
            // full alarm immediately — they're already half-aware.
            gradualVolumeRise: false,
          ));
        }
        break;
      case AppLifecycleState.detached:
        // Engine is going away — release everything best-effort.
        unawaited(_stopAllOutputs());
        break;
    }
  }

  /// Manually report that the audio route changed (e.g. headphones were
  /// unplugged). Boosts the volume to max so the user is not left with
  /// a quiet speaker. Exposed as a method so the host platform can
  /// route `AudioManager.ACTION_AUDIO_BECOMING_NOISY` here.
  Future<void> onAudioBecomingNoisy() async {
    if (_disposed) return;
    await _audio.boostToMax();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    // Fire-and-forget: dispose is synchronous, but we still want every
    // async resource released. Failures are already swallowed inside
    // each helper.
    unawaited(_audio.dispose());
    unawaited(_vibrator.dispose());
    unawaited(_shake.dispose());
    unawaited(_wakelock.dispose());
    if (!_completer.isCompleted) {
      _completer.complete(RingingResult.cancelled);
    }
    super.dispose();
  }
}

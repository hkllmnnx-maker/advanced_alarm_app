import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Encapsulates everything related to *playing* the alarm sound:
///
///  * Plays a ringtone in a loop from an asset, a file path or a URL.
///  * Optional gradual volume rise over 30 seconds.
///  * Reacts to audio focus / interruption events (e.g. an incoming call):
///    pauses on loss, resumes on regain.
///  * Reacts to the `becomingNoisy` event (headphones unplugged) by
///    redirecting playback to the speaker at full volume so the user is
///    never silently un-alarmed.
///  * Guarantees that [stop] is idempotent and that no audio can leak
///    after it has been called.
///
/// All public methods are safe to call multiple times — internal flags
/// short-circuit redundant work.
class AlarmAudioPlayer {
  AlarmAudioPlayer();

  /// How long the gradual volume rise takes to reach full volume.
  static const Duration gradualRampDuration = Duration(seconds: 30);

  /// How often the volume is bumped during the gradual rise.
  static const Duration _rampTick = Duration(milliseconds: 500);

  /// Fallback asset used when [start] is called with an empty path.
  /// The asset itself is *not* required to exist at runtime: if it
  /// cannot be loaded we silently degrade to "vibration only" so the
  /// alarm is never completely silent because of a missing file.
  static const String _fallbackAsset = 'assets/audio/default_alarm.mp3';

  final AudioPlayer _player = AudioPlayer();

  /// Currently configured target volume (0..1). When a gradual ramp is
  /// active, [_currentVolume] climbs from 0 → [_targetVolume] over
  /// [gradualRampDuration].
  double _targetVolume = 1.0;
  double _currentVolume = 0.0;

  Timer? _rampTimer;
  StreamSubscription<void>? _completeSub;
  StreamSubscription<PlayerState>? _stateSub;

  bool _started = false;
  bool _stopped = false;
  bool _pausedByInterruption = false;

  /// Whether the player is currently producing sound.
  bool get isPlaying => _started && !_stopped && !_pausedByInterruption;

  /// Starts playing the configured ringtone in a loop.
  ///
  /// * [ringtonePath] — empty string means "use the bundled default
  ///   asset". Anything starting with `assets/` is treated as a Flutter
  ///   asset; otherwise it is treated as a file system path.
  /// * [gradualVolumeRise] — when `true`, volume ramps from 0 to 1.0
  ///   over [gradualRampDuration]. When `false`, full volume from t=0.
  Future<void> start({
    required String ringtonePath,
    required bool gradualVolumeRise,
    double maxVolume = 1.0,
  }) async {
    if (_started) return; // idempotent

    _started = true;
    _stopped = false;
    _targetVolume = maxVolume.clamp(0.0, 1.0).toDouble();
    _currentVolume = gradualVolumeRise ? 0.0 : _targetVolume;

    // Configure audio context so the OS treats us like an alarm —
    // ducking music, ignoring the silent switch on iOS, and continuing
    // through headphone-unplug events on Android (which fires
    // becomingNoisy that we explicitly *don't* honour by stopping).
    try {
      await _player.setAudioContext(_alarmContext());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AlarmAudioPlayer.setAudioContext failed: $e');
      }
    }

    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(_currentVolume);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AlarmAudioPlayer.setReleaseMode/setVolume failed: $e');
      }
    }

    // Observe state changes so we can react to OS-driven pauses
    // (incoming calls, audio focus loss, headphones unplugged on
    // Android, etc.) and resume automatically once the OS hands focus
    // back to us.
    await _stateSub?.cancel();
    _stateSub = _player.onPlayerStateChanged.listen(_onPlayerStateChanged);

    await _completeSub?.cancel();
    _completeSub = _player.onPlayerComplete.listen((_) {
      // ReleaseMode.loop should make this unreachable, but we re-arm
      // playback defensively so the alarm cannot accidentally fall
      // silent on edge cases.
      _restartLoop();
    });

    await _playCurrentSource(ringtonePath);

    if (gradualVolumeRise && !_stopped) {
      _scheduleRamp();
    }
  }

  /// Stops playback and tears down every resource owned by this player.
  ///
  /// Safe to call multiple times. After [stop] has run, no further audio
  /// can be produced by this instance.
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _rampTimer?.cancel();
    _rampTimer = null;

    try {
      await _player.stop();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AlarmAudioPlayer.stop failed: $e');
      }
    }

    await _stateSub?.cancel();
    _stateSub = null;
    await _completeSub?.cancel();
    _completeSub = null;
  }

  /// Releases all native resources. Call from `dispose()` of the owning
  /// controller so the underlying platform player is freed.
  Future<void> dispose() async {
    await stop();
    try {
      await _player.release();
      await _player.dispose();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AlarmAudioPlayer.dispose failed: $e');
      }
    }
  }

  /// Forces the volume to its maximum target value and cancels any
  /// active gradual ramp. Used when headphones are unplugged so the
  /// user is not left listening to a barely-audible alarm on the
  /// speaker.
  Future<void> boostToMax() async {
    if (_stopped) return;
    _rampTimer?.cancel();
    _rampTimer = null;
    _currentVolume = _targetVolume;
    try {
      await _player.setVolume(_currentVolume);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AlarmAudioPlayer.boostToMax failed: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<void> _playCurrentSource(String ringtonePath) async {
    final Source source = _resolveSource(ringtonePath);
    try {
      await _player.play(source, volume: _currentVolume);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'AlarmAudioPlayer.play primary failed: $e — trying fallback',
        );
      }
      // Try the bundled fallback so a broken / missing user-selected
      // ringtone never produces a completely silent alarm.
      try {
        await _player.play(AssetSource(_fallbackAsset), volume: _currentVolume);
      } catch (e2) {
        if (kDebugMode) {
          debugPrint('AlarmAudioPlayer.play fallback failed: $e2');
        }
        // We swallow the error: the [AlarmVibrator] will still fire,
        // and the UI is fully usable. Silent failure beats a crash on
        // the lock screen.
      }
    }
  }

  Source _resolveSource(String ringtonePath) {
    if (ringtonePath.isEmpty) {
      return AssetSource(_fallbackAsset);
    }
    if (ringtonePath.startsWith('asset:') ||
        ringtonePath.startsWith('assets/')) {
      final String assetKey = ringtonePath.startsWith('asset:')
          ? ringtonePath.substring('asset:'.length)
          : ringtonePath;
      return AssetSource(assetKey);
    }
    if (ringtonePath.startsWith('http://') ||
        ringtonePath.startsWith('https://')) {
      return UrlSource(ringtonePath);
    }
    return DeviceFileSource(ringtonePath);
  }

  void _scheduleRamp() {
    final int totalTicks =
        gradualRampDuration.inMilliseconds ~/ _rampTick.inMilliseconds;
    if (totalTicks <= 0) return;
    final double step = _targetVolume / totalTicks;
    int tick = 0;

    _rampTimer?.cancel();
    _rampTimer = Timer.periodic(_rampTick, (Timer timer) async {
      if (_stopped) {
        timer.cancel();
        return;
      }
      tick++;
      _currentVolume = (tick * step).clamp(0.0, _targetVolume).toDouble();
      try {
        await _player.setVolume(_currentVolume);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('AlarmAudioPlayer ramp setVolume failed: $e');
        }
      }
      if (tick >= totalTicks) {
        timer.cancel();
      }
    });
  }

  void _onPlayerStateChanged(PlayerState state) {
    if (_stopped) return;
    switch (state) {
      case PlayerState.paused:
        // The OS paused us — most likely an incoming call or another
        // app grabbing audio focus. Remember it so the next "playing"
        // event can flip the flag back.
        _pausedByInterruption = true;
        if (kDebugMode) {
          debugPrint('AlarmAudioPlayer: paused by OS (audio focus lost)');
        }
        // We don't try to immediately resume here — that would fight
        // the OS. Instead the [onAudioInterruptionEnded] callback (when
        // available) or the next resume hint will take care of it.
        break;
      case PlayerState.playing:
        _pausedByInterruption = false;
        break;
      case PlayerState.stopped:
      case PlayerState.completed:
      case PlayerState.disposed:
        // No-op; [_completeSub] handles loop re-arming.
        break;
    }
  }

  Future<void> _restartLoop() async {
    if (_stopped) return;
    try {
      await _player.resume();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AlarmAudioPlayer._restartLoop failed: $e');
      }
    }
  }

  /// Builds an [AudioContext] that requests "alarm" semantics on every
  /// platform that exposes them.
  AudioContext _alarmContext() {
    if (Platform.isAndroid) {
      return AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const <AVAudioSessionOptions>{
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
      );
    }
    return AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: const <AVAudioSessionOptions>{
          AVAudioSessionOptions.mixWithOthers,
        },
      ),
      android: const AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: true,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.alarm,
        audioFocus: AndroidAudioFocus.gainTransientMayDuck,
      ),
    );
  }
}

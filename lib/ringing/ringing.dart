/// Public entry points of the ringing experience.
///
/// Other agents wire their alarm engine to this layer by:
///
///  1. Constructing a [RingingPayload] from the firing [Alarm].
///  2. Pushing [RingingScreen.route] onto the navigator (typically as
///     the `home` of a one-shot `MaterialApp` opened by a full-screen
///     intent).
///  3. Awaiting the returned [RingingResult] and acting on it
///     (snooze / dismiss / cancel).
library;

export 'ringing_controller.dart'
    show RingingController, RingingResult, RingingPhase, RingingChallenge;
export 'ringing_payload.dart' show RingingPayload;
export 'ringing_screen.dart' show RingingScreen;

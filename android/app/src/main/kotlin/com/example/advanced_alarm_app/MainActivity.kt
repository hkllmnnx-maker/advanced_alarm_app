package com.example.advanced_alarm_app

import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

/**
 * Main entry activity.
 *
 * This activity is also the target of the alarm engine's full-screen
 * intent, so it must be allowed to appear over the lock screen and to
 * turn the screen on by itself when an alarm fires.
 *
 * The flags below are the modern (API 27+) replacements for the long
 * deprecated `WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED` /
 * `FLAG_TURN_SCREEN_ON`. We still set them programmatically in addition
 * to the matching `AndroidManifest.xml` attributes so the activity
 * behaves correctly even when recreated after a configuration change
 * while ringing.
 */
class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager?
            // Best-effort: ask the keyguard to dismiss itself when the
            // user interacts with the ringing screen. We deliberately
            // pass `null` for the callback because the dismiss success
            // is not actionable from here — the Flutter side already
            // owns the snooze/dismiss flow.
            km?.requestDismissKeyguard(this, null)
        }
    }
}

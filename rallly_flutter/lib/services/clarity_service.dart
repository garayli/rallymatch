import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/clarity_config.dart';
import 'clarity_sdk.dart';

/// Opt-in session recording through Microsoft Clarity (ADR-016).
///
/// Nothing is captured until the user says yes: [consent] is `null` until they
/// answer, and the SDK is only initialised once it is `true`. Turning it off
/// later pauses capture and tells Clarity the consent was withdrawn. Like
/// [AnalyticsService], every call swallows its own errors so a recording
/// problem can never break a user flow.
class ClarityService {
  ClarityService._();
  static final ClarityService instance = ClarityService._();

  static const _prefsKey = 'clarity_consent';

  /// Clarity has no web SDK, and without a project ID there is nothing to
  /// send to — in both cases the whole feature (including the prompt) is off.
  bool get available =>
      clarityProjectId.isNotEmpty &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// `null` = not asked yet, `true` = recording allowed, `false` = declined.
  final ValueNotifier<bool?> consent = ValueNotifier<bool?>(null);

  bool _started = false;

  /// Reads the saved answer. Called once before `runApp`.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      consent.value = prefs.getBool(_prefsKey);
    } catch (e) {
      debugPrint('CLARITY ERROR (load): $e');
    }
  }

  /// Saves the user's answer and starts or pauses recording to match.
  /// [context] must belong to a mounted widget under the app (the SDK needs
  /// it to find the screen to record).
  Future<void> setConsent(bool allowed, BuildContext context) async {
    consent.value = allowed;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, allowed);
    } catch (e) {
      debugPrint('CLARITY ERROR (save): $e');
    }
    if (!context.mounted) return;
    if (allowed) {
      start(context);
    } else {
      _stop();
    }
  }

  /// Starts recording if the user has opted in. Safe to call repeatedly.
  void start(BuildContext context) {
    if (!available || consent.value != true) return;
    try {
      if (!_started) {
        _started = clarityInitialize(context, clarityProjectId);
      } else {
        clarityResume();
      }
      clarityConsent(true);
    } catch (e) {
      debugPrint('CLARITY ERROR (start): $e');
    }
  }

  void _stop() {
    if (!_started) return;
    try {
      clarityConsent(false);
      clarityPause();
    } catch (e) {
      debugPrint('CLARITY ERROR (stop): $e');
    }
  }
}

final clarityService = ClarityService.instance;

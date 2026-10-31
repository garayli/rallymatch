import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

/// Thin wrapper around FirebaseAnalytics so screens never import the
/// Firebase package directly. Mirrors the DataService pattern in this repo.
///
/// Call sites fire and forget (`unawaited(...)`): analytics must never delay
/// or break a user flow, so every call swallows its own errors.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  // False when Firebase failed to start (web without a valid config, see
  // main.dart) — every call is then a no-op.
  bool get _enabled => Firebase.apps.isNotEmpty;

  FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  NavigatorObserver get observer => _enabled
      ? FirebaseAnalyticsObserver(analytics: _analytics)
      : NavigatorObserver();

  Future<void> logEvent(String name, [Map<String, Object>? parameters]) async {
    try {
      if (!_enabled) return;
      await _analytics.logEvent(name: name, parameters: parameters);
    } catch (e) {
      debugPrint('ANALYTICS ERROR ($name): $e');
    }
  }

  /// The Supabase user id (a pseudonymous uuid), so funnels follow one person
  /// across devices. Never pass an email or phone number here.
  Future<void> setUserId(String? id) async {
    try {
      if (!_enabled) return;
      await _analytics.setUserId(id: id);
    } catch (e) {
      debugPrint('ANALYTICS ERROR (setUserId): $e');
    }
  }

  // ── Funnel events ────────────────────────────────────────────────────────
  // Visit → otp_requested → otp_verified → sign_up → match_requested /
  // lobby_joined → match_request_responded → result_submitted →
  // result_confirmed. Parameter values are strings (Firebase drops bools).

  /// [flow] is `signup` or `login`. A gap between this and [logOtpVerified]
  /// is the email-delivery drop-off.
  Future<void> logOtpRequested({required String flow}) =>
      logEvent('otp_requested', {'flow': flow});

  Future<void> logOtpVerified({required String flow}) =>
      logEvent('otp_verified', {'flow': flow});

  Future<void> logSignUp() => logEvent('sign_up', {'method': 'email_otp'});

  Future<void> logLogin() => logEvent('login', {'method': 'email_otp'});

  /// [opponentType] is `registered` or `guest`.
  Future<void> logMatchRequested({
    required String format,
    required String opponentType,
  }) =>
      logEvent('match_requested', {
        'format': format,
        'opponent_type': opponentType,
      });

  Future<void> logMatchRequestResponded({required bool accepted}) =>
      logEvent('match_request_responded',
          {'response': accepted ? 'accepted' : 'declined'});

  Future<void> logLobbyCreated({
    required String sport,
    required String format,
    required String skillLevel,
  }) =>
      logEvent('lobby_created', {
        'sport': sport,
        'format': format,
        'skill_level': skillLevel,
      });

  /// [source] is `list` (Match tab) or `link` (an opened invite link).
  Future<void> logLobbyJoined({required String sport, required String source}) =>
      logEvent('lobby_joined', {'sport': sport, 'source': source});

  /// An invite link was opened. With `signed_in` = no, the funnel continues
  /// at otp_requested → sign_up → lobby_joined (source = link).
  Future<void> logLobbyLinkOpened({required bool signedIn}) =>
      logEvent('lobby_link_opened', {'signed_in': signedIn ? 'yes' : 'no'});

  /// [opponentType] is `registered` or `guest`; a guest result carries a
  /// phone number, so it is the seed of the invite loop.
  Future<void> logResultSubmitted({
    required String opponentType,
    required bool won,
  }) =>
      logEvent('result_submitted', {
        'opponent_type': opponentType,
        'outcome': won ? 'win' : 'loss',
      });

  /// The opponent confirmed: the match counts as played (North Star).
  Future<void> logResultConfirmed() => logEvent('result_confirmed');

  Future<void> logResultDisputed() => logEvent('result_disputed');

  Future<void> logMessageSent() => logEvent('message_sent');

  /// [contentType] is `result_card` or `lobby`. [status] is share_plus's
  /// ShareResultStatus name (`success`, `dismissed`, `unavailable`), or
  /// `copied` when a desktop browser had no share sheet.
  Future<void> logShare({
    required String contentType,
    required String status,
  }) =>
      logEvent('share', {'content_type': contentType, 'status': status});
}

final analyticsService = AnalyticsService.instance;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

/// Thin wrapper around FirebaseAnalytics so screens never import the
/// Firebase package directly. Mirrors the DataService pattern in this repo.
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
    if (!_enabled) return;
    await _analytics.logEvent(name: name, parameters: parameters);
  }

  Future<void> setUserId(String? id) async {
    if (!_enabled) return;
    await _analytics.setUserId(id: id);
  }

  // ── Domain-specific events ───────────────────────────────────────────────

  Future<void> logMatchRequested({required String opponentId}) =>
      logEvent('match_requested', {'opponent_id': opponentId});

  Future<void> logResultSubmitted({required String matchId}) =>
      logEvent('result_submitted', {'match_id': matchId});

  Future<void> logGameCreated({required String gameId}) =>
      logEvent('game_created', {'game_id': gameId});
}

final analyticsService = AnalyticsService.instance;

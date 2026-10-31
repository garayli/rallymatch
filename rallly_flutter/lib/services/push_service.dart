import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../main.dart' show supabase;
import 'analytics_service.dart';
import 'data_service.dart';

/// MainShell tab a tapped push opens (the `tab` key the `push` edge function
/// puts in the FCM data): 1 Messages, 2 Bildirimler. Null = stay put.
int? shellTabForPush(Map<String, dynamic> data) => switch (data['tab']) {
      'messages' => 1,
      'alerts' => 2,
      _ => null,
    };

/// Push notifications (FCM), Android only for now: no web push and no iOS
/// app yet. The app only registers this device's token for the signed-in
/// player; `supabase/functions/push` sends a push for every new
/// `notifications` / `messages` row (Database Webhooks).
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  /// Set when a push is tapped; MainShell switches to that tab and clears it.
  final ValueNotifier<int?> openTab = ValueNotifier(null);

  bool _listening = false;
  StreamSubscription<String>? _tokenRefresh;
  String? _token;

  bool get _supported =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      Firebase.apps.isNotEmpty;

  /// Asks for permission (Android 13+ shows the system prompt once), saves
  /// this device's token for the signed-in player and handles taps. Safe to
  /// call on every MainShell start.
  Future<void> register() async {
    if (!_supported) return;
    try {
      final messaging = FirebaseMessaging.instance;
      _listen();
      final settings = await messaging.requestPermission();
      final status = settings.authorizationStatus.name;
      unawaited(analyticsService.logPushPermission(status: status));
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await messaging.getToken();
      if (token != null) await _save(token);
      _tokenRefresh ??= messaging.onTokenRefresh.listen(_save);
    } catch (e) {
      debugPrint('PUSH REGISTER ERROR: $e');
    }
  }

  /// Call before signing out (the RPC needs the session), so this phone
  /// stops getting the previous player's pushes.
  Future<void> unregister() async {
    final token = _token;
    if (!_supported || token == null) return;
    try {
      await supabase.rpc('unregister_push_token', params: {'p_token': token});
      _token = null;
    } catch (e) {
      debugPrint('PUSH UNREGISTER ERROR: $e');
    }
  }

  void _listen() {
    if (_listening) return;
    _listening = true;
    // With the app open Android shows nothing: refresh what's on screen now
    // instead of waiting for the next 10 s poll.
    FirebaseMessaging.onMessage.listen((_) => dataService.refreshLive());
    FirebaseMessaging.onMessageOpenedApp.listen(_opened);
    // Cold start from a tap: MainShell reads [openTab] when it mounts.
    unawaited(FirebaseMessaging.instance.getInitialMessage().then((m) {
      if (m != null) _opened(m);
    }));
  }

  void _opened(RemoteMessage message) {
    final tab = shellTabForPush(message.data);
    unawaited(analyticsService.logPushOpened(tab: '${message.data['tab']}'));
    if (tab != null) openTab.value = tab;
    dataService.refreshLive();
  }

  Future<void> _save(String token) async {
    try {
      // register_push_token (SECURITY DEFINER) moves a token another account
      // left on this phone over to the current player.
      await supabase.rpc('register_push_token',
          params: {'p_token': token, 'p_platform': 'android'});
      _token = token;
    } catch (e) {
      debugPrint('PUSH TOKEN SAVE ERROR: $e');
    }
  }
}

final pushService = PushService.instance;

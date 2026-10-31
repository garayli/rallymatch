import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../config/app_links.dart';
import '../l10n/data_error_message.dart';
import '../l10n/l10n.dart';
import '../l10n/option_labels.dart';
import '../models/models.dart';
import '../services/analytics_service.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';

/// Lobby actions shared by the Match-tab card, the manage sheet and the
/// invite-link screen, so all of them behave and report the same way.

const lobbySportEmojis = {
  'Tenis': '🎾',
  'Padel': '🏓',
  'Badminton': '🏸',
  'Squash': '🟡',
};

/// Opens the system share sheet (WhatsApp, Instagram, …) with an invite to
/// [lobby]. The link opens the lobby in the app on Android and in the web app
/// everywhere else, signed in or not. Desktop browsers have no share sheet
/// (no Web Share API): there the invite is copied to the clipboard instead of
/// share_plus's default mailto: fallback, which often does nothing.
Future<void> shareLobby(BuildContext context, Lobby lobby) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final dt = lobby.dateTime;
  final text = l.lobbyShareText(
    sportLabel(l, lobby.sport),
    dt == null ? '' : DateFormat('EEE d MMM, HH:mm', context.localeName).format(dt),
    lobby.court,
    lobbyLink(lobby.id),
  );
  try {
    final shared = await SharePlus.instance
        .share(ShareParams(text: text, mailToFallbackEnabled: false));
    unawaited(analyticsService.logShare(
      contentType: 'lobby',
      status: shared.status.name,
    ));
  } catch (e) {
    debugPrint('LOBBY SHARE UNAVAILABLE, COPYING: $e');
    try {
      await Clipboard.setData(ClipboardData(text: text));
      unawaited(analyticsService.logShare(contentType: 'lobby', status: 'copied'));
      messenger.showSnackBar(SnackBar(
        content: Text(l.lobbyLinkCopied),
        backgroundColor: RallyColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (e) {
      debugPrint('LOBBY SHARE ERROR: $e');
      messenger.showSnackBar(SnackBar(content: Text(l.shareFailed)));
    }
  }
}

/// Sends a join request for [lobby] and reports the outcome in a snackbar.
/// Returns whether the request went through. [source] (`list` / `link`) only
/// feeds analytics.
Future<bool> joinLobbyWithFeedback(
  BuildContext context,
  Lobby lobby, {
  required String source,
}) async {
  final dt = lobby.dateTime;
  if (dt == null) return false;
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await dataService.joinLobby(
      lobbyId: lobby.id,
      creatorId: lobby.creatorId,
      dateTime: dt,
      court: lobby.court,
      sport: sportLabel(l, lobby.sport),
      source: source,
    );
    messenger.showSnackBar(SnackBar(
      content: Text(l.lobbyJoinSent(sportLabel(l, lobby.sport))),
      backgroundColor: RallyColors.accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
    return true;
  } catch (e) {
    debugPrint('LOBBY JOIN ERROR: $e');
    // The lobby was stale (someone filled it meanwhile): re-read.
    dataService.refreshLive();
    messenger.showSnackBar(SnackBar(
      content: Text(l.actionFailed(dataErrorMessage(l, e))),
      backgroundColor: RallyColors.accent2,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
    return false;
  }
}

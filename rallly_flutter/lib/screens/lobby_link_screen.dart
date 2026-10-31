import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n.dart';
import '../l10n/option_labels.dart';
import '../main.dart' show CourtThemeProvider, supabase;
import '../models/models.dart';
import '../router/app_router.dart';
import '../services/analytics_service.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';
import '../utils/lobby_state.dart';
import '../widgets/lobby_actions.dart';
import '../widgets/lobby_manage_sheet.dart';

/// Where an invite link (kortagel.com/l/<id>) lands. Signed out it is a public
/// preview with "Kaydol ve katıl" — the link is kept through auth and the
/// signup wizard, so the new player comes back here to join. Signed in it
/// offers the same action as the lobby card on the Match tab.
class LobbyLinkScreen extends StatefulWidget {
  final String lobbyId;
  const LobbyLinkScreen({super.key, required this.lobbyId});

  @override
  State<LobbyLinkScreen> createState() => _LobbyLinkScreenState();
}

class _LobbyLinkScreenState extends State<LobbyLinkScreen> {
  late Future<Lobby?> _lobby = dataService.getLobby(widget.lobbyId);
  bool _joining = false;

  bool get _signedIn => supabase.auth.currentSession != null;

  @override
  void initState() {
    super.initState();
    unawaited(analyticsService.logLobbyLinkOpened(signedIn: _signedIn));
    if (_signedIn) {
      // Arrived: the link kept through the auth flow is used up.
      clearPendingLobbyLink();
      // Opened cold from a link, MainShell never warmed the cache: without
      // it this screen can't tell "already requested" or name the organiser.
      dataService.cacheVersion.addListener(_onCache);
      unawaited(dataService.warmCache().then((_) => _onCache()));
    }
  }

  @override
  void dispose() {
    dataService.cacheVersion.removeListener(_onCache);
    super.dispose();
  }

  void _onCache() {
    if (mounted) setState(() {});
  }

  void _retry() =>
      setState(() => _lobby = dataService.getLobby(widget.lobbyId));

  void _leave() => context.go(_signedIn ? AppRoutes.home : AppRoutes.landing);

  void _startAuth({required bool signUp}) {
    rememberLobbyLink('${AppRoutes.lobby}/${widget.lobbyId}');
    context.go(AppRoutes.authEmail, extra: {'isSignUp': signUp});
  }

  Future<void> _join(Lobby lobby) async {
    setState(() => _joining = true);
    await joinLobbyWithFeedback(context, lobby, source: 'link');
    if (mounted) setState(() => _joining = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cp = CourtThemeProvider.of(context);
    return Scaffold(
      backgroundColor: cp.bg,
      appBar: AppBar(
        backgroundColor: cp.bg,
        foregroundColor: cp.text,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: _leave),
        title: Text(l.lobbyLinkTitle,
            style: RallyType.titleMD.copyWith(color: cp.text)),
      ),
      body: FutureBuilder<Lobby?>(
        future: _lobby,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator(color: cp.accent));
          }
          if (snap.hasError) {
            debugPrint('LOBBY LINK LOAD ERROR: ${snap.error}');
            return _Message(
              icon: Icons.wifi_off,
              title: l.lobbyLinkLoadFailed,
              action: l.lobbyLinkRetry,
              onAction: _retry,
            );
          }
          final lobby = snap.data;
          if (lobby == null) {
            return _Message(
              icon: Icons.event_busy,
              title: l.lobbyLinkUnavailable,
              body: l.lobbyLinkUnavailableHint,
              action: _signedIn ? l.lobbyLinkBrowse : l.landingGetStarted,
              onAction: _signedIn ? _leave : () => _startAuth(signUp: true),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(Spacing.xl),
            children: [
              LobbyInviteCard(
                lobby: lobby,
                organiserName: dataService
                    .getPlayers()
                    .where((p) => p.id == lobby.creatorId)
                    .firstOrNull
                    ?.name,
              ),
              const SizedBox(height: Spacing.xl),
              if (_signedIn)
                ..._signedInActions(lobby, cp)
              else
                ..._signedOutActions(cp),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _signedOutActions(CourtPalette cp) {
    final l = context.l10n;
    return [
      FilledButton(
        onPressed: () => _startAuth(signUp: true),
        style: FilledButton.styleFrom(
          backgroundColor: cp.accent,
          minimumSize: const Size.fromHeight(48),
        ),
        child: Text(l.lobbyLinkSignUpToJoin),
      ),
      const SizedBox(height: Spacing.sm),
      TextButton(
        onPressed: () => _startAuth(signUp: false),
        child: Text(l.landingHaveAccount,
            style: TextStyle(color: cp.accentStrong)),
      ),
      const SizedBox(height: Spacing.xs),
      Text(l.lobbyLinkSignedOutHint,
          textAlign: TextAlign.center,
          style: RallyType.caption.copyWith(color: cp.muted)),
    ];
  }

  List<Widget> _signedInActions(Lobby lobby, CourtPalette cp) {
    final l = context.l10n;
    final mine = dataService
        .getUpcomingSessions()
        .where((s) =>
            s.lobbyId == lobby.id &&
            s.isRequester &&
            (s.status == MatchStatus.pending ||
                s.status == MatchStatus.confirmed))
        .firstOrNull;
    final state = lobbyCardState(lobby, mine, dataService.currentUserId);
    final label = switch (state) {
      LobbyCardState.own => l.lobbyManage,
      LobbyCardState.canJoin => l.join,
      LobbyCardState.requested => l.lobbyRequested,
      LobbyCardState.joined => l.lobbyJoined,
      LobbyCardState.queueFull => l.lobbyQueueFull,
      LobbyCardState.rosterFull => l.lobbyRosterFull,
    };
    final VoidCallback? onPressed = switch (state) {
      LobbyCardState.own => () => showLobbyManageSheet(context, lobby),
      LobbyCardState.canJoin => _joining ? null : () => _join(lobby),
      _ => null,
    };
    return [
      FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: cp.accent,
          minimumSize: const Size.fromHeight(48),
        ),
        child: Text(label),
      ),
      if (state == LobbyCardState.queueFull) ...[
        const SizedBox(height: Spacing.xs),
        Text(l.lobbyQueueFullHint,
            textAlign: TextAlign.center,
            style: RallyType.caption.copyWith(color: cp.muted)),
      ],
      const SizedBox(height: Spacing.sm),
      OutlinedButton.icon(
        onPressed: () => shareLobby(context, lobby),
        icon: const Icon(Icons.ios_share, size: 18),
        label: Text(l.lobbyShareInvite),
        style: OutlinedButton.styleFrom(
          foregroundColor: cp.accentStrong,
          minimumSize: const Size.fromHeight(44),
        ),
      ),
    ];
  }
}

/// The lobby as an invitee sees it: sport, level, format, court, time, spots.
class LobbyInviteCard extends StatelessWidget {
  final Lobby lobby;
  final String? organiserName;
  const LobbyInviteCard({super.key, required this.lobby, this.organiserName});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cp = CourtThemeProvider.of(context);
    final dt = lobby.dateTime;
    final notes = lobby.notes?.trim() ?? '';
    Widget info(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: Spacing.sm),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: cp.muted),
            const SizedBox(width: Spacing.sm),
            Expanded(
                child: Text(text,
                    style: RallyType.body.copyWith(color: cp.text))),
          ]),
        );
    Widget chip(String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: cp.accentTint,
            borderRadius: BorderRadius.circular(RallyRadius.pill),
          ),
          child: Text(text,
              style: RallyType.caption.copyWith(color: cp.accentStrong)),
        );

    return Container(
      padding: const EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        color: cp.surface,
        borderRadius: BorderRadius.circular(RallyRadius.xl),
        border: Border.all(color: cp.border),
        boxShadow: RallyElevation.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(lobbySportEmojis[lobby.sport] ?? '🎾',
                style: const TextStyle(fontSize: 32)),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sportLabel(l, lobby.sport),
                      style: RallyType.titleLG.copyWith(color: cp.text)),
                  if (organiserName != null)
                    Text(l.lobbyLinkOrganiser(organiserName!),
                        style: RallyType.bodySM.copyWith(color: cp.muted),
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ]),
          const SizedBox(height: Spacing.md),
          Wrap(spacing: Spacing.xs, runSpacing: Spacing.xs, children: [
            chip(skillLevelLabel(l, lobby.skillLevel)),
            chip(lobby.isDoubles ? l.formatDoubles : l.formatSingles),
          ]),
          const SizedBox(height: Spacing.xs),
          info(Icons.place_outlined, lobby.court),
          if (dt != null)
            info(Icons.event_outlined,
                DateFormat('EEEE d MMMM, HH:mm', context.localeName).format(dt)),
          info(
              Icons.group_outlined,
              l.lobbyCounts(
                  lobby.acceptedCount, lobby.capacity, lobby.pendingCount)),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: Spacing.md),
            Text(notes, style: RallyType.bodySM.copyWith(color: cp.muted)),
          ],
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final String action;
  final VoidCallback onAction;
  const _Message({
    required this.icon,
    required this.title,
    this.body,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cp = CourtThemeProvider.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: cp.muted),
          const SizedBox(height: Spacing.lg),
          Text(title,
              textAlign: TextAlign.center,
              style: RallyType.titleMD.copyWith(color: cp.text)),
          if (body != null) ...[
            const SizedBox(height: Spacing.sm),
            Text(body!,
                textAlign: TextAlign.center,
                style: RallyType.body.copyWith(color: cp.muted)),
          ],
          const SizedBox(height: Spacing.xl),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(backgroundColor: cp.accent),
            child: Text(action),
          ),
        ]),
      ),
    );
  }
}

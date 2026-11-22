import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../services/clarity_service.dart';

bool _asking = false; // the shell can call this from several places at once

/// One-time ask for Clarity session recording. Shown at most once: either
/// answer is saved, and the switch under Profile → Privacy & Security changes
/// it later. Does nothing when recording is unavailable or already answered.
Future<void> askClarityConsentIfNeeded(BuildContext context) async {
  if (!clarityService.available ||
      clarityService.consent.value != null ||
      _asking) {
    return;
  }
  _asking = true;
  final l = context.l10n;
  final allowed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(l.clarityConsentTitle),
      content: Text(l.clarityConsentBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l.clarityConsentDecline),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l.clarityConsentAllow),
        ),
      ],
    ),
  );
  _asking = false;
  if (allowed == null || !context.mounted) return;
  await clarityService.setConsent(allowed, context);
}

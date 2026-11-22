import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_links.dart';
import '../l10n/l10n.dart';
import '../main.dart' show CourtThemeProvider;
import '../services/clarity_service.dart';
import '../theme/design_tokens.dart';

/// Profile → Privacy & Security. Holds the Clarity opt-in switch (shown only
/// where recording is possible) and a link to the privacy policy.
class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cp = CourtThemeProvider.of(context);
    return Scaffold(
      backgroundColor: cp.bg,
      appBar: AppBar(
        title: Text(l.privacySecurity,
            style: const TextStyle(fontFamily: 'InstrumentSerif', fontSize: 22)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
        children: [
          if (clarityService.available)
            ValueListenableBuilder<bool?>(
              valueListenable: clarityService.consent,
              builder: (context, allowed, _) => SwitchListTile(
                value: allowed == true,
                onChanged: (v) => clarityService.setConsent(v, context),
                activeThumbColor: cp.accent,
                title: Text(l.clarityToggleTitle,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(l.clarityToggleSub),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l.privacyPolicyLink),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => launchUrl(Uri.parse('$appOrigin/privacy'),
                mode: LaunchMode.externalApplication),
          ),
        ],
      ),
    );
  }
}

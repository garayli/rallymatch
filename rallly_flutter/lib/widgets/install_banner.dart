import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/l10n.dart';
import '../main.dart' show CourtThemeProvider;
import '../services/pwa_install.dart';
import '../theme/design_tokens.dart';

/// Web-only strip above the bottom nav inviting the user to add the PWA to
/// their home screen. Chrome/Edge/Android get the browser's install dialog;
/// iOS (no install API) gets Share → "Add to Home Screen" instructions.
/// Hidden on native builds, when already running installed, or once dismissed.
class InstallBanner extends StatefulWidget {
  const InstallBanner({super.key});

  @override
  State<InstallBanner> createState() => _InstallBannerState();
}

class _InstallBannerState extends State<InstallBanner> {
  static const _prefsKey = 'install_banner_dismissed';
  bool _dismissed = true;

  @override
  void initState() {
    super.initState();
    if (kIsWeb && !pwaInstall.isStandalone) _loadDismissed();
  }

  Future<void> _loadDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _dismissed = prefs.getBool(_prefsKey) ?? false);
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
  }

  Future<void> _install() async {
    if (pwaInstall.canPrompt) {
      if (await pwaInstall.prompt()) _dismiss();
    } else {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => const _IosInstructionsSheet(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    return ValueListenableBuilder<int>(
      valueListenable: pwaInstall.changes,
      builder: (context, _, __) {
        final offer = !pwaInstall.isStandalone &&
            (pwaInstall.canPrompt || pwaInstall.isIos);
        if (!offer) return const SizedBox.shrink();

        final cp = CourtThemeProvider.of(context);
        final l = context.l10n;
        return Container(
          margin: const EdgeInsets.fromLTRB(
              Spacing.md, 0, Spacing.md, Spacing.sm),
          padding: const EdgeInsets.fromLTRB(
              Spacing.md, Spacing.sm, Spacing.xs, Spacing.sm),
          decoration: BoxDecoration(
            color: cp.surface,
            borderRadius: BorderRadius.circular(RallyRadius.lg),
            border: Border.all(color: cp.border),
            boxShadow: RallyElevation.raised,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(RallyRadius.sm),
                child: Container(
                  width: 36,
                  height: 36,
                  color: cp.accent,
                  alignment: Alignment.center,
                  child: const Icon(Icons.add_to_home_screen,
                      color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.installBannerTitle,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: cp.text)),
                    const SizedBox(height: 2),
                    Text(l.installBannerBody,
                        style: TextStyle(fontSize: 12, color: cp.muted)),
                  ],
                ),
              ),
              TextButton(
                onPressed: _install,
                style: TextButton.styleFrom(foregroundColor: cp.accent),
                child: Text(l.installBannerAction,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              IconButton(
                onPressed: _dismiss,
                tooltip: l.installBannerDismiss,
                icon: Icon(Icons.close, size: 18, color: cp.muted),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _IosInstructionsSheet extends StatelessWidget {
  const _IosInstructionsSheet();

  @override
  Widget build(BuildContext context) {
    final cp = CourtThemeProvider.of(context);
    final l = context.l10n;
    final steps = [
      (Icons.ios_share, l.installIosStep1),
      (Icons.add_box_outlined, l.installIosStep2),
      (Icons.check_circle_outline, l.installIosStep3),
    ];
    return Container(
      decoration: BoxDecoration(
        color: cp.bg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(RallyRadius.sheet)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.xl, Spacing.xl, Spacing.xl, Spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.installIosTitle,
                  style: RallyType.displayMD.copyWith(color: cp.text)),
              const SizedBox(height: Spacing.lg),
              for (final (i, (icon, text)) in steps.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.md),
                  child: Row(
                    children: [
                      Text('${i + 1}',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: cp.accent)),
                      const SizedBox(width: Spacing.md),
                      Icon(icon, color: cp.accent, size: 22),
                      const SizedBox(width: Spacing.md),
                      Expanded(
                        child: Text(text,
                            style: TextStyle(fontSize: 14, color: cp.text)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: Spacing.sm),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(backgroundColor: cp.accent),
                  child: Text(l.installIosDone),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

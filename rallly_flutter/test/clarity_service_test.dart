import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallly/l10n/app_localizations.dart';
import 'package:rallly/services/clarity_service.dart';
import 'package:rallly/widgets/clarity_consent_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => clarityService.consent.value = null);

  test('is on for Android and iOS, off elsewhere', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(clarityService.available, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(clarityService.available, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(clarityService.available, isFalse);
    debugDefaultTargetPlatformOverride = null;
  });

  test('load restores the saved answer, and null when never asked', () async {
    SharedPreferences.setMockInitialValues({});
    await clarityService.load();
    expect(clarityService.consent.value, isNull);

    SharedPreferences.setMockInitialValues({'clarity_consent': true});
    await clarityService.load();
    expect(clarityService.consent.value, isTrue);
  });

  testWidgets('setConsent saves the answer, both ways', (tester) async {
    SharedPreferences.setMockInitialValues({});
    late BuildContext ctx;
    await tester.pumpWidget(Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }));

    await clarityService.setConsent(true, ctx);
    expect(clarityService.consent.value, isTrue);
    expect((await SharedPreferences.getInstance()).getBool('clarity_consent'),
        isTrue);

    await clarityService.setConsent(false, ctx);
    expect(clarityService.consent.value, isFalse);
    expect((await SharedPreferences.getInstance()).getBool('clarity_consent'),
        isFalse);
  });

  testWidgets('the prompt appears once on mobile and saves a "no"',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }),
    ));

    final asked = askClarityConsentIfNeeded(ctx);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    await asked;
    expect(clarityService.consent.value, isFalse);

    // Answered: never asked again.
    await askClarityConsentIfNeeded(ctx);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the prompt never appears off mobile', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }),
    ));

    await askClarityConsentIfNeeded(ctx);
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
    expect(clarityService.consent.value, isNull);
    debugDefaultTargetPlatformOverride = null;
  });
}

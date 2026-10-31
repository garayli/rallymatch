import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallly/l10n/app_localizations.dart';
import 'package:rallly/widgets/delete_account_dialog.dart';

Widget _app(Locale locale) => MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: DeleteAccountDialog()),
    );

void main() {
  for (final c in const [('tr', 'onayla'), ('en', 'delete')]) {
    testWidgets('${c.$1}: delete button enables only after the confirm word',
        (tester) async {
      await tester.pumpWidget(_app(Locale(c.$1)));
      await tester.pumpAndSettle();

      final button = find.byType(TextButton).last;
      expect(tester.widget<TextButton>(button).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'nope');
      await tester.pump();
      expect(tester.widget<TextButton>(button).onPressed, isNull);

      // lower case and stray spaces still count, so a phone keyboard that
      // does not capitalise does not lock the player out.
      await tester.enterText(find.byType(TextField), '  ${c.$2} ');
      await tester.pump();
      expect(tester.widget<TextButton>(button).onPressed, isNotNull);
    });
  }
}

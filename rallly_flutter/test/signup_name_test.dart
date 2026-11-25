import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallly/l10n/app_localizations.dart';
import 'package:rallly/main.dart' show CourtThemeProvider;
import 'package:rallly/screens/signup_screen.dart';
import 'package:rallly/theme/app_theme.dart';
import 'package:rallly/widgets/shared_widgets.dart';

// RallyButton reads CourtThemeProvider.of(context), as in the real app.
Widget _app() => CourtThemeProvider(
      child: MaterialApp(
        theme: RallyTheme.light,
        locale: const Locale('tr'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: SignupScreen(onComplete: () {}),
      ),
    );

void main() {
  const surnameError = 'Adını ve soyadını birlikte yaz';

  testWidgets('name field drops invalid characters and keeps real names',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final name = find.byType(TextFormField).at(0);
    String current() => tester.widget<TextFormField>(name).controller!.text;

    await tester.enterText(name, 'Leyla!!! 123');
    await tester.pump();
    expect(current(), 'Leyla ');

    const real = "Ağaoğlu Şükrü İlkay-Öz O'Neil";
    await tester.enterText(name, real);
    await tester.pump();
    expect(current(), real);
  });

  testWidgets('a first name alone explains the surname rule instead of a dead button',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Leyla');
    await tester.pump();
    // Still typing: no error yet.
    expect(find.text(surnameError), findsNothing);

    await tester.enterText(fields.at(1), 'Kadıköy');
    await tester.pumpAndSettle();
    // Leaving the name field with one word shows the hint.
    expect(find.text(surnameError), findsOneWidget);

    // Button is tappable, but tapping keeps us on step 1.
    final button = find.byType(RallyButton);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('1/4'), findsOneWidget);
    expect(find.text(surnameError), findsOneWidget);

    // Adding the surname clears the error and lets the user continue.
    await tester.enterText(fields.at(0), 'Leyla Garayli');
    await tester.pump();
    expect(find.text(surnameError), findsNothing);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('2/4'), findsOneWidget);
  });
}

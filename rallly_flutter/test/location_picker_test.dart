import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallly/data/tr_locations.dart';
import 'package:rallly/l10n/app_localizations.dart';
import 'package:rallly/main.dart' show CourtThemeProvider;
import 'package:rallly/theme/app_theme.dart';
import 'package:rallly/widgets/location_picker.dart';

import 'location_picker_helpers.dart';

Widget _app(Widget child) => CourtThemeProvider(
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
        home: Scaffold(body: child),
      ),
    );

void main() {
  group('trLocations data', () {
    test('has 81 provinces and 973 districts', () {
      expect(trLocations.length, 81);
      expect(trLocations.values.fold<int>(0, (n, l) => n + l.length), 973);
    });

    test('metropolitan district counts', () {
      expect(trLocations['İstanbul'], hasLength(39));
      expect(trLocations['Ankara'], hasLength(25));
      expect(trLocations['İzmir'], hasLength(30));
      expect(trLocations['İstanbul'], containsAll(['Pendik', 'Kadıköy', 'Şişli']));
    });

    test('uses Turkish alphabetical order', () {
      final ist = trLocations['İstanbul']!;
      expect(ist.first, 'Adalar');
      expect(ist.last, 'Zeytinburnu');
      // Ç after C, Ş after S, Ü after U.
      expect(ist.indexOf('Büyükçekmece') < ist.indexOf('Çatalca'), isTrue);
      expect(ist.indexOf('Sultangazi') < ist.indexOf('Şile'), isTrue);
      expect(ist.indexOf('Tuzla') < ist.indexOf('Ümraniye'), isTrue);
      final provinces = trLocations.keys.toList();
      expect(provinces.indexOf('Iğdır') < provinces.indexOf('İstanbul'), isTrue);
    });
  });

  group('parseTrLocation', () {
    test('parses "<ilçe>, <il>"', () {
      final p = parseTrLocation('Pendik, İstanbul');
      expect(p?.il, 'İstanbul');
      expect(p?.ilce, 'Pendik');
    });

    test('ignores case and Turkish diacritics, returns canonical names', () {
      final p = parseTrLocation('  kadikoy ,ISTANBUL ');
      expect(p?.il, 'İstanbul');
      expect(p?.ilce, 'Kadıköy');
    });

    test('legacy free text, unknown pairs and empty → null', () {
      expect(parseTrLocation('Kurtköy'), isNull);
      expect(parseTrLocation('Kurtkoy, Istanbul'), isNull);
      expect(parseTrLocation('Pendik, Ankara'), isNull);
      expect(parseTrLocation('Pendik, İstanbul, Türkiye'), isNull);
      expect(parseTrLocation(''), isNull);
      expect(parseTrLocation(null), isNull);
    });
  });

  group('LocationPicker', () {
    testWidgets('picking il + ilçe produces the stored string',
        (tester) async {
      String? value;
      await tester.pumpWidget(_app(LocationPicker(
          initialValue: 'Çankaya, Ankara', onChanged: (v) => value = v)));
      expect(find.text('Çankaya'), findsOneWidget);

      // Changing il clears ilçe.
      await tester.tap(openField('İl'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'istanbul');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'İstanbul'));
      await tester.pumpAndSettle();
      expect(value, isNull);
      expect(find.text('Çankaya'), findsNothing);

      // Search ignores Turkish case: "kurt" finds nothing in İstanbul, "pendik" does.
      await tester.tap(openField('İlçe'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'kurt');
      await tester.pumpAndSettle();
      expect(find.text('Sonuç bulunamadı'), findsOneWidget);
      expect(find.text('Mahalle değil, ilçe seçin (örn. Kurtköy → Pendik)'),
          findsOneWidget);
      await tester.enterText(find.byType(TextField), 'PENDİK');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Pendik'));
      await tester.pumpAndSettle();

      expect(value, 'Pendik, İstanbul');
      expect(find.text('Pendik'), findsOneWidget);
    });

    testWidgets('legacy value starts on İstanbul with no ilçe', (tester) async {
      await tester.pumpWidget(
          _app(LocationPicker(initialValue: 'Kurtköy', onChanged: (_) {})));
      expect(find.text('İstanbul'), findsOneWidget);
      expect(find.text('Kurtköy'), findsNothing);
      final empty = tester
          .widgetList<InputDecorator>(find.byType(InputDecorator))
          .map((d) => d.isEmpty);
      expect(empty, [false, true]);
    });

    testWidgets('helper picks il then ilçe', (tester) async {
      String? value;
      await tester.pumpWidget(_app(LocationPicker(onChanged: (v) => value = v)));
      await pickLocation(tester, il: 'İzmir', ilce: 'Karşıyaka');
      expect(value, 'Karşıyaka, İzmir');
    });
  });
}

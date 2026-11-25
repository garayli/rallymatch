import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drives LocationPicker (Turkish UI): optionally picks [il], then searches
/// for and picks [ilce] in the district sheet.
Future<void> pickLocation(WidgetTester tester,
    {String? il, required String ilce}) async {
  if (il != null) await _pick(tester, 'İl', il);
  await _pick(tester, 'İlçe', ilce);
}

/// The tappable LocationPicker field labelled [label] ('İl' / 'İlçe').
Finder openField(String label) => find
    .ancestor(of: find.text(label), matching: find.byType(InkWell))
    .first;

Future<void> _pick(WidgetTester tester, String field, String option) async {
  await tester.tap(openField(field));
  await tester.pumpAndSettle();
  await tester.enterText(
      find.descendant(
          of: find.byType(BottomSheet), matching: find.byType(TextField)),
      option);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, option));
  await tester.pumpAndSettle();
}

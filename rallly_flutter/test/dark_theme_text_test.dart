import 'package:flutter_test/flutter_test.dart';
import 'package:rallly/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Regression: in dark mode the TextField input text (bodyLarge) inherited the
  // light theme's near-black colour and was invisible on the dark surface.
  test('dark theme body text is light, light theme body text is dark', () {
    final dark = RallyTheme.dark.textTheme.bodyLarge!.color!;
    final light = RallyTheme.light.textTheme.bodyLarge!.color!;

    expect(dark, RallyColors.darkText);
    expect(light, RallyColors.textPrimary);
    expect(dark.computeLuminance(), greaterThan(0.5));
    expect(light.computeLuminance(), lessThan(0.5));
  });
}

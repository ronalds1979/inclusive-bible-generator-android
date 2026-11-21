import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/main.dart';
import 'package:app/services/color_accessibility.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('ColorAccessibility unit tests', () {
    test('worstCaseCvdContrast detects red-green contrast collapse under CVD', () {
      final result = ColorAccessibility.worstCaseCvdContrast(
        textColor: const Color(0xFFD32F2F),
        backgroundColor: const Color(0xFF2E7D32),
      );
      expect(ColorAccessibility.cvdModes, contains(result.worstMode));
      expect(result.minRatio, lessThan(2.0));
    });

    test('suggestSafestTextColor picks highest minimum-contrast color across CVD modes', () {
      const candidates = [
        MapEntry(Colors.white, 'color_white'),
        MapEntry(Color(0xFFFFAB91), 'color_coral'),
        MapEntry(Colors.black, 'color_black'),
      ];
      final onDark = ColorAccessibility.suggestSafestTextColor(
        candidates: candidates,
        backgroundColor: const Color(0xFF101828),
      );
      expect(onDark.entry.key, equals(Colors.white));
      expect(onDark.guaranteedRatio, greaterThan(10.0));

      final onLight = ColorAccessibility.suggestSafestTextColor(
        candidates: candidates,
        backgroundColor: const Color(0xFFF5F5F0),
      );
      expect(onLight.entry.key, equals(Colors.black));
      expect(onLight.guaranteedRatio, greaterThan(10.0));
    });

    test('describeColorName produces clear localized names across en, pt-BR, and es', () {
      expect(ColorAccessibility.describeColorName(Colors.white, 'en'), equals('White'));
      expect(ColorAccessibility.describeColorName(Colors.black, 'pt-BR'), equals('Preto'));
      expect(ColorAccessibility.describeColorName(const Color(0xFF0D2B52), 'en'), contains('Blue'));
      expect(ColorAccessibility.describeColorName(const Color(0xFFFFD54F), 'es'), contains('Dorado'));
    });
  });

  testWidgets(
    'Color-blindness features: tone badge, named swatches, Suggest Safe Color, and CVD UI toggle',
    (WidgetTester tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      await tester.runAsync(() async {
        await tester.pumpWidget(const MyApp());
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      // 1. Toggle Color-Blind-Friendly Status Colors in Advanced Features
      await tester.tap(find.byTooltip('Advanced Features'));
      await tester.pumpAndSettle();
      expect(find.text('Color-Blind-Friendly Status Colors'), findsOneWidget);
      await tester.tap(find.text('Color-Blind-Friendly Status Colors'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // 2. Step 2: Background tone badge is visible
      await tester.tap(find.text('Background'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('background'),
        findsWidgets,
      );

      // 3. Step 3: Visible named color chips + Suggest Safe Color button
      await tester.tap(find.text('Style'));
      await tester.pumpAndSettle();

      final deepNavyChip = find.text('Deep Navy');
      await tester.ensureVisible(deepNavyChip);
      expect(deepNavyChip, findsOneWidget);
      expect(find.text('Warm Gold'), findsOneWidget);

      final suggestBtn = find.text('Suggest Safe Color');
      await tester.ensureVisible(suggestBtn);
      await tester.tap(suggestBtn);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Applied color-blind-safe text color:'),
        findsOneWidget,
      );
    },
  );
}

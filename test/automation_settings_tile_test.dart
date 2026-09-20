import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irblaster_controller/l10n/app_localizations.dart';
import 'package:irblaster_controller/widgets/settings/widgets/automation_settings_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget settings({Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
          body: SingleChildScrollView(child: AutomationSettingsTile())),
    );

void main() {
  testWidgets('automation is opt-in, persists, and can be disabled',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(settings());
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse);
    expect(find.textContaining('Any installed app'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(AutomationSettingsTile.preferenceKey), isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(settings());
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(prefs.getBool(AutomationSettingsTile.preferenceKey), isFalse);
  });

  testWidgets('translated warning fits a compact screen with large text',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(settings(locale: const Locale('de')));
    await tester.pumpAndSettle();
    expect(find.text('Automatisierungs-Broadcasts erlauben'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

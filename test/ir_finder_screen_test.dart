import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irblaster_controller/ir_finder/ir_finder_models.dart';
import 'package:irblaster_controller/ir_finder/irblaster_db.dart';
import 'package:irblaster_controller/l10n/app_localizations.dart';
import 'package:irblaster_controller/widgets/ir_finder_cooldown_control.dart';
import 'package:irblaster_controller/widgets/ir_finder_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    databaseFactory = databaseFactorySqflitePlugin;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.tekartik.sqflite'),
            (call) async {
      switch (call.method) {
        case 'getDatabasesPath':
          return '/tmp/ir-finder-layout-test';
        case 'databaseExists':
          return true;
        case 'openDatabase':
          return {'id': 1};
        case 'query':
          return <Map<String, Object?>>[];
        default:
          return null;
      }
    });
    await IrBlasterDb.instance.ensureInitialized();
  });
  tearDownAll(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
          const MethodChannel('com.tekartik.sqflite'), null));
  for (final locale in [
    const Locale('en'),
    const Locale('de'),
    const Locale('ar')
  ]) {
    testWidgets('guided Finder and live cooldown fit a compact screen: $locale',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const IrFinderScreen(),
      ));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<SegmentedButton<IrFinderMode>>(
                  find.byType(SegmentedButton<IrFinderMode>))
              .selected,
          {IrFinderMode.database});
      expect(tester.takeException(), isNull);
      tester
          .widget<NavigationBar>(find.byType(NavigationBar))
          .onDestinationSelected!(1);
      await tester.pumpAndSettle();
      final control = find.byType(IrFinderCooldownControl);
      await tester.ensureVisible(control);
      await tester.pumpAndSettle();
      tester.widget<IrFinderCooldownControl>(control).onChanged!(750);
      await tester.pumpAndSettle();
      expect(tester.widget<IrFinderCooldownControl>(control).delayMs, 750);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}

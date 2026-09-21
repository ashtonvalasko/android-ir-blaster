import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irblaster_controller/l10n/app_localizations.dart';
import 'package:irblaster_controller/widgets/ir_finder_cooldown_control.dart';

void main() {
  testWidgets(
      'cooldown displays restored delays and remains editable on a small screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var delay = 5000;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: StatefulBuilder(
            builder: (context, setState) => IrFinderCooldownControl(
                delayMs: delay,
                onChanged: (value) => setState(() => delay = value))),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(find.byType(Slider)).value, 5000);
    expect(find.text('Cooldown (ms): 5000'), findsOneWidget);
    tester.widget<Slider>(find.byType(Slider)).onChanged!(750);
    await tester.pumpAndSettle();
    expect(find.text('Cooldown (ms): 750'), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 750);
    expect(tester.takeException(), isNull);
  });
}

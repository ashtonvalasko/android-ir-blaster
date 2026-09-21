import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irblaster_controller/l10n/app_localizations.dart';
import 'package:irblaster_controller/models/macro_step.dart';
import 'package:irblaster_controller/models/timed_macro.dart';
import 'package:irblaster_controller/utils/remote.dart';
import 'package:irblaster_controller/widgets/macro_editor_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late TimedMacro? saved;
  setUp(() {
    saved = null;
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('org.nslabs/irtransmitter'), (_) async => true);
  });

  Future<void> open(WidgetTester tester, {TimedMacro? macro}) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
          builder: (context) => Scaffold(
                  body: TextButton(
                onPressed: () async {
                  saved = await Navigator.of(context)
                      .push<TimedMacro>(MaterialPageRoute(
                    builder: (_) => MacroEditorScreen(
                        macro: macro, remote: Remote(name: 'TV', buttons: [])),
                  ));
                },
                child: const Text('Open'),
              ))),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'cancel confirms dirty changes and continue editing preserves input',
      (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'Bedtime');
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Continue editing'));
    await tester.pumpAndSettle();
    expect(find.text('Bedtime'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    expect(saved, isNull);
  });

  testWidgets('clean cancel leaves without a dialog', (tester) async {
    await open(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets(
      'saving edited macro preserves ID and steps without discard prompt',
      (tester) async {
    const macro =
        TimedMacro(id: 'same-id', name: 'Before', remoteName: 'TV', steps: [
      MacroStep(id: 'manual', type: MacroStepType.manualContinue),
      MacroStep(id: 'delay', type: MacroStepType.delay, delayMs: 250),
    ]);
    await open(tester, macro: macro);
    await tester.enterText(find.byType(TextField), 'After');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(saved!.id, macro.id);
    expect(saved!.name, 'After');
    expect(saved!.steps, macro.steps);
  });
}

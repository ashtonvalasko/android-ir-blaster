import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irblaster_controller/l10n/app_localizations.dart';
import 'package:irblaster_controller/utils/remote.dart';
import 'package:irblaster_controller/widgets/ir_waveform_view.dart';
import 'package:irblaster_controller/widgets/remote_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  testWidgets('remote disposal does not update an unmounting widget',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('org.nslabs/irtransmitter'),
            (_) async => {'hasInternal': true});
    await tester
        .pumpWidget(app(RemoteView(remote: Remote(name: 'TV', buttons: []))));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('waveform owns its horizontal scroll position and disposes it',
      (tester) async {
    await tester.pumpWidget(app(const Scaffold(
        body: PrimaryScrollController.none(
      child: SizedBox(
          width: 320,
          child: IrWaveformPanel(
            pattern: [9000, 4500, 560, 560, 560],
            frequencyHz: 38000,
          )),
    ))));
    await tester.pumpAndSettle();
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        greaterThan(0));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}

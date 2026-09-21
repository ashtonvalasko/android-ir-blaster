import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irblaster_controller/l10n/app_localizations.dart';
import 'package:irblaster_controller/widgets/db_catalog_picker.dart';

Widget app(Widget child,
        {Locale locale = const Locale('en'), double scale = 1}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('search and scroll survive submit, dismiss and rebuild',
      (tester) async {
    var loads = 0;
    final picker = DbCatalogPicker(loadNames: () async {
      loads++;
      return ['TCL', for (var i = 0; i < 100; i++) 'SONY $i'];
    });
    await tester.pumpWidget(app(picker));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'sony');
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));
    await tester.pumpAndSettle();
    final controller = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    final offset = controller.offset;
    await tester.showKeyboard(find.byType(TextField));
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(picker, scale: 1.1));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'sony');
    expect(controller.offset, offset);
    expect(find.text('TCL'), findsNothing);
    expect(loads, 1);
    await tester.showKeyboard(find.byType(TextField));
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'sony');
    expect(loads, 1);
  });

  testWidgets(
      'typing while loading uses the latest query and supports clearing',
      (tester) async {
    final names = Completer<List<String>>();
    await tester
        .pumpWidget(app(DbCatalogPicker(loadNames: () => names.future)));
    await tester.enterText(find.byType(TextField), 'sony');
    await tester.enterText(find.byType(TextField), 'tcl');
    names.complete(['SONY', 'TCL']);
    await tester.pumpAndSettle();
    expect(find.text('TCL'), findsOneWidget);
    expect(find.text('SONY'), findsNothing);
    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('SONY'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();
    expect(find.text('No results found.'), findsOneWidget);
  });

  testWidgets(
      'load failure is retryable and late completion after close is safe',
      (tester) async {
    var attempts = 0;
    final names = Completer<List<String>>();
    await tester.pumpWidget(app(DbCatalogPicker(loadNames: () {
      if (attempts++ == 0) return Future.error(StateError('Unavailable'));
      return names.future;
    })));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    names.complete(['SONY']);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final locale in [
    const Locale('en'),
    const Locale('ar'),
    const Locale('de')
  ]) {
    testWidgets('compact screen and large text: ${locale.languageCode}',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(
        DbCatalogPicker(brand: 'SONY', loadNames: () async => ['RM - ED013']),
        locale: locale,
        scale: 2,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

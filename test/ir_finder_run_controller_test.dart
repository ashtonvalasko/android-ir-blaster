import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:irblaster_controller/ir_finder/ir_finder_models.dart';
import 'package:irblaster_controller/ir_finder/ir_finder_run_controller.dart';
import 'package:irblaster_controller/ir_finder/ir_finder_search.dart';
import 'package:shared_preferences/shared_preferences.dart';

const candidate = IrFinderCandidate(
  protocolId: 'nec',
  displayProtocol: 'NEC',
  displayCode: '00FF01FE',
  params: <String, dynamic>{},
  source: IrFinderSource.bruteforce,
);

void configure(IrFinderRunController controller, int delay) =>
    controller.configure(
      mode: IrFinderMode.bruteforce,
      protocolId: 'nec',
      delayMs: delay,
      maxKeysToTest: 100,
      bruteMaxAttempts: 100,
      bruteAllCombinations: false,
      bruteStrategy: IrFinderSearchStrategy.smart,
      prefixRaw: '',
      kaseikyoVendor: '2002',
      onlySelectedProtocol: true,
      quickWinsFirst: true,
      brand: null,
      model: null,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('cooldown is a full gap after send completion', (tester) async {
    var sends = 0;
    final sent = Completer<void>();
    final controller = IrFinderRunController(
      fetchCandidate: (_) async => candidate,
      sendCandidate: (_) {
        sends++;
        return sends == 1 ? sent.future : Future.value();
      },
    );
    await controller.start();
    await tester.pump(const Duration(milliseconds: 500));
    expect(sends, 1);
    await tester.pump(const Duration(milliseconds: 300));
    sent.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 499));
    expect(sends, 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(sends, 2);
    controller.dispose();
  });

  testWidgets('changing cooldown during a run reschedules the next attempt',
      (tester) async {
    var sends = 0;
    final controller = IrFinderRunController(
      fetchCandidate: (_) async => candidate,
      sendCandidate: (_) async {
        sends++;
      },
    );
    await controller.start();
    await tester.pump(const Duration(milliseconds: 500));
    configure(controller, 1500);
    await tester.pump(const Duration(milliseconds: 1499));
    expect(sends, 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(sends, 2);
    expect(controller.snapshot().delayMs, 1500);
    controller.dispose();
  });

  for (final action in ['pause', 'stop', 'dispose']) {
    testWidgets('$action cancels transmission after an outstanding lookup',
        (tester) async {
      var sends = 0;
      final lookup = Completer<IrFinderCandidate?>();
      final controller = IrFinderRunController(
        fetchCandidate: (_) => lookup.future,
        sendCandidate: (_) async {
          sends++;
        },
      );
      await controller.start();
      await tester.pump(const Duration(milliseconds: 500));
      expect(controller.busy, isTrue);
      if (action == 'pause') controller.pause();
      if (action == 'stop') await controller.stop();
      if (action == 'dispose') controller.dispose();
      lookup.complete(candidate);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(sends, 0);
      expect(controller.attempted, 0);
      if (action != 'dispose') controller.dispose();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Save hit freezes the completed candidate and scan',
      (tester) async {
    var sends = 0;
    final controller = IrFinderRunController(
      fetchCandidate: (_) async => candidate,
      sendCandidate: (_) async {
        sends++;
      },
    );
    await controller.start();
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.pauseForHit(), same(candidate));
    expect(controller.paused, isTrue);
    await tester.pump(const Duration(seconds: 5));
    expect(sends, 1);
    expect(controller.attempted, 1);
    controller.dispose();
  });

  testWidgets(
      'saving while sending is rejected; updated delay applies afterward',
      (tester) async {
    final sent = Completer<void>();
    var sends = 0;
    final controller = IrFinderRunController(
      fetchCandidate: (_) async => candidate,
      sendCandidate: (_) {
        sends++;
        return sends == 1 ? sent.future : Future.value();
      },
    );
    await controller.start();
    await tester.pump(const Duration(milliseconds: 500));
    configure(controller, 1000);
    expect(controller.pauseForHit(), isNull);
    sent.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 999));
    expect(sends, 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(sends, 2);
    controller.dispose();
  });

  testWidgets('lookup failure pauses instead of throwing from a timer',
      (tester) async {
    final controller = IrFinderRunController(
      fetchCandidate: (_) async => throw StateError('Lookup failed'),
      sendCandidate: (_) async => fail('Must not transmit'),
    );
    await controller.start();
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.paused, isTrue);
    expect(controller.lastError, isStateError);
    expect(controller.pauseForHit(), isNull);
    controller.dispose();
  });

  testWidgets('old send completion cannot advance a restarted scan',
      (tester) async {
    final sent = Completer<void>();
    final controller = IrFinderRunController(
      fetchCandidate: (_) async => candidate,
      sendCandidate: (_) => sent.future,
    );
    await controller.start();
    await tester.pump(const Duration(milliseconds: 500));
    await controller.stop();
    await controller.start();
    sent.complete();
    await tester.pump();
    expect(controller.attempted, 0);
    expect(controller.lastCandidate, isNull);
    controller.dispose();
  });
}

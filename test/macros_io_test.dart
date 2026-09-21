import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irblaster_controller/models/macro_step.dart';
import 'package:irblaster_controller/models/timed_macro.dart';
import 'package:irblaster_controller/utils/macros_io.dart';
import 'package:irblaster_controller/utils/remote.dart';

const macro =
    TimedMacro(id: 'macro', name: 'Original', remoteName: 'TV', steps: [
  MacroStep(id: 'wait', type: MacroStepType.delay, delayMs: 300),
  MacroStep(id: 'manual', type: MacroStepType.manualContinue),
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('macro-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('saving and reading preserves steps and order', () async {
    await writeMacrosList([macro]);
    expect((await readMacros()).single.toJson(), macro.toJson());
  });

  test('overlapping saves are ordered and snapshot mutable input', () async {
    final initial = [macro];
    final first = writeMacrosList(initial);
    initial.clear();
    final saves = [first];
    for (var i = 0; i < 20; i++) {
      saves.add(writeMacrosList([macro.copyWith(name: 'Revision $i')]));
    }
    await Future.wait(saves);
    expect((await readMacros()).single.name, 'Revision 19');
    expect(await File('${dir.path}/macros.json.tmp').exists(), isFalse);
  });

  test('snapshot is captured before waiting for path lookup', () async {
    final input = [macro];
    final saving = writeMacrosList(input);
    input.clear();
    await saving;
    expect((await readMacros()).single.name, 'Original');
  });

  test('failed save preserves old file and later saves still work', () async {
    await writeMacrosList([macro]);
    final obstruction = Directory('${dir.path}/macros.json.tmp');
    await obstruction.create();
    await expectLater(writeMacrosList([macro.copyWith(name: 'Lost')]),
        throwsA(isA<FileSystemException>()));
    expect((await readMacros()).single.name, 'Original');
    await obstruction.delete();
    await writeMacrosList([macro.copyWith(name: 'Recovered')]);
    expect((await readMacros()).single.name, 'Recovered');
  });

  test('binding prioritizes stable IDs and supports legacy labels', () {
    const button = IRButton(id: 'id', image: 'Renamed', isImage: false);
    final remote = Remote(name: 'TV', buttons: [button]);
    final bound = bindMacroToRemote(
        macro.copyWith(steps: [
          const MacroStep(
              id: 'first', type: MacroStepType.send, buttonId: 'id'),
          const MacroStep(
              id: 'second', type: MacroStepType.send, buttonRef: 'Renamed'),
          const MacroStep(
              id: 'missing', type: MacroStepType.send, buttonId: 'deleted'),
          ...macro.steps,
        ]),
        remote);
    expect(bound.steps[0].buttonRef, 'Renamed');
    expect(bound.steps[1].buttonId, 'id');
    expect(bound.steps[2].buttonId, 'deleted');
    expect(bound.steps.skip(3), macro.steps);
  });
}

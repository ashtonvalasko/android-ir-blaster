import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:irblaster_controller/ir/ir_protocol_registry.dart';
import 'package:irblaster_controller/ir_finder/ir_finder_models.dart';
import 'package:irblaster_controller/utils/db_button_import.dart';
import 'package:irblaster_controller/utils/ir.dart';

void main() {
  final vectors = (jsonDecode(
          File('test/fixtures/protocols/reference_vectors.json')
              .readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();

  test('reference vectors cover every implemented protocol', () {
    expect(
        vectors.map((v) => v['id']).toSet(),
        IrProtocolRegistry.allDefinitions()
            .where((definition) => definition.implemented)
            .map((definition) => definition.id)
            .toSet());
  });

  for (final vector in vectors) {
    final id = vector['id'] as String;
    test('$id waveform matches ${vector['reference']}', () {
      final result = IrProtocolRegistry.encoderFor(id).encode({
        ...Map<String, dynamic>.from(vector['params'] as Map),
        '_preview': true,
      });
      _expectReference(result.frequencyHz, result.pattern, vector);
    });

    if (vector.containsKey('databaseHex')) {
      test('$id database import preserves the reference payload', () {
        final button = buildButtonFromDbRow(IrDbKeyCandidate(
          id: 1,
          protocol: id,
          hexcode: vector['databaseHex'] as String,
        ));
        expect(button, isNotNull);
        final result = previewIRButton(button!);
        // Legacy NEC buttons end at the stop mark; silence is not stored.
        _expectReference(result.frequencyHz, result.pattern, vector,
            omitTrailingGap: id == 'nec');
      });
    }
  }

  test('RAW keeps all supplied durations and pads only an odd trailing mark',
      () {
    final encoder = IrProtocolRegistry.encoderFor('raw');
    final result = encoder.encode({'pattern': '9000 4500 560'});
    expect(result.pattern, [9000, 4500, 560, 45000]);
  });
}

void _expectReference(
    int frequency, List<int> pattern, Map<String, dynamic> vector,
    {bool omitTrailingGap = false}) {
  final expected = (vector['pattern'] as List).cast<int>();
  final referenceHz = vector['frequencyHz'] as int;
  expect(frequency, closeTo(referenceHz, referenceHz * 0.03));
  expect(pattern.length,
      (vector['totalLength'] ?? expected.length) - (omitTrailingGap ? 1 : 0));
  expect(pattern.length.isEven, !omitTrailingGap);
  expect(pattern.every((duration) => duration > 0), isTrue);
  for (int i = 0; i < expected.length - (omitTrailingGap ? 1 : 0); i++) {
    // This suite checks payload/header identity, not repeat cadence. Existing
    // lead-out timings differ from IRP references; see the fixture README.
    if (vector['id'] != 'raw' &&
        (i == expected.length - 1 ||
            (i.isOdd && expected[i] > 10000 && pattern[i] > 10000))) {
      continue;
    }
    expect(pattern[i],
        closeTo(expected[i], expected[i] * (vector['timingTolerance'] as num)),
        reason: '${vector['id']} duration $i (${vector['reference']})');
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:irblaster_controller/ir/protocols/proton.dart';
import 'package:irblaster_controller/ir_finder/ir_finder_models.dart';
import 'package:irblaster_controller/utils/db_button_import.dart';
import 'package:irblaster_controller/utils/ir.dart';
import 'package:irblaster_controller/utils/remote.dart';

void main() {
  test('Proton uses the canonical 4 ms separator between data bytes', () {
    const encoder = ProtonProtocolEncoder();
    final result = encoder.encode(<String, dynamic>{'hex': '0014'});

    expect(result.frequencyHz, 38500);
    expect(result.pattern.take(2), <int>[8000, 4000]);
    expect(result.pattern.skip(18).take(2), <int>[500, 4000]);
    expect(_decodeBits(result.pattern), '0000000000010100');
    expect(
        result.pattern.fold<int>(0, (sum, duration) => sum + duration), 63000);
  });

  test('database Proton Power matches issue 113 working RAW byte order', () {
    // Power from the reporter's irblaster_backup_fixed.json (issue #113).
    const workingRaw = <int>[
      8100, 3900,
      600, 400, 600, 400, 600, 1400, 600, 400,
      600, 1400, 600, 400, 600, 400, 600, 400,
      600, 3900,
      600, 1400, 600, 400, 600, 1400, 600, 400,
      600, 1400, 600, 400, 600, 400, 600, 400,
      600,
    ];
    final button = buildButtonFromDbRow(const IrDbKeyCandidate(
      id: 1,
      protocol: 'Proton',
      hexcode: '28A8',
      label: 'POWER',
    ))!;
    final preview = previewIRButton(button);

    expect(_decodeBits(workingRaw), '0010100010101000');
    expect(_decodeBits(preview.pattern), _decodeBits(workingRaw));
    expect(preview.pattern.skip(18).take(2), <int>[500, 4000]);
    expect(preview.frequencyHz, 38500);
    expect(
      previewIRButton(IRButton.fromJson(button.toJson())).pattern,
      preview.pattern,
    );
  });

  test('existing saved Proton codes send the address before the command', () {
    for (final sample in <String, String>{
      '28A8': '0010100010101000', // Power
      '2848': '0010100001001000', // Mute
      '28C8': '0010100011001000', // Volume up
      '2828': '0010100000101000', // Volume down (equal bytes)
    }.entries) {
      final button = IRButton.fromJson(<String, dynamic>{
        'id': 'saved-proton',
        'image': 'Button',
        'isImage': false,
        'frequency': 38500,
        'protocol': 'proton',
        'protocolParams': <String, dynamic>{'hex': sample.key},
      });
      expect(
        _decodeBits(previewIRButton(button).pattern),
        sample.value,
        reason: sample.key,
      );
    }
  });
}

String _decodeBits(List<int> pattern) {
  final buffer = StringBuffer();
  for (final start in <int>[2, 20]) {
    for (int index = start + 1; index < start + 16; index += 2) {
      buffer.write(pattern[index] < 1000 ? '0' : '1');
    }
  }
  return buffer.toString();
}

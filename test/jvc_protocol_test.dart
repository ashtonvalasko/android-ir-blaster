import 'package:flutter_test/flutter_test.dart';
import 'package:irblaster_controller/ir_finder/ir_finder_models.dart';
import 'package:irblaster_controller/utils/db_button_import.dart';
import 'package:irblaster_controller/utils/ir.dart';

void main() {
  test('JVC database TV Power preserves the captured wire-order bits', () {
    // Independent capture: probonopd/lirc-remotes, jvc/RM-S9.xml,
    // KEY_POWER C0E8, decoded JVC D=3,F=23 (both fields LSB-first).
    final button = buildButtonFromDbRow(const IrDbKeyCandidate(
      id: 1,
      protocol: 'JVC',
      hexcode: 'C0E8',
    ))!;
    final signal = previewIRButton(button);
    expect(signal.frequencyHz, 38000);
    expect(signal.pattern.take(2), <int>[8400, 4200]);
    expect(signal.pattern.length, 36);
    final bits = <int>[
      for (int i = 3; i < 34; i += 2) signal.pattern[i] == 1575 ? 1 : 0,
    ].join();
    expect(bits, '1100000011101000');
    expect(signal.pattern.skip(34), <int>[525, 21000]);
  });
}

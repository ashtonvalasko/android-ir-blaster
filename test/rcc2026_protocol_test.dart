import 'package:flutter_test/flutter_test.dart';
import 'package:irblaster_controller/ir_finder/ir_finder_models.dart';
import 'package:irblaster_controller/utils/db_button_import.dart';
import 'package:irblaster_controller/utils/ir.dart';

void main() {
  test('RCC2026 removes trailing padding, not leading address bits', () {
    // NEC42 layout: D:13,~D:13,F:8,~F:8, each LSB-first.
    // Bundled code 38863BD42BC represents D=284,F=10, then two padding bits.
    final button = buildButtonFromDbRow(const IrDbKeyCandidate(
      id: 1,
      protocol: 'RCC2026',
      hexcode: '38863BD42BC',
    ))!;
    final result = previewIRButton(button);
    expect(result.pattern.length, 92);
    final bits = [
      for (int i = 3; i < 86; i += 2) result.pattern[i] == 1650 ? '1' : '0',
    ].join();
    int field(int start, int end) =>
        int.parse(bits.substring(start, end).split('').reversed.join(), radix: 2);
    expect(field(0, 13), 284);
    expect(field(13, 26), 284 ^ 0x1FFF);
    expect(field(26, 34), 10);
    expect(field(34, 42), 10 ^ 0xFF);
  });
}

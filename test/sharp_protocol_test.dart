import 'package:flutter_test/flutter_test.dart';
import 'package:irblaster_controller/ir/protocols/sharp.dart';
import 'package:irblaster_controller/ir_finder/ir_finder_models.dart';
import 'package:irblaster_controller/utils/db_button_import.dart';
import 'package:irblaster_controller/utils/ir.dart';

void main() {
  test('Sharp database TV Power decodes to device 1, command 22', () {
    // Independent capture: probonopd/lirc-remotes, sharp/1781.xml KEY_POWER.
    // IRP: D:5,F:8,1:2. Database frame is left-aligned with one padding bit.
    final button = buildButtonFromDbRow(const IrDbKeyCandidate(
      id: 1,
      protocol: 'Sharp',
      hexcode: '8344',
    ))!;
    final result = previewIRButton(button);
    expect(_decodeFrame(result.pattern, 0), '100000110100010');
    expect(_decodeFrame(result.pattern, 1), '100001001011101');
    expect(_decodeFrame(result.pattern, 2), '100000110100010');
  });

  test('Sharp emits the required normal, inverted, normal frame sequence', () {
    const encoder = SharpProtocolEncoder();
    final result = encoder.encode(<String, dynamic>{'hex': '81E4'});

    expect(result.frequencyHz, 38000);
    expect(result.pattern.length, 96);
    expect(_decodeFrame(result.pattern, 0), '100000011110010');
    expect(_decodeFrame(result.pattern, 1), '100001100001101');
    expect(_decodeFrame(result.pattern, 2), '100000011110010');
  });
}

String _decodeFrame(List<int> pattern, int frameIndex) {
  final frame = pattern.skip(frameIndex * 32).take(32).toList(growable: false);
  final buffer = StringBuffer();
  for (int index = 1; index < 30; index += 2) {
    buffer.write(frame[index] == 860 ? '0' : '1');
  }
  expect(frame.takeLast(2), <int>[280, 43560]);
  return buffer.toString();
}

extension<T> on Iterable<T> {
  Iterable<T> takeLast(int count) => skip(length - count);
}

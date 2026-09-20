import 'package:flutter_test/flutter_test.dart';
import 'package:irblaster_controller/ir/protocols/xsat.dart';

void main() {
  test('XSAT retains the field separator and command stop marks', () {
    // LIRC xsat/XSAT_CDTV410.xml KEY_MUTE: decoded D=34,F=11.
    // Its capture has a separate mark/space separator and a final stop mark.
    const encoder = XsatProtocolEncoder();
    final result = encoder.encode({'address': '22', 'command': '0B'});
    expect(result.pattern.length, 38);
    expect(result.pattern.take(2), [8000, 4000]);
    expect(result.pattern.sublist(18, 20), [526, 4000]);
    String bits(int offset) => [
      for (int i = offset + 1; i < offset + 16; i += 2)
        result.pattern[i] == 1474 ? 1 : 0,
    ].join();
    expect(bits(2), '01000100');
    expect(bits(20), '11010000');
    expect(result.pattern[36], 526);
    expect(result.pattern.last, greaterThan(0));
    expect(result.pattern.reduce((a, b) => a + b), 60000);
  });

  test('XSAT commands differing only in bit 7 have different waveforms', () {
    const encoder = XsatProtocolEncoder();
    final zero = encoder.encode({'address': '22', 'command': '00'});
    final high = encoder.encode({'address': '22', 'command': '80'});
    expect(high.pattern, isNot(zero.pattern));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:irblaster_controller/ir/protocols/thomson7.dart';

void main() {
  test('Thomson keeps address and all seven command bits in wire order', () {
    // LIRC thomson/RCT100.xml: 0300 and 0310 differ at command bit 4.
    // Wire layout: D:4, T:1, F:7; packed input already contains wire bits.
    const encoder = Thomson7ProtocolEncoder();
    final zero = encoder.encode({'code': 0x300, '_preview': true});
    final command = encoder.encode({'code': 0x310, '_preview': true});
    String bits(List<int> pattern) => [
      for (int i = 1; i < 24; i += 2) pattern[i] == 4600 ? 1 : 0,
    ].join();
    final zeroBits = bits(zero.pattern);
    final commandBits = bits(command.pattern);
    expect(zeroBits.substring(0, 4), '0011');
    expect(commandBits.substring(0, 4), '0011');
    expect(zeroBits.substring(5), '0000000');
    expect(commandBits.substring(5), '0010000');
    expect(commandBits[4], zeroBits[4]);
    expect(command.pattern.length, 52);
    expect(command.pattern.take(26), command.pattern.skip(26));
    expect(command.pattern.take(26).reduce((a, b) => a + b), 80000);
  });
}

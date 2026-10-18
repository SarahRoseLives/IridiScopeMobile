import 'package:flutter_test/flutter_test.dart';
import 'package:iridiscope_mobile/models/iridium_message.dart';

void main() {
  test('parses an IRA message from native JSON', () {
    final msg = IridiumMessage.fromJson({
      'seq': 7,
      'type': 'IRA',
      'pretty': 'Ring alert',
      'freq': 1621250000.0,
      'ts_ns': 1700000000000000000,
      'confidence': 99,
      'uplink': 0,
      'symbols': 312,
      'error': false,
      'ira': {
        'sat': 12,
        'beam': 3,
        'lat': 51.5,
        'lon': -0.1,
        'alt_km': 780,
      },
    });

    expect(msg.seq, 7);
    expect(msg.type, 'IRA');
    expect(msg.frequencyLabel, '1621.2500 MHz');
    expect(msg.ira!['sat'], 12);
    expect(msg.subtitle, contains('SAT 12'));
  });
}

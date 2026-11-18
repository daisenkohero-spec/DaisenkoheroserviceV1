import 'package:flutter_test/flutter_test.dart';
import 'package:project_techniqian/core/geo/geohash.dart';

void main() {
  test('matches known geohashes', () {
    // u4pruydqqvj is the reference example from the geohash spec.
    expect(encodeGeohash(57.64911, 10.40744, precision: 11), 'u4pruydqqvj');
    expect(encodeGeohash(13.7563, 100.5018, precision: 5), 'w4rqq');
  });
}

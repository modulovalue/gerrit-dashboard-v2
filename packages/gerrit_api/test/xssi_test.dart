import 'package:gerrit_api/gerrit_api.dart';
import 'package:test/test.dart';

void main() {
  group('stripXssiPrefix', () {
    test("strips the standard )]}' prefix", () {
      expect(stripXssiPrefix(")]}'\n[1,2,3]"), '[1,2,3]');
    });

    test('handles leading whitespace before prefix', () {
      expect(stripXssiPrefix("  )]}'\n{\"a\":1}"), '{"a":1}');
    });

    test('returns input unchanged when prefix is missing', () {
      expect(stripXssiPrefix('[1,2,3]'), '[1,2,3]');
    });

    test('handles empty input', () {
      expect(stripXssiPrefix(''), '');
    });
  });
}

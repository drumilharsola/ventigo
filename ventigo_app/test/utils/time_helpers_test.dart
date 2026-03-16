import 'package:flutter_test/flutter_test.dart';
import 'package:ventigo_app/utils/time_helpers.dart';

void main() {
  group('timeAgo', () {
    test('returns "just now" for recent timestamps', () {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      expect(timeAgo('$now'), equals('just now'));
    });

    test('returns minutes ago', () {
      final fiveMinAgo = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 300;
      expect(timeAgo('$fiveMinAgo'), equals('5m ago'));
    });

    test('returns hours ago', () {
      final twoHoursAgo = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 7200;
      expect(timeAgo('$twoHoursAgo'), equals('2h ago'));
    });

    test('handles int input', () {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      expect(timeAgo(now), equals('just now'));
    });

    test('handles null-like input gracefully', () {
      // Will parse to 0, so many hours ago
      final result = timeAgo('invalid');
      expect(result, contains('h ago'));
    });
  });

  group('formatRemaining', () {
    test('formats 0 seconds', () {
      expect(formatRemaining(0), equals('00:00'));
    });

    test('formats 90 seconds', () {
      expect(formatRemaining(90), equals('01:30'));
    });

    test('formats 900 seconds (15 min)', () {
      expect(formatRemaining(900), equals('15:00'));
    });

    test('formats 59 seconds', () {
      expect(formatRemaining(59), equals('00:59'));
    });

    test('formats 61 seconds', () {
      expect(formatRemaining(61), equals('01:01'));
    });

    test('pads single digits', () {
      expect(formatRemaining(5), equals('00:05'));
      expect(formatRemaining(65), equals('01:05'));
    });
  });
}

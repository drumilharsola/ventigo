import 'package:flutter_test/flutter_test.dart';
import 'package:ventigo_app/screens/posts_screen.dart';

void main() {
  group('postTimeLeft', () {
    test('shows hours and minutes when > 1h', () {
      final expiry = DateTime.now().millisecondsSinceEpoch / 1000 + 3661;
      final result = postTimeLeft(expiry);
      expect(result, contains('h'));
      expect(result, contains('m left'));
    });

    test('shows only minutes when < 1h', () {
      final expiry = DateTime.now().millisecondsSinceEpoch / 1000 + 1800;
      final result = postTimeLeft(expiry);
      expect(result, contains('m left'));
      expect(result, isNot(contains('h')));
    });

    test('shows expiring soon when <= 0', () {
      final expiry = DateTime.now().millisecondsSinceEpoch / 1000 - 10;
      final result = postTimeLeft(expiry);
      expect(result, 'expiring soon');
    });

    test('shows expiring soon when exactly 0 seconds', () {
      final expiry = DateTime.now().millisecondsSinceEpoch / 1000;
      final result = postTimeLeft(expiry);
      expect(result, 'expiring soon');
    });

    test('handles very large values', () {
      final expiry = DateTime.now().millisecondsSinceEpoch / 1000 + 86400;
      final result = postTimeLeft(expiry);
      expect(result, contains('h'));
      expect(result, contains('left'));
    });
  });
}

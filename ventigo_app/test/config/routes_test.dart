import 'package:flutter_test/flutter_test.dart';
import 'package:ventigo_app/config/routes.dart';

void main() {
  group('Route path constants', () {
    test('kPathVerify', () => expect(kPathVerify, '/verify'));
    test('kPathOnboarding', () => expect(kPathOnboarding, '/onboarding'));
    test('kPathHome', () => expect(kPathHome, '/home'));
    test('kPathCommunity', () => expect(kPathCommunity, '/community'));
    test('kPathProfile', () => expect(kPathProfile, '/profile'));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:ventigo_app/utils/content_filter.dart';

void main() {
  group('ContentFilter.hasSocialMedia', () {
    test('detects @usernames', () {
      expect(ContentFilter.hasSocialMedia('follow @my_handle'), isTrue);
    });

    test('detects instagram keyword', () {
      expect(ContentFilter.hasSocialMedia('add me on instagram'), isTrue);
    });

    test('detects snapchat keyword', () {
      expect(ContentFilter.hasSocialMedia('my snap is xyz'), isTrue);
    });

    test('detects phone numbers', () {
      expect(ContentFilter.hasSocialMedia('call me 9876543210'), isTrue);
    });

    test('detects emails', () {
      expect(ContentFilter.hasSocialMedia('email me at test@example.com'), isTrue);
    });

    test('clean text passes', () {
      expect(ContentFilter.hasSocialMedia('I feel really low today'), isFalse);
    });

    test('detects discord', () {
      expect(ContentFilter.hasSocialMedia('join my discord'), isTrue);
    });

    test('detects telegram', () {
      expect(ContentFilter.hasSocialMedia('message me on telegram'), isTrue);
    });

    test('detects whatsapp', () {
      expect(ContentFilter.hasSocialMedia('whatsapp me'), isTrue);
    });
  });

  group('ContentFilter.hasBadWords', () {
    test('detects English profanity', () {
      expect(ContentFilter.hasBadWords('what the fuck'), isTrue);
    });

    test('detects Hindi profanity', () {
      expect(ContentFilter.hasBadWords('tu chutiya hai'), isTrue);
    });

    test('clean text passes', () {
      expect(ContentFilter.hasBadWords('I am feeling anxious'), isFalse);
    });

    test('case insensitive', () {
      expect(ContentFilter.hasBadWords('FUCK'), isTrue);
    });
  });

  group('ContentFilter.isViolation', () {
    test('true for social media', () {
      expect(ContentFilter.isViolation('my insta is cool'), isTrue);
    });

    test('true for bad words', () {
      expect(ContentFilter.isViolation('damn it'), isTrue);
    });

    test('false for clean text', () {
      expect(ContentFilter.isViolation('I need someone to talk to'), isFalse);
    });
  });

  group('ContentFilter.mask', () {
    test('replaces bad words with asterisks', () {
      final result = ContentFilter.mask('what the fuck');
      expect(result, contains('****'));
      expect(result, isNot(contains('fuck')));
    });

    test('preserves clean text', () {
      expect(ContentFilter.mask('good morning'), equals('good morning'));
    });
  });

  group('ContentFilter.validate', () {
    test('returns error for social media', () {
      final result = ContentFilter.validate('follow @me');
      expect(result, isNotNull);
      expect(result, contains('social media'));
    });

    test('returns error for bad words', () {
      final result = ContentFilter.validate('shit');
      expect(result, isNotNull);
      expect(result, contains('respectful'));
    });

    test('returns null for clean text', () {
      expect(ContentFilter.validate('I feel better now'), isNull);
    });
  });
}

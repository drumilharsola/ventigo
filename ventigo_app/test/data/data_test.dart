import 'package:flutter_test/flutter_test.dart';
import 'package:ventigo_app/data/quotes.dart';
import 'package:ventigo_app/data/fun_facts.dart';

void main() {
  group('dailyQuotes', () {
    test('has 45 entries', () {
      expect(dailyQuotes.length, 45);
    });

    test('all non-empty strings', () {
      for (final q in dailyQuotes) {
        expect(q.isNotEmpty, true);
      }
    });

    test('no duplicates', () {
      expect(dailyQuotes.toSet().length, dailyQuotes.length);
    });
  });

  group('quoteOfTheDay', () {
    test('returns a string from the list', () {
      final q = quoteOfTheDay();
      expect(dailyQuotes.contains(q), true);
    });

    test('is deterministic within same call', () {
      final a = quoteOfTheDay();
      final b = quoteOfTheDay();
      expect(a, b);
    });
  });

  group('kFunFacts', () {
    test('has 45 entries', () {
      expect(kFunFacts.length, 45);
    });

    test('all non-empty strings', () {
      for (final f in kFunFacts) {
        expect(f.isNotEmpty, true);
      }
    });

    test('no duplicates', () {
      expect(kFunFacts.toSet().length, kFunFacts.length);
    });
  });
}

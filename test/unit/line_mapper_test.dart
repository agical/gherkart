// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import 'package:gherkart/gherkart.dart';
import 'package:test/test.dart';

void main() {
  group('LineMapper', () {
    group('String.mapper() extension', () {
      test('matches exact string with no parameters', () {
        final mapper = 'the app is running'.mapper();
        final result = mapper('the app is running');

        expect(result, isNotNull);
        expect(result, isEmpty);
      });

      test('returns null for non-matching string', () {
        final mapper = 'the app is running'.mapper();
        final result = mapper('something else');

        expect(result, isNull);
      });

      test('extracts single parameter', () {
        final mapper = 'I navigate to {page}'.mapper();
        final result = mapper('I navigate to Sessions');

        expect(result, isNotNull);
        expect(result, ['Sessions']);
      });

      test('extracts parameter with quotes', () {
        final mapper = 'I navigate to "{page}"'.mapper();
        final result = mapper('I navigate to "Sessions"');

        expect(result, isNotNull);
        expect(result, ['Sessions']);
      });

      test('extracts multiple parameters', () {
        final mapper = 'I set {field} to {value}'.mapper();
        final result = mapper('I set team name to Champions');

        expect(result, isNotNull);
        expect(result, ['team name', 'Champions']);
      });

      test('handles parameter at start of line', () {
        final mapper = '{user} is logged in'.mapper();
        final result = mapper('John is logged in');

        expect(result, isNotNull);
        expect(result, ['John']);
      });

      test('is case sensitive', () {
        final mapper = 'The app is running'.mapper();

        expect(mapper('The app is running'), isNotNull);
        expect(mapper('the app is running'), isNull);
      });

      test('handles special regex characters in pattern', () {
        final mapper = 'I see the (optional) message'.mapper();
        final result = mapper('I see the (optional) message');

        expect(result, isNotNull);
        expect(result, isEmpty);
      });
    });

    group('Type conversions', () {
      test('converts int parameter', () {
        final mapper = 'I wait {seconds} seconds'.mapper(types: {'seconds': int});
        final result = mapper('I wait 5 seconds');

        expect(result, isNotNull);
        expect(result, [5]);
        expect(result![0], isA<int>());
      });

      test('converts double parameter', () {
        final mapper = 'the score is {score}'.mapper(types: {'score': double});
        final result = mapper('the score is 3.14');

        expect(result, isNotNull);
        expect(result, [3.14]);
        expect(result![0], isA<double>());
      });

      test('converts bool parameter true', () {
        final mapper = 'editing is {enabled}'.mapper(types: {'enabled': bool});
        final result = mapper('editing is true');

        expect(result, isNotNull);
        expect(result, [true]);
        expect(result![0], isA<bool>());
      });

      test('converts bool parameter false', () {
        final mapper = 'editing is {enabled}'.mapper(types: {'enabled': bool});
        final result = mapper('editing is false');

        expect(result, isNotNull);
        expect(result, [false]);
      });

      test('keeps string as default', () {
        final mapper = 'I enter {text}'.mapper();
        final result = mapper('I enter hello');

        expect(result, isNotNull);
        expect(result, ['hello']);
        expect(result![0], isA<String>());
      });

      test('converts mixed types', () {
        final mapper = 'I wait {seconds} seconds then enter {text}'.mapper(types: {'seconds': int});
        final result = mapper('I wait 10 seconds then enter hello');

        expect(result, isNotNull);
        expect(result, [10, 'hello']);
        expect(result?[0], isA<int>());
        expect(result?[1], isA<String>());
      });
    });

    group('Edge cases', () {
      test('empty pattern matches empty line', () {
        final mapper = ''.mapper();
        final result = mapper('');

        expect(result, isNotNull);
        expect(result, isEmpty);
      });

      test('empty pattern does not match non-empty line', () {
        final mapper = ''.mapper();
        final result = mapper('something');

        expect(result, isNull);
      });

      test('parameter can capture multiple words', () {
        final mapper = 'I see "{message}"'.mapper();
        final result = mapper('I see "Hello World"');

        expect(result, isNotNull);
        expect(result, ['Hello World']);
      });

      test('greedy capture stops at next literal', () {
        final mapper = '{greeting}, {name}!'.mapper();
        final result = mapper('Hello, World!');

        expect(result, isNotNull);
        expect(result, ['Hello', 'World']);
      });
    });
  });
}

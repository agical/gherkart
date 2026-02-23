// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import 'package:gherkart/gherkart.dart';
import 'package:test/test.dart';

void main() {
  group('StepRegistry', () {
    group('register and match', () {
      test('matches registered step with no parameters', () {
        final registry = StepRegistry<void>();

        registry.register(
          'the app is running'.mapper(),
          (_, ctx) async {},
        );

        final match = registry.match('the app is running');

        expect(match, isNotNull);
        expect(match!.params, isEmpty);
      });

      test('executes matched step', () async {
        final registry = StepRegistry<void>();
        var called = false;

        registry.register(
          'the app is running'.mapper(),
          (_, ctx) async {
            called = true;
          },
        );

        final match = registry.match('the app is running');
        await match!.execute(null);

        expect(called, isTrue);
      });

      test('extracts parameters and passes to step', () async {
        final registry = StepRegistry<void>();
        String? capturedPage;

        registry.register(
          'I navigate to "{page}"'.mapper(),
          (_, ctx) async {
            capturedPage = ctx.args[0] as String;
          },
        );

        final match = registry.match('I navigate to "Sessions"');
        await match!.execute(null);

        expect(capturedPage, 'Sessions');
      });

      test('returns null for unregistered step', () {
        final registry = StepRegistry<void>();

        final match = registry.match('unknown step');

        expect(match, isNull);
      });

      test('matches first registered pattern', () async {
        final registry = StepRegistry<void>();
        var matchedFirst = false;
        var matchedSecond = false;

        registry.register('test step'.mapper(), (_, ctx) async {
          matchedFirst = true;
        });
        registry.register('test step'.mapper(), (_, ctx) async {
          matchedSecond = true;
        });

        final match = registry.match('test step');
        await match!.execute(null);

        expect(matchedFirst, isTrue);
        expect(matchedSecond, isFalse);
      });

      test('handles typed parameters', () async {
        final registry = StepRegistry<void>();
        int? capturedCount;

        registry.register(
          'I wait {count} seconds'.mapper(types: {'count': int}),
          (_, ctx) async {
            capturedCount = ctx.args[0] as int;
          },
        );

        final match = registry.match('I wait 5 seconds');
        await match!.execute(null);

        expect(capturedCount, 5);
        expect(capturedCount, isA<int>());
      });
    });

    group('suggestPlaceholder', () {
      test('generates placeholder for simple step', () {
        final suggestion = StepRegistry.suggestPlaceholder('the app is running');

        expect(suggestion, contains("'the app is running'.mapper()"));
        expect(suggestion, contains('(\$, ctx) async'));
        expect(suggestion, contains('// TODO: implement'));
      });

      test('generates placeholder with detected string parameter', () {
        final suggestion = StepRegistry.suggestPlaceholder('I navigate to "Sessions"');

        expect(suggestion, contains('{page}'));
        expect(suggestion, contains('ctx.arg<String>(0)'));
      });

      test('generates placeholder with multiple string parameters', () {
        final suggestion = StepRegistry.suggestPlaceholder('I set "name" to "value"');

        expect(suggestion, contains('{page}'));
        expect(suggestion, contains('{param2}'));
        expect(suggestion, contains('ctx.arg<String>(0)'));
        expect(suggestion, contains('ctx.arg<String>(1)'));
      });

      test('generates placeholder with number parameter', () {
        final suggestion = StepRegistry.suggestPlaceholder('I wait 5 seconds');

        expect(suggestion, contains('{number}'));
        expect(suggestion, contains("'number': int"));
      });
    });

    group('fromMap constructor', () {
      test('creates registry from map literal', () async {
        var called = false;

        final registry = StepRegistry<void>.fromMap({
          'the app is running'.mapper(): (_, ctx) async {
            called = true;
          },
        });

        final match = registry.match('the app is running');
        await match!.execute(null);

        expect(called, isTrue);
      });

      test('supports multiple entries', () {
        final registry = StepRegistry<void>.fromMap({
          'step one'.mapper(): (_, ctx) async {},
          'step two'.mapper(): (_, ctx) async {},
        });

        expect(registry.match('step one'), isNotNull);
        expect(registry.match('step two'), isNotNull);
        expect(registry.match('step three'), isNull);
      });
    });

    group('merge', () {
      test('combines two registries', () {
        final registry1 = StepRegistry<void>.fromMap({
          'step one'.mapper(): (_, ctx) async {},
        });
        final registry2 = StepRegistry<void>.fromMap({
          'step two'.mapper(): (_, ctx) async {},
        });

        final merged = registry1.merge(registry2);

        expect(merged.match('step one'), isNotNull);
        expect(merged.match('step two'), isNotNull);
      });

      test('first registry takes precedence for duplicates', () async {
        var whichCalled = '';

        final registry1 = StepRegistry<void>.fromMap({
          'duplicate step'.mapper(): (_, ctx) async {
            whichCalled = 'first';
          },
        });
        final registry2 = StepRegistry<void>.fromMap({
          'duplicate step'.mapper(): (_, ctx) async {
            whichCalled = 'second';
          },
        });

        final merged = registry1.merge(registry2);
        final match = merged.match('duplicate step');
        await match!.execute(null);

        expect(whichCalled, 'first');
      });
    });

    group('stepCount', () {
      test('returns number of registered steps', () {
        final registry = StepRegistry<void>.fromMap({
          'step one'.mapper(): (_, ctx) async {},
          'step two'.mapper(): (_, ctx) async {},
          'step three'.mapper(): (_, ctx) async {},
        });

        expect(registry.stepCount, 3);
      });

      test('returns 0 for empty registry', () {
        final registry = StepRegistry<void>();

        expect(registry.stepCount, 0);
      });
    });

    group('StepContext', () {
      test('provides args via context', () async {
        final registry = StepRegistry<void>();
        String? capturedPage;

        registry.register(
          'I navigate to "{page}"'.mapper(),
          (_, ctx) async {
            capturedPage = ctx.arg<String>(0);
          },
        );

        final match = registry.match('I navigate to "Sessions"');
        await match!.execute(null);

        expect(capturedPage, 'Sessions');
      });

      test('provides firstArg convenience getter', () async {
        final registry = StepRegistry<void>();
        String? captured;

        registry.register(
          'I see "{text}"'.mapper(),
          (_, ctx) async {
            captured = ctx.firstArg;
          },
        );

        final match = registry.match('I see "Hello"');
        await match!.execute(null);

        expect(captured, 'Hello');
      });

      test('provides data table via context', () async {
        final registry = StepRegistry<void>();
        List<Map<String, String>>? capturedRows;

        registry.register(
          'the following users:'.mapper(),
          (_, ctx) async {
            capturedRows = ctx.tableRows;
          },
        );

        final match = registry.match('the following users:');
        final table = DataTable(
          headers: ['name', 'email'],
          rows: [
            ['Alice', 'alice@test.com'],
            ['Bob', 'bob@test.com'],
          ],
        );

        await match!.execute(null, table: table);

        expect(capturedRows, hasLength(2));
        expect(capturedRows![0], {'name': 'Alice', 'email': 'alice@test.com'});
      });

      test('hasTable returns true when table present', () async {
        final registry = StepRegistry<void>();
        bool? hasTable;

        registry.register(
          'users:'.mapper(),
          (_, ctx) async {
            hasTable = ctx.hasTable;
          },
        );

        final match = registry.match('users:');
        await match!.execute(
          null,
          table: DataTable(headers: ['x'], rows: []),
        );

        expect(hasTable, isTrue);
      });

      test('hasTable returns false when no table', () async {
        final registry = StepRegistry<void>();
        bool? hasTable;

        registry.register(
          'no table'.mapper(),
          (_, ctx) async {
            hasTable = ctx.hasTable;
          },
        );

        final match = registry.match('no table');
        await match!.execute(null);

        expect(hasTable, isFalse);
      });

      test('provides doc string via context', () async {
        final registry = StepRegistry<void>();
        String? capturedContent;

        registry.register(
          'the JSON:'.mapper(),
          (_, ctx) async {
            capturedContent = ctx.docContent;
          },
        );

        final match = registry.match('the JSON:');
        final docString = DocString(content: '{"key": "value"}');

        await match!.execute(null, docString: docString);

        expect(capturedContent, '{"key": "value"}');
      });

      test('hasDocString returns true when doc string present', () async {
        final registry = StepRegistry<void>();
        bool? hasDoc;

        registry.register(
          'content:'.mapper(),
          (_, ctx) async {
            hasDoc = ctx.hasDocString;
          },
        );

        final match = registry.match('content:');
        await match!.execute(null, docString: DocString(content: 'text'));

        expect(hasDoc, isTrue);
      });

      test('provides location via context', () async {
        final registry = StepRegistry<void>();
        SourceLocation? capturedLocation;

        registry.register(
          'a step'.mapper(),
          (_, ctx) async {
            capturedLocation = ctx.location;
          },
        );

        final match = registry.match('a step');
        final loc = SourceLocation(filePath: 'test.feature', line: 42);
        await match!.execute(null, location: loc);

        expect(capturedLocation, isNotNull);
        expect(capturedLocation!.filePath, 'test.feature');
        expect(capturedLocation!.line, 42);
      });

      test('tableRows throws when no table', () async {
        final registry = StepRegistry<void>();
        Object? caughtError;

        registry.register(
          'no table'.mapper(),
          (_, ctx) async {
            try {
              ctx.tableRows;
            } catch (e) {
              caughtError = e;
            }
          },
        );

        final match = registry.match('no table');
        await match!.execute(null);

        expect(caughtError, isA<StateError>());
      });

      test('docContent throws when no doc string', () async {
        final registry = StepRegistry<void>();
        Object? caughtError;

        registry.register(
          'no doc'.mapper(),
          (_, ctx) async {
            try {
              ctx.docContent;
            } catch (e) {
              caughtError = e;
            }
          },
        );

        final match = registry.match('no doc');
        await match!.execute(null);

        expect(caughtError, isA<StateError>());
      });
    });
  });
}

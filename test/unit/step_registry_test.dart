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

        registry.register('the app is running'.mapper(), (_, ctx) async {});

        final match = registry.match('the app is running');

        expect(match, isNotNull);
        expect(match!.params, isEmpty);
      });

      test('executes matched step', () async {
        final registry = StepRegistry<void>();
        var called = false;

        registry.register('the app is running'.mapper(), (_, ctx) async {
          called = true;
        });

        final match = registry.match('the app is running');
        await match!.execute(null);

        expect(called, isTrue);
      });

      test('extracts parameters and passes to step', () async {
        final registry = StepRegistry<void>();
        String? capturedPage;

        registry.register('I navigate to "{page}"'.mapper(), (_, ctx) async {
          capturedPage = ctx.args[0] as String;
        });

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

        registry.register('I wait {count} seconds'.mapper(types: {'count': int}), (_, ctx) async {
          capturedCount = ctx.args[0] as int;
        });

        final match = registry.match('I wait 5 seconds');
        await match!.execute(null);

        expect(capturedCount, 5);
        expect(capturedCount, isA<int>());
      });
    });

    group('suggestPlaceholder & CucumberExpressionGenerator', () {
      test('generates placeholder for simple step', () {
        final suggestion = StepRegistry.suggestPlaceholder('the app is running');

        expect(suggestion, contains("'the app is running'.cucumber()"));
        expect(suggestion, contains('(\$, ctx) async'));
        expect(suggestion, contains('// TODO: implement'));
      });

      test('generates placeholder with detected {string} parameter', () {
        final suggestion = StepRegistry.suggestPlaceholder('I navigate to "Sessions"');

        expect(suggestion, contains("'I navigate to {string}'.cucumber()"));
        expect(suggestion, contains('ctx.arg<String>(0)'));
      });

      test('generates placeholder with multiple {string} parameters', () {
        final suggestion = StepRegistry.suggestPlaceholder('I set "name" to "value"');

        expect(suggestion, contains("'I set {string} to {string}'.cucumber()"));
        expect(suggestion, contains('final string = ctx.arg<String>(0)'));
        expect(suggestion, contains('final string2 = ctx.arg<String>(1)'));
      });

      test('generates candidate placeholders for integer ({int} and {float})', () {
        final candidates = StepRegistry.suggestPlaceholders('I wait 5 seconds');

        expect(candidates.length, greaterThanOrEqualTo(2));
        expect(candidates[0], contains("'I wait {int} seconds'.cucumber()"));
        expect(candidates[0], contains('final intVal = ctx.arg<int>(0)'));
        expect(candidates[1], contains("'I wait {float} seconds'.cucumber()"));
        expect(candidates[1], contains('final float = ctx.arg<double>(0)'));
      });

      test('includes custom ParameterType in generated snippets', () {
        final paramTypes = ParameterTypeRegistry()
          ..defineParameterType(ParameterType<String>('airport', r'[A-Z]{3}', 'String', (g) => g.first!));

        final suggestion = StepRegistry.suggestPlaceholder('flight from LHR to CDG', parameterTypes: paramTypes);

        expect(suggestion, contains("'flight from {airport} to {airport}'.cucumber()"));
        expect(suggestion, contains('final airport = ctx.arg<String>(0)'));
        expect(suggestion, contains('final airport2 = ctx.arg<String>(1)'));
      });
    });

    group('Cucumber Expressions & RegExp support', () {
      test('matches typed {int}, {float}, {string}, and {word} without types map', () async {
        int? count;
        double? price;
        String? item;
        String? currency;

        final registry = StepRegistry<void>.fromMap({
          'I buy {int} {string} for {float} {word}'.cucumber(): (_, ctx) async {
            count = ctx.arg<int>(0);
            item = ctx.arg<String>(1);
            price = ctx.arg<double>(2);
            currency = ctx.arg<String>(3);
          },
        });

        final match = registry.match('I buy 3 "cucumbers" for 4.50 USD');
        expect(match, isNotNull);
        await match!.execute(null);

        expect(count, 3);
        expect(item, 'cucumbers');
        expect(price, 4.50);
        expect(currency, 'USD');
      });

      test('supports optional text apple(s) and alternatives is/are via fluent API', () async {
        final captured = <int>[];

        final registry = StepRegistry<void>()
          ..given('there is/are {int} apple(s) on the tree', (_, ctx) async {
            captured.add(ctx.arg<int>(0));
          })
          ..when('I pick {int} apple(s)', (_, ctx) async {
            captured.add(ctx.arg<int>(0));
          })
          ..then('{int} apple(s) remain(s)', (_, ctx) async {
            captured.add(ctx.arg<int>(0));
          })
          ..and('the basket is empty/full', (_, __) async {})
          ..but('nothing is spoiled', (_, __) async {});

        await registry.match('there is 1 apple on the tree')!.execute(null);
        await registry.match('there are 5 apples on the tree')!.execute(null);
        await registry.match('I pick 2 apples')!.execute(null);
        await registry.match('3 apples remain')!.execute(null);
        expect(registry.match('the basket is full'), isNotNull);
        expect(registry.match('nothing is spoiled'), isNotNull);

        expect(captured, [1, 5, 2, 3]);
      });

      test('supports custom ParameterType registration and merge', () async {
        final colors = <String>[];

        final r1 = StepRegistry<void>()
          ..defineParameterType(
            ParameterType<String>('color', 'red|green|blue', 'String', (g) => g.first!.toUpperCase()),
          )
          ..step('the light is {color}', (_, ctx) async {
            colors.add(ctx.arg<String>(0));
          });

        final r2 = StepRegistry<void>.fromExpressions({'I press {word}': (_, __) async {}});

        final merged = r1.merge(r2);
        expect(merged.customParameterTypes, hasLength(1));
        expect(merged.customParameterTypes.single.name, 'color');

        await merged.match('the light is green')!.execute(null);
        expect(colors, ['GREEN']);
        expect(merged.match('the light is yellow'), isNull);
        expect(merged.match('I press start'), isNotNull);
      });

      test('supports RegExp.mapper() and registry.regex()', () async {
        final registry = StepRegistry<void>.fromMap({
          RegExp(r'^user (\d+) logs in$').mapper(): (_, ctx) async {
            expect(ctx.arg<int>(0), 42);
          },
        });

        final match = registry.match('user 42 logs in');
        expect(match, isNotNull);
        await match!.execute(null);
        expect(registry.isRegularExpressionAt(0), isTrue);
      });

      test('coexists cleanly with legacy .mapper() and SchemeResolver', () async {
        String? resolvedGreeting;
        final resolver = SchemeResolver()..register('t', (key, _) async => 'Hello from $key');

        final registry = StepRegistry<void>.fromMap({
          'I see {string}'.cucumber(): (_, ctx) async {
            resolvedGreeting = ctx.arg<String>(0);
          },
          'legacy {name} step'.mapper(): (_, __) async {},
        });

        final match = registry.match('I see "{t:home}"')!;
        final resolved = await resolver.resolveAll(match.params);
        await match.execute(null, resolvedArgs: resolved.map((r) => r.resolved).toList());

        expect(resolvedGreeting, 'Hello from home');
        expect(registry.match('legacy custom step'), isNotNull);
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
        final registry1 = StepRegistry<void>.fromMap({'step one'.mapper(): (_, ctx) async {}});
        final registry2 = StepRegistry<void>.fromMap({'step two'.mapper(): (_, ctx) async {}});

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

        registry.register('I navigate to "{page}"'.mapper(), (_, ctx) async {
          capturedPage = ctx.arg<String>(0);
        });

        final match = registry.match('I navigate to "Sessions"');
        await match!.execute(null);

        expect(capturedPage, 'Sessions');
      });

      test('provides firstArg convenience getter', () async {
        final registry = StepRegistry<void>();
        String? captured;

        registry.register('I see "{text}"'.mapper(), (_, ctx) async {
          captured = ctx.firstArg;
        });

        final match = registry.match('I see "Hello"');
        await match!.execute(null);

        expect(captured, 'Hello');
      });

      test('provides data table via context', () async {
        final registry = StepRegistry<void>();
        List<Map<String, String>>? capturedRows;

        registry.register('the following users:'.mapper(), (_, ctx) async {
          capturedRows = ctx.tableRows;
        });

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

        registry.register('users:'.mapper(), (_, ctx) async {
          hasTable = ctx.hasTable;
        });

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

        registry.register('no table'.mapper(), (_, ctx) async {
          hasTable = ctx.hasTable;
        });

        final match = registry.match('no table');
        await match!.execute(null);

        expect(hasTable, isFalse);
      });

      test('provides doc string via context', () async {
        final registry = StepRegistry<void>();
        String? capturedContent;

        registry.register('the JSON:'.mapper(), (_, ctx) async {
          capturedContent = ctx.docContent;
        });

        final match = registry.match('the JSON:');
        final docString = DocString(content: '{"key": "value"}');

        await match!.execute(null, docString: docString);

        expect(capturedContent, '{"key": "value"}');
      });

      test('hasDocString returns true when doc string present', () async {
        final registry = StepRegistry<void>();
        bool? hasDoc;

        registry.register('content:'.mapper(), (_, ctx) async {
          hasDoc = ctx.hasDocString;
        });

        final match = registry.match('content:');
        await match!.execute(null, docString: DocString(content: 'text'));

        expect(hasDoc, isTrue);
      });

      test('provides location via context', () async {
        final registry = StepRegistry<void>();
        SourceLocation? capturedLocation;

        registry.register('a step'.mapper(), (_, ctx) async {
          capturedLocation = ctx.location;
        });

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

        registry.register('no table'.mapper(), (_, ctx) async {
          try {
            ctx.tableRows;
          } catch (e) {
            caughtError = e;
          }
        });

        final match = registry.match('no table');
        await match!.execute(null);

        expect(caughtError, isA<StateError>());
      });

      test('docContent throws when no doc string', () async {
        final registry = StepRegistry<void>();
        Object? caughtError;

        registry.register('no doc'.mapper(), (_, ctx) async {
          try {
            ctx.docContent;
          } catch (e) {
            caughtError = e;
          }
        });

        final match = registry.match('no doc');
        await match!.execute(null);

        expect(caughtError, isA<StateError>());
      });
    });
  });
}

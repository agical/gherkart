// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import 'package:gherkart/gherkart.dart';
import 'package:test/test.dart';

void main() {
  group('SchemeResolver', () {
    late SchemeResolver resolver;

    setUp(() {
      resolver = SchemeResolver();
    });

    group('pattern matching', () {
      test('identifies scheme parameters', () async {
        resolver.register('t', (value) async => 'translated: $value');

        final result = await resolver.resolve('{t:greeting}');

        expect(result.scheme, 't');
        expect(result.value, 'greeting');
        expect(result.hasScheme, true);
      });

      test('treats plain text as literal', () async {
        final result = await resolver.resolve('plain text');

        expect(result.scheme, isNull);
        expect(result.value, 'plain text');
        expect(result.resolved, 'plain text');
        expect(result.hasScheme, false);
      });

      test('treats quoted text without scheme as literal', () async {
        final result = await resolver.resolve('Game Complete!');

        expect(result.scheme, isNull);
        expect(result.value, 'Game Complete!');
        expect(result.resolved, 'Game Complete!');
      });

      test('handles colons in value', () async {
        resolver.register('t', (value) async => 'got: $value');

        final result = await resolver.resolve('{t:key:with:colons}');

        expect(result.scheme, 't');
        expect(result.value, 'key:with:colons');
      });

      test('handles spaces in value', () async {
        resolver.register('k', (value) async => 'key: $value');

        final result = await resolver.resolve('{k:bank display}');

        expect(result.scheme, 'k');
        expect(result.value, 'bank display');
      });
    });

    group('scheme handlers', () {
      test('applies translation handler', () async {
        final translations = {
          'greeting': 'Hello!',
          'farewell': 'Goodbye!',
        };
        resolver.register('t', createTranslationHandler((key) => translations[key]!));

        final result = await resolver.resolve('{t:greeting}');

        expect(result.resolved, 'Hello!');
      });

      test('applies key mapping handler', () async {
        final keys = {
          'bank display': 'BankGameKeys.bankDisplay',
          'shot counter': 'BankGameKeys.shotCounter',
        };
        resolver.register('k', createKeyMappingHandler((name) => keys[name]));

        final result = await resolver.resolve('{k:shot counter}');

        expect(result.resolved, 'BankGameKeys.shotCounter');
      });

      test('throws on unknown scheme', () async {
        expect(
          () => resolver.resolve('{unknown:value}'),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Unknown scheme "unknown"'),
          )),
        );
      });

      test('error message includes original param without parameters', () async {
        resolver.register('t', (v) async => v);

        expect(
          () => resolver.resolve('{bad:hello}'),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('Unknown scheme "bad"'),
              contains('{bad:hello}'),
              contains('Registered schemes: t'),
            ),
          )),
        );
      });

      test('error message includes original param with parameters', () async {
        resolver.register('t', (v) async => v);

        expect(
          () => resolver.resolve('{bad:key(name: \'Alice\')}'),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('Unknown scheme "bad"'),
              contains('{bad:key(name: \'Alice\')}'),
              contains('Registered schemes: t'),
            ),
          )),
        );
      });
    });

    group('resolveAll', () {
      test('resolves list of parameters', () async {
        resolver.register('t', (v) async => 'T:$v');
        resolver.register('k', (v) async => 'K:$v');

        final results = await resolver.resolveAll([
          '{t:hello}',
          '{k:element}',
          'literal',
        ]);

        expect(results.length, 3);
        expect(results[0].resolved, 'T:hello');
        expect(results[1].resolved, 'K:element');
        expect(results[2].resolved, 'literal');
      });

      test('handles non-string parameters', () async {
        final results = await resolver.resolveAll([123, true]);

        expect(results[0].resolved, 123);
        expect(results[1].resolved, true);
      });
    });

    group('hasScheme', () {
      test('returns true for registered schemes', () {
        resolver.register('t', (v) async => v);

        expect(resolver.hasScheme('t'), true);
        expect(resolver.hasScheme('k'), false);
      });
    });

    group('ResolvedParam', () {
      test('toString for scheme param', () {
        final param = ResolvedParam(
          original: '{t:greeting}',
          scheme: 't',
          value: 'greeting',
          resolved: 'Hello!',
        );

        expect(param.toString(), 't:greeting -> Hello!');
      });

      test('toString for literal param', () {
        final param = ResolvedParam(
          original: 'literal',
          scheme: null,
          value: 'literal',
          resolved: 'literal',
        );

        expect(param.toString(), 'literal: literal');
      });
    });

    group('parameterized scheme values', () {
      test('parses single parameter from scheme value', () async {
        resolver.register('t', (value) async => '{shots} shot(s)');

        final result = await resolver.resolve('{t:shotLabel(shots: 1)}');

        expect(result.scheme, 't');
        expect(result.value, 'shotLabel');
        expect(result.params, {'shots': '1'});
        expect(result.resolved, '1 shot(s)');
      });

      test('parses multiple parameters', () async {
        resolver.register('t', (value) async => 'Good {time}, {name}!');

        final result = await resolver.resolve('{t:greeting(name: \'Alice\', time: \'morning\')}');

        expect(result.scheme, 't');
        expect(result.value, 'greeting');
        expect(result.params, {'name': 'Alice', 'time': 'morning'});
        expect(result.resolved, 'Good morning, Alice!');
      });

      test('passes only the key to handler, not the params', () async {
        String? receivedKey;
        resolver.register('t', (value) async {
          receivedKey = value;
          return 'resolved';
        });

        await resolver.resolve('{t:myKey(p: \'v\')}');

        expect(receivedKey, 'myKey');
      });

      test('no substitution when no params provided', () async {
        resolver.register('t', (value) async => 'Hello, World!');

        final result = await resolver.resolve('{t:hello}');

        expect(result.params, isEmpty);
        expect(result.resolved, 'Hello, World!');
      });

      test('params field is empty for plain scheme values', () async {
        resolver.register('t', (value) async => 'resolved');

        final result = await resolver.resolve('{t:simpleKey}');

        expect(result.params, isEmpty);
      });

      test('params field is empty for literal values', () async {
        final result = await resolver.resolve('plain text');

        expect(result.params, isEmpty);
      });

      test('substitutes only matching placeholders', () async {
        resolver.register('t', (value) async => '{name} has {count} {thing}');

        final result = await resolver.resolve('{t:label(name: \'Bob\', count: 3)}');

        // {thing} is not in params, so it stays as-is
        expect(result.resolved, 'Bob has 3 {thing}');
      });

      test('does not substitute when resolved value is not a String', () async {
        resolver.register('k', (value) async => 42);

        final result = await resolver.resolve('{k:element(p: \'v\')}');

        expect(result.resolved, 42);
        expect(result.params, {'p': 'v'});
      });

      test('handles quoted parameter values with spaces', () async {
        resolver.register('t', (value) async => 'Welcome, {guest}!');

        final result = await resolver.resolve('{t:welcome(guest: \'John Doe\')}');

        expect(result.params, {'guest': 'John Doe'});
        expect(result.resolved, 'Welcome, John Doe!');
      });

      test('resolveAll works with parameterized values', () async {
        resolver.register('t', (value) async {
          final map = {
            'shotLabel': '{shots} shot(s)',
            'hello': 'Hello!',
          };
          return map[value]!;
        });

        final results = await resolver.resolveAll([
          '{t:shotLabel(shots: 5)}',
          '{t:hello}',
          'literal',
        ]);

        expect(results[0].resolved, '5 shot(s)');
        expect(results[1].resolved, 'Hello!');
        expect(results[2].resolved, 'literal');
      });
    });
  });
}

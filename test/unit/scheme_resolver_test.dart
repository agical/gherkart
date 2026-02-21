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
        resolver.register(
            't', createTranslationHandler((key) => translations[key]!));

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
  });
}

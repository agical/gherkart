// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import 'package:gherkart/gherkart.dart';
import 'package:test/test.dart';

void main() {
  group('TranslationScheme', () {
    group('createMapTranslationHandler', () {
      test('resolves known keys', () async {
        final handler = createMapTranslationHandler({
          'greeting': 'Hello!',
          'farewell': 'Goodbye!',
        });

        expect(await handler('greeting', {}), 'Hello!');
        expect(await handler('farewell', {}), 'Goodbye!');
      });

      test('throws on unknown key', () async {
        final handler = createMapTranslationHandler({
          'greeting': 'Hello!',
        });

        expect(
          () => handler('unknown', {}),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Translation key "unknown" not found'),
          )),
        );
      });
    });

    group('createArbTranslationHandler with AssetSource', () {
      test('loads translations from ARB content via AssetSource', () async {
        final source = AssetSource.fromMap({
          'test.arb': '''
{
  "@@locale": "en",
  "sessionTitle": "Sessions",
  "homeWelcome": "Welcome to Beer Pong",
  "appName": "Beer Pong"
}
''',
        });

        final handler = createArbTranslationHandler('test.arb', source: source);

        expect(await handler('sessionTitle', {}), 'Sessions');
        expect(await handler('homeWelcome', {}), 'Welcome to Beer Pong');
      });

      test('throws on unknown key with AssetSource', () async {
        final source = AssetSource.fromMap({
          'test.arb': '''
{
  "@@locale": "en",
  "greeting": "Hello!"
}
''',
        });

        final handler = createArbTranslationHandler('test.arb', source: source);

        expect(
          () => handler('unknownKey', {}),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Translation key "unknownKey" not found'),
          )),
        );
      });
    });

    group('integration with SchemeResolver', () {
      test('resolves translation scheme', () async {
        final resolver = SchemeResolver()
          ..register(
              't',
              createMapTranslationHandler({
                'greeting': 'Hello!',
                'sessionTitle': 'Sessions',
              }));

        final result = await resolver.resolve('{t:greeting}');

        expect(result.scheme, 't');
        expect(result.value, 'greeting');
        expect(result.resolved, 'Hello!');
      });

      test('works with AssetSource ARB file', () async {
        final source = AssetSource.fromMap({
          'lib/l10n/en.arb': '''
{
  "@@locale": "en",
  "sessionTitle": "Sessions"
}
''',
        });

        final resolver = SchemeResolver()
          ..register('t', createArbTranslationHandler('lib/l10n/en.arb', source: source));

        final result = await resolver.resolve('{t:sessionTitle}');

        expect(result.scheme, 't');
        expect(result.value, 'sessionTitle');
        expect(result.resolved, 'Sessions');
      });
    });

    group('parameterized translations with map handler', () {
      test('substitutes single placeholder in map translation', () async {
        final resolver = SchemeResolver()
          ..register(
              't',
              createMapTranslationHandler({
                'shotLabel': '{shots} shot(s)',
              }));

        final result = await resolver.resolve('{t:shotLabel(shots: 3)}');

        expect(result.resolved, '3 shot(s)');
      });

      test('substitutes multiple placeholders in map translation', () async {
        final resolver = SchemeResolver()
          ..register(
              't',
              createMapTranslationHandler({
                'greeting': 'Good {time}, {name}!',
              }));

        final result = await resolver.resolve('{t:greeting(name: \'Alice\', time: \'morning\')}');

        expect(result.resolved, 'Good morning, Alice!');
      });

      test('plain key still works alongside parameterized key', () async {
        final resolver = SchemeResolver()
          ..register(
              't',
              createMapTranslationHandler({
                'hello': 'Hello, World!',
                'shotLabel': '{shots} shot(s)',
              }));

        final plain = await resolver.resolve('{t:hello}');
        final parameterized = await resolver.resolve('{t:shotLabel(shots: 1)}');

        expect(plain.resolved, 'Hello, World!');
        expect(parameterized.resolved, '1 shot(s)');
      });
    });

    group('parameterized translations with ARB handler', () {
      test('substitutes placeholders in ARB translation', () async {
        final source = AssetSource.fromMap({
          'test.arb': '''
{
  "@@locale": "en",
  "shotLabel": "{shots} shot(s)",
  "@shotLabel": {
    "placeholders": {
      "shots": {"type": "int"}
    }
  }
}
''',
        });

        final resolver = SchemeResolver()..register('t', createArbTranslationHandler('test.arb', source: source));

        final result = await resolver.resolve('{t:shotLabel(shots: 2)}');

        expect(result.resolved, '2 shot(s)');
      });

      test('substitutes multiple placeholders in ARB translation', () async {
        final source = AssetSource.fromMap({
          'test.arb': '''
{
  "@@locale": "en",
  "greeting": "Good {time}, {name}!",
  "@greeting": {
    "placeholders": {
      "name": {"type": "String"},
      "time": {"type": "String"}
    }
  }
}
''',
        });

        final resolver = SchemeResolver()..register('t', createArbTranslationHandler('test.arb', source: source));

        final result = await resolver.resolve('{t:greeting(name: \'Bob\', time: \'evening\')}');

        expect(result.resolved, 'Good evening, Bob!');
      });
    });

    group('ICU plural support', () {
      test('selects =0 form for zero', () async {
        final handler = createMapTranslationHandler({
          'shotLabel': '{count, plural, =0{no shots} =1{1 shot} other{{count} shots}}',
        });

        final resolver = SchemeResolver()..register('t', handler);
        final result = await resolver.resolve('{t:shotLabel(count: 0)}');

        expect(result.resolved, 'no shots');
      });

      test('selects =1 form for one', () async {
        final handler = createMapTranslationHandler({
          'shotLabel': '{count, plural, =0{no shots} =1{1 shot} other{{count} shots}}',
        });

        final resolver = SchemeResolver()..register('t', handler);
        final result = await resolver.resolve('{t:shotLabel(count: 1)}');

        expect(result.resolved, '1 shot');
      });

      test('selects other form and substitutes param', () async {
        final handler = createMapTranslationHandler({
          'shotLabel': '{count, plural, =0{no shots} =1{1 shot} other{{count} shots}}',
        });

        final resolver = SchemeResolver()..register('t', handler);
        final result = await resolver.resolve('{t:shotLabel(count: 5)}');

        expect(result.resolved, '5 shots');
      });

      test('handles # as placeholder for count param', () async {
        final handler = createMapTranslationHandler({
          'itemCount': '{count, plural, =0{no items} =1{# item} other{# items}}',
        });

        final resolver = SchemeResolver()..register('t', handler);
        final result = await resolver.resolve('{t:itemCount(count: 42)}');

        expect(result.resolved, '42 items');
      });

      test('handles plural with ARB handler', () async {
        final source = AssetSource.fromMap({
          'test.arb': '''
{
  "@@locale": "en",
  "shotLabel": "{count, plural, =0{no shots} =1{1 shot} other{{count} shots}}",
  "@shotLabel": {
    "placeholders": {
      "count": {"type": "int"}
    }
  }
}
''',
        });

        final resolver = SchemeResolver()..register('t', createArbTranslationHandler('test.arb', source: source));
        final result = await resolver.resolve('{t:shotLabel(count: 3)}');

        expect(result.resolved, '3 shots');
      });

      test('plural with mixed regular placeholders', () async {
        final handler = createMapTranslationHandler({
          'userShots': '{name} scored {count, plural, =0{no shots} =1{1 shot} other{{count} shots}}',
        });

        final resolver = SchemeResolver()..register('t', handler);
        final result = await resolver.resolve('{t:userShots(name: \'Alice\', count: 2)}');

        expect(result.resolved, 'Alice scored 2 shots');
      });

      test('falls back to other when exact match not found', () async {
        final handler = createMapTranslationHandler({
          'shotLabel': '{count, plural, =0{no shots} other{{count} shots}}',
        });

        final resolver = SchemeResolver()..register('t', handler);
        final result = await resolver.resolve('{t:shotLabel(count: 1)}');

        expect(result.resolved, '1 shots');
      });
    });
  });
}

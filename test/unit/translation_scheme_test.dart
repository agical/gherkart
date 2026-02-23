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

        expect(await handler('greeting'), 'Hello!');
        expect(await handler('farewell'), 'Goodbye!');
      });

      test('throws on unknown key', () async {
        final handler = createMapTranslationHandler({
          'greeting': 'Hello!',
        });

        expect(
          () => handler('unknown'),
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
  "homeWelcome": "Welcome to RipMatrix",
  "appName": "RipMatrix"
}
''',
        });

        final handler = createArbTranslationHandler('test.arb', source: source);

        expect(await handler('sessionTitle'), 'Sessions');
        expect(await handler('homeWelcome'), 'Welcome to RipMatrix');
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
          () => handler('unknownKey'),
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
  });
}

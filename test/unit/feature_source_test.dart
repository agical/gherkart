// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import 'package:gherkart/gherkart.dart';
import 'package:test/test.dart';

void main() {
  group('AssetSource', () {
    group('fromMap', () {
      test('reads content from map', () async {
        final source = AssetSource.fromMap({
          'test.feature': 'Feature: Test',
        });

        final content = await source.read('test.feature');

        expect(content, 'Feature: Test');
      });

      test('throws on missing path', () async {
        final source = AssetSource.fromMap({
          'test.feature': 'Feature: Test',
        });

        expect(
          () => source.read('missing.feature'),
          throwsA(isA<FeatureSourceException>()),
        );
      });

      test('lists single feature file', () async {
        final source = AssetSource.fromMap({
          'test.feature': 'Feature: Test',
        });

        final files = await source.list('test.feature');

        expect(files, ['test.feature']);
      });

      test('lists features in directory', () async {
        final source = AssetSource.fromMap({
          'features/login.feature': 'Feature: Login',
          'features/home.feature': 'Feature: Home',
          'features/nested/deep.feature': 'Feature: Deep',
          'other/unrelated.txt': 'Not a feature',
        });

        final files = await source.list('features');

        expect(files, hasLength(3));
        expect(files, contains('features/login.feature'));
        expect(files, contains('features/home.feature'));
        expect(files, contains('features/nested/deep.feature'));
        expect(files, isNot(contains('other/unrelated.txt')));
      });

      test('returns empty list for non-existent directory', () async {
        final source = AssetSource.fromMap({
          'features/test.feature': 'Feature: Test',
        });

        final files = await source.list('nonexistent');

        expect(files, isEmpty);
      });

      test('checks existence', () async {
        final source = AssetSource.fromMap({
          'test.feature': 'Feature: Test',
        });

        expect(await source.exists('test.feature'), isTrue);
        expect(await source.exists('missing.feature'), isFalse);
      });
    });

    group('fromLoader', () {
      test('reads content via loader function', () async {
        final source = AssetSource.fromLoader((path) async {
          if (path == 'test.feature') {
            return 'Feature: Test';
          }
          throw Exception('Not found: $path');
        });

        final content = await source.read('test.feature');

        expect(content, 'Feature: Test');
      });

      test('lists via lister function', () async {
        final source = AssetSource.fromLoader(
          (path) async => 'content',
          lister: (path) async => [
            'features/a.feature',
            'features/b.feature',
          ],
        );

        final files = await source.list('features');

        expect(files, hasLength(2));
      });

      test('throws when listing without lister for directory', () async {
        final source = AssetSource.fromLoader((path) async => 'content');

        expect(
          () => source.list('features'),
          throwsA(isA<FeatureSourceException>()),
        );
      });

      test('returns single file when listing .feature path without lister',
          () async {
        final source = AssetSource.fromLoader((path) async => 'content');

        final files = await source.list('test.feature');

        expect(files, ['test.feature']);
      });
    });
  });
}

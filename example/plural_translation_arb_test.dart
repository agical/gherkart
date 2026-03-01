// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/// Plural translation example using ARB source.
///
/// Demonstrates the same ICU plural functionality as
/// plural_translation_test.dart, but reading translations from an ARB file
/// via [AssetSource] instead of an in-memory map.
///
/// Run with: dart test example/plural_translation_arb_test.dart
library;

import 'package:gherkart/gherkart.dart';
import 'package:gherkart/gherkart_io.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Steps
// ---------------------------------------------------------------------------

final _steps = StepRegistry<void>.fromMap({
  '"{actual}" is "{expected}"'.mapper(): ($, ctx) async {
    final actual = ctx.arg<String>(0);
    final expected = ctx.arg<String>(1);
    expect(actual, expected);
  },
});

// ---------------------------------------------------------------------------
// ARB source with ICU plural translations
// ---------------------------------------------------------------------------

final _arbSource = AssetSource.fromMap({
  'example/l10n/en.arb': '''
{
  "@@locale": "en",
  "shotLabel": "{count, plural, =0{no shots} =1{1 shot} other{{count} shots}}",
  "@shotLabel": {
    "placeholders": {
      "count": {"type": "int"}
    }
  },
  "itemCount": "{count, plural, =0{no items} =1{# item} other{# items}}",
  "@itemCount": {
    "placeholders": {
      "count": {"type": "int"}
    }
  },
  "userShots": "{name} scored {count, plural, =0{nothing} =1{1 shot} other{{count} shots}}",
  "@userShots": {
    "placeholders": {
      "name": {"type": "String"},
      "count": {"type": "int"}
    }
  }
}
''',
});

final _resolver = SchemeResolver()
  ..register(
    't',
    createArbTranslationHandler('example/l10n/en.arb', source: _arbSource),
  );

// ---------------------------------------------------------------------------
// Test runner
// ---------------------------------------------------------------------------

Future<void> main() async {
  await runBddTests<void>(
    rootPaths: ['example/features/plural_translation_arb.feature'],
    registry: _steps,
    source: FileSystemSource(),
    schemeResolver: _resolver,
    adapter: _createTestAdapter(),
    output: const BddOutput.verbose(),
  );
}

TestAdapter<void> _createTestAdapter() {
  return TestAdapter<void>(
    testFunction: _testFunction,
    group: group,
    setUpAll: setUpAll,
    tearDownAll: tearDownAll,
    fail: (message) => fail(message),
  );
}

void _testFunction(
  String name, {
  List<String>? tags,
  bool skip = false,
  Future<void> Function(void)? callback,
}) {
  test(name, () => callback!(null), tags: tags, skip: skip);
}

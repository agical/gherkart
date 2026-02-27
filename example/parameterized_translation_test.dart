// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/// Parameterized translation example.
///
/// Demonstrates:
/// - `{t:key(param: value)}` syntax for parameterized translations
/// - Placeholders in translation values get substituted with provided params
/// - Backward-compatible with plain `{t:key}` syntax
///
/// Run with: dart test example/parameterized_translation_test.dart
library;

import 'package:gherkart/gherkart.dart';
import 'package:gherkart/gherkart_io.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

final _seen = <String>[];

// ---------------------------------------------------------------------------
// Steps
// ---------------------------------------------------------------------------

final paramTranslationSteps = StepRegistry<void>.fromMap({
  'I see the text "{text}"'.mapper(): ($, ctx) async {
    final text = ctx.arg<String>(0);
    _seen.add(text);
    expect(text, isNotEmpty);
  },
});

// ---------------------------------------------------------------------------
// Scheme resolver with parameterized translations
// ---------------------------------------------------------------------------

final resolver = SchemeResolver()
  ..register(
    't',
    createMapTranslationHandler({
      'shotLabel': '{shots} shot(s)',
      'greeting': 'Good {time}, {name}!',
      'hello': 'Hello, World!',
    }),
  );

// ---------------------------------------------------------------------------
// Test runner
// ---------------------------------------------------------------------------

Future<void> main() async {
  setUp(_seen.clear);

  await runBddTests<void>(
    rootPaths: ['example/features/parameterized_translation.feature'],
    registry: paramTranslationSteps,
    source: FileSystemSource(),
    schemeResolver: resolver,
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

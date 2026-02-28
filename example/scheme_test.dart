// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/// Scheme resolution example.
///
/// Demonstrates:
/// - `SchemeResolver` with the `{t:key}` prefix for translation lookups
/// - `createMapTranslationHandler` for in-memory translations
/// - Literal values passing through without a scheme
///
/// Run with: dart test example/scheme_test.dart
library;

import 'package:gherkart/gherkart.dart';
import 'package:gherkart/gherkart_io.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Steps — the resolved value arrives in ctx.arg after scheme resolution
// ---------------------------------------------------------------------------

final schemeSteps = StepRegistry<void>.fromMap({
  '"{actual}" is "{expected}"'.mapper(): ($, ctx) async {
    final actual = ctx.arg<String>(0);
    final expected = ctx.arg<String>(1);
    expect(actual, expected);
  },
});

// ---------------------------------------------------------------------------
// Scheme resolver
// ---------------------------------------------------------------------------

final resolver = SchemeResolver()
  ..register(
    't',
    createMapTranslationHandler({
      'hello': 'Hello, World!',
      'goodbye': 'See you later!',
    }),
  );

// ---------------------------------------------------------------------------
// Test runner
// ---------------------------------------------------------------------------

Future<void> main() async {
  await runBddTests<void>(
    rootPaths: ['example/features/scheme.feature'],
    registry: schemeSteps,
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

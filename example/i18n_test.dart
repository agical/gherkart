// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/// Multi-language (i18n) BDD test example.
///
/// Demonstrates:
/// - Parsing `.feature` files in languages other than English via `# language: fr`
/// - Step definitions written in the feature's natural language
/// - Standard Gherkin keywords (`Règle`, `Exemple`, `*`, `Quand`, `Alors`)
///
/// Run with: dart test example/i18n_test.dart
library;

import 'package:gherkart/gherkart.dart';
import 'package:gherkart/gherkart_io.dart';
import 'package:test/test.dart';

var _total = 0;

final frenchMathSteps = StepRegistry<void>.fromMap({
  "J'ai le nombre {n}".mapper(types: {'n': int}): ($, ctx) async {
    _total = ctx.arg<int>(0);
  },
  "J'ajoute {n}".mapper(types: {'n': int}): ($, ctx) async {
    _total += ctx.arg<int>(0);
  },
  'le résultat est {expected}'.mapper(types: {'expected': int}): ($, ctx) async {
    expect(_total, ctx.arg<int>(0));
  },
});

Future<void> main() async {
  setUp(() {
    _total = 0;
  });

  await runBddTests<void>(
    rootPaths: ['example/features/i18n.feature'],
    registry: frenchMathSteps,
    source: FileSystemSource(),
    adapter: TestAdapter<void>(
      testFunction: _testFunction,
      group: group,
      setUpAll: setUpAll,
      tearDownAll: tearDownAll,
      fail: (message) => fail(message),
    ),
    structure: TestStructure.flat,
    output: const BddOutput.steps(),
  );
}

void _testFunction(String name, {List<String>? tags, bool skip = false, Future<void> Function(void)? callback}) {
  test(name, () => callback!(null), tags: tags, skip: skip);
}

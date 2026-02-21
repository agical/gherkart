// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/// Reporters and lifecycle hooks example.
///
/// Demonstrates:
/// - `SummaryReporter` — prints pass/fail/skip counts at the end
/// - `BddHooks` — `beforeAll`, `afterAll`, `beforeEach`, `afterEach`
/// - `TestStructure.tree` — groups nested by directory structure
///
/// Run with: dart test example/reporter_test.dart
library;

import 'package:gherkart/gherkart.dart';
import 'package:gherkart/gherkart_io.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Reuse the simple math steps
// ---------------------------------------------------------------------------

final _state = _State();

class _State {
  int number = 0;
}

final mathSteps = StepRegistry<void>.fromMap({
  'I have the number {n}'.mapper(types: {'n': int}): ($, ctx) async {
    _state.number = ctx.arg<int>(0);
  },
  'I add {n}'.mapper(types: {'n': int}): ($, ctx) async {
    _state.number += ctx.arg<int>(0);
  },
  'the result is {expected}'.mapper(types: {'expected': int}): ($, ctx) async {
    expect(_state.number, ctx.arg<int>(0));
  },
});

// ---------------------------------------------------------------------------
// Test runner with reporter and hooks
// ---------------------------------------------------------------------------

Future<void> main() async {
  setUp(() => _state.number = 0);

  final reporter = SummaryReporter(
    onSummary: (summary) {
      // Called after all features complete.
      // summary.featureCount, summary.scenarioPassed, etc.
    },
  );

  await runBddTests<void>(
    rootPaths: [
      'example/features/demo.feature',
      'example/features/background.feature',
    ],
    registry: mathSteps,
    source: FileSystemSource(),
    adapter: _createTestAdapter(),
    structure: TestStructure.tree,
    output: const BddOutput.scenarios(),
    reporter: reporter,
    hooks: BddHooks(
      beforeAll: () async {
        // One-time global setup (e.g. start a service).
      },
      afterAll: () async {
        // One-time global teardown.
      },
      beforeEach: (scenarioName, tags) async {
        // Runs before every scenario — reset shared state.
        _state.number = 0;
      },
      afterEach: (scenarioName, success, tags) async {
        // Runs after every scenario — log or clean up.
      },
    ),
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

// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/// Demo: basic scenarios, background steps, tags, and scenario outlines.
///
/// Covers: demo.feature, background.feature, tagged.feature, outline.feature
///
/// Run with: dart test example/demo_test.dart
library;

import 'package:gherkart/gherkart.dart';
import 'package:gherkart/gherkart_io.dart';
import 'package:test/test.dart';

/// Step registry mapping Gherkin steps to test functions.
///
/// The same three steps handle basic scenarios, background, tags,
/// and scenario outlines — all use simple math operations.
final mathSteps = StepRegistry<void>.fromMap({
  // Given steps
  'I have the number {n}'.mapper(types: {'n': int}): ($, ctx) async {
    _state.number = ctx.arg<int>(0);
  },

  // When steps
  'I add {n}'.mapper(types: {'n': int}): ($, ctx) async {
    _state.number += ctx.arg<int>(0);
  },

  // Then steps
  'the result is {expected}'.mapper(types: {'expected': int}): ($, ctx) async {
    expect(_state.number, ctx.arg<int>(0));
  },
});

/// Simple state holder for the demo.
final _state = _DemoState();

class _DemoState {
  int number = 0;
}

Future<void> main() async {
  setUp(() {
    _state.number = 0;
  });

  await runBddTests<void>(
    rootPaths: [
      'example/features/demo.feature',
      'example/features/background.feature',
      'example/features/tagged.feature',
      'example/features/outline.feature',
    ],
    registry: mathSteps,
    source: FileSystemSource(),
    adapter: _createTestAdapter(),
    structure: TestStructure.flat,
    output: const BddOutput.steps(),
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

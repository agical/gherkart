// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

// ============================================================================
// For more complete, runnable examples see the example/ directory on GitHub:
//   https://github.com/agical/gherkart/tree/main/example
// ============================================================================

/// Gherkart — a lightweight, runtime BDD framework for Flutter widget testing.
///
/// This file demonstrates the core API: parsing `.feature` files, defining
/// step functions, and running scenarios as ordinary Dart tests.
///
/// --------------------------------------------------------------------------
/// example/features/demo.feature
/// --------------------------------------------------------------------------
///
/// ```gherkin
/// Feature: BDD Framework Demo
///   A simple demo to verify the BDD framework works.
///
///   Scenario: Simple math
///     Given I have the number 5
///     When I add 3
///     Then the result is 8
/// ```
///
/// --------------------------------------------------------------------------
/// example/features/data_tables.feature
/// --------------------------------------------------------------------------
///
/// ```gherkin
/// Feature: Data Tables Demo
///   Demonstrates step-attached data tables.
///
///   Scenario: Add items from a table
///     Given I have an empty inventory
///     When I add items:
///       | name    | quantity |
///       | Apples  | 5        |
///       | Oranges | 3        |
///       | Bananas | 2        |
///     Then the total quantity is 10
/// ```
library;

import 'package:gherkart/gherkart.dart';
import 'package:gherkart/gherkart_io.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

int _number = 0;
final _inventory = <String, int>{};

// ---------------------------------------------------------------------------
// Step definitions — map Gherkin text to test functions
// ---------------------------------------------------------------------------

/// Steps for simple math scenarios.
final mathSteps = StepRegistry<void>.fromMap({
  'I have the number {n}'.mapper(types: {'n': int}): ($, ctx) async {
    _number = ctx.arg<int>(0);
  },
  'I add {n}'.mapper(types: {'n': int}): ($, ctx) async {
    _number += ctx.arg<int>(0);
  },
  'the result is {expected}'.mapper(types: {'expected': int}): ($, ctx) async {
    expect(_number, ctx.arg<int>(0));
  },
});

/// Steps for the data-tables scenario.
final inventorySteps = StepRegistry<void>.fromMap({
  'I have an empty inventory'.mapper(): ($, ctx) async {
    _inventory.clear();
  },
  'I add items:'.mapper(): ($, ctx) async {
    for (final row in ctx.tableRows) {
      final name = row['name']!;
      final qty = int.parse(row['quantity']!);
      _inventory[name] = (_inventory[name] ?? 0) + qty;
    }
  },
  'the total quantity is {n}'.mapper(types: {'n': int}): ($, ctx) async {
    final total = _inventory.values.fold(0, (sum, v) => sum + v);
    expect(total, ctx.arg<int>(0));
  },
});

// ---------------------------------------------------------------------------
// Test runner
// ---------------------------------------------------------------------------

Future<void> main() async {
  setUp(() {
    _number = 0;
    _inventory.clear();
  });

  // Merge separate registries into one — a core gherkart feature.
  final allSteps = mathSteps.merge(inventorySteps);

  await runBddTests<void>(
    rootPaths: [
      'example/features/demo.feature',
      'example/features/data_tables.feature',
    ],
    registry: allSteps,
    source: FileSystemSource(),
    adapter: _createTestAdapter(),
    output: const BddOutput.steps(),
  );
}

// ---------------------------------------------------------------------------
// Test adapter — bridges gherkart to package:test
// ---------------------------------------------------------------------------

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

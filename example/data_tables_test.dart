// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/// Data tables and doc strings example.
///
/// Demonstrates:
/// - Step-attached data tables accessed via `ctx.tableRows`
/// - Multi-line doc strings accessed via `ctx.docContent`
/// - Merging separate step registries with `registry.merge(other)`
///
/// Run with: dart test example/data_tables_test.dart
library;

import 'dart:convert';

import 'package:gherkart/gherkart.dart';
import 'package:gherkart/gherkart_io.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

final _inventory = <String, int>{};
final _config = <String, dynamic>{};

// ---------------------------------------------------------------------------
// Step registries — split into modules, then merged
// ---------------------------------------------------------------------------

/// Steps for the inventory / data-tables feature.
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

/// Steps for the configuration / doc-strings feature.
final configSteps = StepRegistry<void>.fromMap({
  'the configuration:'.mapper(): ($, ctx) async {
    _config
      ..clear()
      ..addAll((json.decode(ctx.docContent) as Map).cast<String, dynamic>());
  },
  'the theme is "{theme}"'.mapper(): ($, ctx) async {
    expect(_config['theme'], ctx.arg<String>(0));
  },
  'the font size is {size}'.mapper(types: {'size': int}): ($, ctx) async {
    expect(_config['fontSize'], ctx.arg<int>(0));
  },
});

// ---------------------------------------------------------------------------
// Test runner
// ---------------------------------------------------------------------------

Future<void> main() async {
  setUp(() {
    _inventory.clear();
    _config.clear();
  });

  // Merge two registries into one — a core gherkart feature.
  final allSteps = inventorySteps.merge(configSteps);

  await runBddTests<void>(
    rootPaths: [
      'example/features/data_tables.feature',
      'example/features/doc_strings.feature',
    ],
    registry: allSteps,
    source: FileSystemSource(),
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

// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cucumber_messages/cucumber_messages.dart' as cm;
import 'package:gherkart/gherkart.dart';
import 'package:gherkart/gherkart_io.dart';
import 'package:test/test.dart';

String _envelopeType(cm.Envelope e) {
  if (e.meta != null) return 'meta';
  if (e.source != null) return 'source';
  if (e.gherkinDocument != null) return 'gherkinDocument';
  if (e.pickle != null) return 'pickle';
  if (e.stepDefinition != null) return 'stepDefinition';
  if (e.hook != null) return 'hook';
  if (e.parameterType != null) return 'parameterType';
  if (e.testRunStarted != null) return 'testRunStarted';
  if (e.testCase != null) return 'testCase';
  if (e.testCaseStarted != null) return 'testCaseStarted';
  if (e.testStepStarted != null) return 'testStepStarted';
  if (e.testStepFinished != null) return 'testStepFinished';
  if (e.testCaseFinished != null) return 'testCaseFinished';
  if (e.testRunFinished != null) return 'testRunFinished';
  if (e.suggestion != null) return 'suggestion';
  if (e.attachment != null) return 'attachment';
  if (e.parseError != null) return 'parseError';
  return 'unknown';
}

Future<List<cm.Envelope>> _loadReferenceEnvelopes(String path) async {
  final raw = File(path).readAsStringSync();
  final lines = Stream<String>.fromIterable(const LineSplitter().convert(raw));
  return cm.decodeNdjsonEnvelopes(lines).toList();
}

Future<void> _noopCallback(void _) async {}

class _Flight {
  final String from;
  final String to;
  const _Flight(this.from, this.to);
}

/// Runs a CCK suite through [BddTestRunner] + [NdjsonReporter], round-trips the
/// serialized NDJSON output through `cucumber_messages` schema decoding, and
/// validates full Cucumber Messages protocol & CCK conformance against [referenceNdjsonPath].
Future<List<cm.Envelope>> _executeCckSample({
  required List<String> featurePaths,
  required StepRegistry<void> registry,
  BddHooks<void> hooks = const BddHooks(),
  bool checkMissingStepsUpfront = false,
}) async {
  var nextId = 0;
  var tick = 0;
  final ndjsonBuffer = StringBuffer();
  final reporter = NdjsonReporter(
    sink: ndjsonBuffer,
    idGenerator: () => 'cck-${nextId++}',
    clock: () => DateTime.fromMillisecondsSinceEpoch(tick++ * 10, isUtc: true),
  );

  final scheduledScenarios = <Future<void> Function()>[];
  FutureOr<void> Function()? scheduledSetUpAll;
  FutureOr<void> Function()? scheduledTearDownAll;

  final adapter = TestAdapter<void>(
    testFunction: (name, {tags, skip = false, callback = _noopCallback}) {
      if (!skip) {
        scheduledScenarios.add(() async {
          try {
            await callback(null);
          } catch (_) {
            // Expected for CCK samples exercising FAILED / UNDEFINED scenarios.
          }
        });
      }
    },
    group: (_, body) => body(),
    setUpAll: (fn) => scheduledSetUpAll = fn,
    tearDownAll: (fn) => scheduledTearDownAll = fn,
    fail: (msg) => throw StateError(msg),
  );

  await runBddTests<void>(
    rootPaths: featurePaths,
    registry: registry,
    adapter: adapter,
    source: FileSystemSource(),
    structure: TestStructure.flat,
    hooks: hooks,
    reporter: reporter,
    checkMissingStepsUpfront: checkMissingStepsUpfront,
  );

  if (scheduledSetUpAll != null) await scheduledSetUpAll!();
  for (final runScenario in scheduledScenarios) {
    await runScenario();
  }
  if (scheduledTearDownAll != null) await scheduledTearDownAll!();

  // Round-trip through cucumber_messages NDJSON decoder to enforce strict schema conformance!
  final serialized = ndjsonBuffer.toString();
  expect(serialized, isNotEmpty);
  final lines = Stream<String>.fromIterable(const LineSplitter().convert(serialized));
  return cm.decodeNdjsonEnvelopes(lines, includeLineInErrors: true).toList();
}

void _assertCckConformance(List<cm.Envelope> actual, List<cm.Envelope> expected, {required String suiteName}) {
  // 1. Exact envelope type sequence must match the CCK reference stream!
  final actualTypes = actual.map(_envelopeType).toList();
  final expectedTypes = expected.map(_envelopeType).toList();
  expect(actualTypes, equals(expectedTypes), reason: 'Envelope sequence mismatch in CCK suite "$suiteName"');

  // 2. Meta protocol version is present and matches our cucumber_messages schema version
  final actualMeta = actual.firstWhere((e) => e.meta != null).meta!;
  final expectedMeta = expected.firstWhere((e) => e.meta != null).meta!;
  expect(actualMeta.protocolVersion, NdjsonReporter.protocolVersion);
  expect(expectedMeta.protocolVersion, isNotEmpty);

  // 3. Pickles match names, steps, and tags
  final actualPickles = actual.where((e) => e.pickle != null).map((e) => e.pickle!).toList();
  final expectedPickles = expected.where((e) => e.pickle != null).map((e) => e.pickle!).toList();
  expect(actualPickles, hasLength(expectedPickles.length));
  for (var i = 0; i < expectedPickles.length; i++) {
    expect(actualPickles[i].name, expectedPickles[i].name);
    expect(actualPickles[i].steps.map((s) => s.text).toList(), expectedPickles[i].steps.map((s) => s.text).toList());
    expect(actualPickles[i].tags.map((t) => t.name).toList(), expectedPickles[i].tags.map((t) => t.name).toList());
  }

  // 4. Referential integrity across Pickle -> TestCase -> TestCaseStarted -> TestStep -> Finished
  final pickleById = {for (final p in actualPickles) p.id: p};
  final pickleStepIds = {
    for (final p in actualPickles)
      for (final s in p.steps) s.id,
  };
  final stepDefIds = {
    for (final e in actual)
      if (e.stepDefinition != null) e.stepDefinition!.id,
  };

  final actualRunStarted = actual.singleWhere((e) => e.testRunStarted != null).testRunStarted!;
  final actualRunFinished = actual.singleWhere((e) => e.testRunFinished != null).testRunFinished!;
  final expectedRunFinished = expected.singleWhere((e) => e.testRunFinished != null).testRunFinished!;

  expect(actualRunFinished.testRunStartedId, actualRunStarted.id);
  expect(
    actualRunFinished.success,
    expectedRunFinished.success,
    reason: 'TestRunFinished.success mismatch in CCK suite "$suiteName"',
  );

  final actualTestCases = actual.where((e) => e.testCase != null).map((e) => e.testCase!).toList();
  final expectedTestCases = expected.where((e) => e.testCase != null).map((e) => e.testCase!).toList();
  expect(actualTestCases, hasLength(expectedTestCases.length));

  final testCaseById = <String, cm.TestCase>{};
  final testStepById = <String, cm.TestStep>{};
  for (var i = 0; i < actualTestCases.length; i++) {
    final tc = actualTestCases[i];
    final expTc = expectedTestCases[i];
    expect(pickleById.containsKey(tc.pickleId), isTrue);
    expect(tc.testRunStartedId, actualRunStarted.id);
    expect(tc.testSteps, hasLength(expTc.testSteps.length));
    testCaseById[tc.id] = tc;

    for (var s = 0; s < tc.testSteps.length; s++) {
      final ts = tc.testSteps[s];
      final expTs = expTc.testSteps[s];
      testStepById[ts.id] = ts;
      if (ts.pickleStepId != null) {
        expect(pickleStepIds.contains(ts.pickleStepId), isTrue);
      }
      expect(
        ts.stepDefinitionIds?.length ?? 0,
        expTs.stepDefinitionIds?.length ?? 0,
        reason: 'stepDefinitionIds count mismatch on TestCase #$i step #$s in "$suiteName"',
      );
      for (final defId in ts.stepDefinitionIds ?? const <String>[]) {
        expect(stepDefIds.contains(defId), isTrue);
      }
    }
  }

  // 5. Step result statuses match CCK reference step-for-step!
  final actualStepResults = actual
      .where((e) => e.testStepFinished != null)
      .map((e) => e.testStepFinished!.testStepResult.status)
      .toList();
  final expectedStepResults = expected
      .where((e) => e.testStepFinished != null)
      .map((e) => e.testStepFinished!.testStepResult.status)
      .toList();
  expect(
    actualStepResults,
    equals(expectedStepResults),
    reason: 'TestStepFinished statuses mismatch in CCK suite "$suiteName"',
  );

  // Verify every TestCaseStarted/Finished and TestStepStarted/Finished links to valid IDs
  final startedCaseIds = <String>{};
  for (final e in actual) {
    if (e.testCaseStarted != null) {
      expect(testCaseById.containsKey(e.testCaseStarted!.testCaseId), isTrue);
      startedCaseIds.add(e.testCaseStarted!.id);
    }
    if (e.testStepStarted != null) {
      expect(startedCaseIds.contains(e.testStepStarted!.testCaseStartedId), isTrue);
      expect(testStepById.containsKey(e.testStepStarted!.testStepId), isTrue);
    }
    if (e.testStepFinished != null) {
      expect(startedCaseIds.contains(e.testStepFinished!.testCaseStartedId), isTrue);
      expect(testStepById.containsKey(e.testStepFinished!.testStepId), isTrue);
    }
    if (e.testCaseFinished != null) {
      expect(startedCaseIds.contains(e.testCaseFinished!.testCaseStartedId), isTrue);
    }
    if (e.suggestion != null) {
      expect(pickleStepIds.contains(e.suggestion!.pickleStepId), isTrue);
      expect(e.suggestion!.snippets, isNotEmpty);
    }
  }
}

void main() {
  group('Official Cucumber Compatibility Kit (CCK) — NdjsonReporter Conformance', () {
    test('minimal', () async {
      final registry = StepRegistry<void>.fromMap({
        'I have {count} cukes in my belly'.mapper(types: {'count': int}): (_, _) async {},
      });

      final actual = await _executeCckSample(
        featurePaths: ['test/compliance/cck/minimal/minimal.feature'],
        registry: registry,
      );
      final expected = await _loadReferenceEnvelopes('test/compliance/cck/minimal/minimal.ndjson');
      _assertCckConformance(actual, expected, suiteName: 'minimal');

      // Also verify exact StepMatchArgument character offset & parameter type from minimal.ndjson!
      final tc = actual.singleWhere((e) => e.testCase != null).testCase!;
      final arg = tc.testSteps.single.stepMatchArgumentsLists!.single.stepMatchArguments.single;
      expect(arg.group.start, 7);
      expect(arg.group.value, '42');
      expect(arg.parameterTypeName, 'int');
    });

    test('backgrounds', () async {
      final registry = StepRegistry<void>.fromMap({
        'an order for "{item}"'.mapper(): (_, _) async {},
        'an action'.mapper(): (_, _) async {},
        'an outcome'.mapper(): (_, _) async {},
      });

      final actual = await _executeCckSample(
        featurePaths: ['test/compliance/cck/backgrounds/backgrounds.feature'],
        registry: registry,
      );
      final expected = await _loadReferenceEnvelopes('test/compliance/cck/backgrounds/backgrounds.ndjson');
      _assertCckConformance(actual, expected, suiteName: 'backgrounds');
    });

    test('rules', () async {
      var money = 0;
      var stock = <String>[];
      String? chocolate;

      final registry = StepRegistry<void>.fromMap({
        'the customer has {cents} cents'.mapper(types: {'cents': int}): (_, ctx) async {
          money = ctx.arg<int>(0);
        },
        'there are chocolate bars in stock'.mapper(): (_, _) async {
          stock = ['Mars'];
        },
        'there are no chocolate bars in stock'.mapper(): (_, _) async {
          stock = [];
        },
        'the customer tries to buy a {price} cent chocolate bar'.mapper(types: {'price': int}): (_, ctx) async {
          final price = ctx.arg<int>(0);
          if (money >= price && stock.isNotEmpty) {
            chocolate = stock.removeLast();
          }
        },
        'the sale should not happen'.mapper(): (_, _) async {
          expect(chocolate, isNull);
        },
        'the sale should happen'.mapper(): (_, _) async {
          expect(chocolate, isNotNull);
        },
      });

      final actual = await _executeCckSample(
        featurePaths: ['test/compliance/cck/rules/rules.feature'],
        registry: registry,
        hooks: BddHooks<void>(
          beforeEach: (_, _) {
            money = 0;
            stock = [];
            chocolate = null;
          },
        ),
      );
      final expected = await _loadReferenceEnvelopes('test/compliance/cck/rules/rules.ndjson');
      _assertCckConformance(actual, expected, suiteName: 'rules');
    });

    test('rules-backgrounds', () async {
      final registry = StepRegistry<void>.fromMap({
        'an order for "{item}"'.mapper(): (_, _) async {},
        'an action'.mapper(): (_, _) async {},
        'an outcome'.mapper(): (_, _) async {},
      });

      final actual = await _executeCckSample(
        featurePaths: ['test/compliance/cck/rules-backgrounds/rules-backgrounds.feature'],
        registry: registry,
      );
      final expected = await _loadReferenceEnvelopes('test/compliance/cck/rules-backgrounds/rules-backgrounds.ndjson');
      _assertCckConformance(actual, expected, suiteName: 'rules-backgrounds');
    });

    test('examples-tables (mixed passing & failing outline rows + parameterized outline title)', () async {
      var count = 0;
      var friends = 0;

      final registry = StepRegistry<void>.fromMap({
        'there are {n} cucumbers'.mapper(types: {'n': int}): (_, ctx) async {
          count = ctx.arg<int>(0);
        },
        'there are {n} friends'.mapper(types: {'n': int}): (_, ctx) async {
          friends = ctx.arg<int>(0);
        },
        'I eat {n} cucumbers'.mapper(types: {'n': int}): (_, ctx) async {
          count -= ctx.arg<int>(0);
        },
        'I should have {n} cucumbers'.mapper(types: {'n': int}): (_, ctx) async {
          expect(count, ctx.arg<int>(0));
        },
        'each person can eat {n} cucumbers'.mapper(types: {'n': int}): (_, ctx) async {
          final share = (count / (1 + friends)).floor();
          expect(share, ctx.arg<int>(0));
        },
      });

      final actual = await _executeCckSample(
        featurePaths: ['test/compliance/cck/examples-tables/examples-tables.feature'],
        registry: registry,
        hooks: BddHooks<void>(
          beforeEach: (_, _) {
            count = 0;
            friends = 0;
          },
        ),
      );
      final expected = await _loadReferenceEnvelopes('test/compliance/cck/examples-tables/examples-tables.ndjson');
      _assertCckConformance(actual, expected, suiteName: 'examples-tables');
    });

    test('data-tables', () async {
      List<List<String>>? transposed;

      final registry = StepRegistry<void>.fromMap({
        'the following table is transposed:'.mapper(): (_, ctx) async {
          final raw = ctx.table!.allRows;
          final rows = raw.length;
          final cols = raw.first.length;
          transposed = List.generate(cols, (c) => List.generate(rows, (r) => raw[r][c]));
        },
        'it should be:'.mapper(): (_, ctx) async {
          expect(transposed, equals(ctx.table!.allRows));
        },
      });

      final actual = await _executeCckSample(
        featurePaths: ['test/compliance/cck/data-tables/data-tables.feature'],
        registry: registry,
      );
      final expected = await _loadReferenceEnvelopes('test/compliance/cck/data-tables/data-tables.ndjson');
      _assertCckConformance(actual, expected, suiteName: 'data-tables');
    });

    test('doc-strings', () async {
      final registry = StepRegistry<void>.fromMap({
        'a doc string:'.mapper(): (_, ctx) async {
          expect(ctx.hasDocString, isTrue);
        },
      });

      final actual = await _executeCckSample(
        featurePaths: ['test/compliance/cck/doc-strings/doc-strings.feature'],
        registry: registry,
      );
      final expected = await _loadReferenceEnvelopes('test/compliance/cck/doc-strings/doc-strings.ndjson');
      _assertCckConformance(actual, expected, suiteName: 'doc-strings');
    });

    test('empty', () async {
      final actual = await _executeCckSample(
        featurePaths: ['test/compliance/cck/empty/empty.feature'],
        registry: StepRegistry<void>(),
      );
      final expected = await _loadReferenceEnvelopes('test/compliance/cck/empty/empty.ndjson');
      _assertCckConformance(actual, expected, suiteName: 'empty');
    });

    test('skipped (dynamic runtime step skipping)', () async {
      final registry = StepRegistry<void>.fromMap({
        'a step that does not skip'.mapper(): (_, _) async {},
        'a step that is skipped'.mapper(): (_, _) async {},
        'I skip a step'.mapper(): (_, _) async {
          throw const SkipScenarioException('skipped by step');
        },
      });

      final actual = await _executeCckSample(
        featurePaths: ['test/compliance/cck/skipped/skipped.feature'],
        registry: registry,
      );
      final expected = await _loadReferenceEnvelopes('test/compliance/cck/skipped/skipped.ndjson');
      _assertCckConformance(actual, expected, suiteName: 'skipped');
    });

    test('undefined (undefined steps, Suggestion snippets, and subsequent SKIPPED steps)', () async {
      final registry = StepRegistry<void>.fromMap({
        'an implemented step'.mapper(): (_, _) async {},
        'a step that will be skipped'.mapper(): (_, _) async {},
      });

      final actual = await _executeCckSample(
        featurePaths: ['test/compliance/cck/undefined/undefined.feature'],
        registry: registry,
        checkMissingStepsUpfront: false,
      );
      final expected = await _loadReferenceEnvelopes('test/compliance/cck/undefined/undefined.ndjson');
      _assertCckConformance(actual, expected, suiteName: 'undefined');
    });

    test('multiple-features', () async {
      final registry = StepRegistry<void>.fromMap({'an order for "{item}"'.mapper(): (_, _) async {}});

      final actual = await _executeCckSample(
        featurePaths: ['test/compliance/cck/multiple-features'],
        registry: registry,
      );
      final expected = await _loadReferenceEnvelopes('test/compliance/cck/multiple-features/multiple-features.ndjson');
      _assertCckConformance(actual, expected, suiteName: 'multiple-features');
    });

    test('parameter-types (custom ParameterType + nested StepMatchArgument groups)', () async {
      final registry = StepRegistry<void>()
        ..defineParameterType(
          ParameterType<_Flight>(
            'flight',
            RegExp(r'([A-Z]{3})-([A-Z]{3})'),
            'Flight',
            (groups) => _Flight(groups[0]!, groups[1]!),
          ),
        )
        ..given('{flight} has been delayed', (_, ctx) async {
          final flight = ctx.arg<_Flight>(0);
          expect(flight.from, 'LHR');
          expect(flight.to, 'CDG');
        });

      final actual = await _executeCckSample(
        featurePaths: ['test/compliance/cck/parameter-types/parameter-types.feature'],
        registry: registry,
      );
      final expected = await _loadReferenceEnvelopes('test/compliance/cck/parameter-types/parameter-types.ndjson');
      _assertCckConformance(actual, expected, suiteName: 'parameter-types');

      final paramTypeMsg = actual.singleWhere((e) => e.parameterType != null).parameterType!;
      expect(paramTypeMsg.name, 'flight');
      expect(paramTypeMsg.regularExpressions, ['([A-Z]{3})-([A-Z]{3})']);

      final tc = actual.singleWhere((e) => e.testCase != null).testCase!;
      final arg = tc.testSteps.single.stepMatchArgumentsLists!.single.stepMatchArguments.single;
      expect(arg.parameterTypeName, 'flight');
      expect(arg.group.start, 0);
      expect(arg.group.value, 'LHR-CDG');
      expect(arg.group.children, hasLength(2));
      expect(arg.group.children![0].start, 0);
      expect(arg.group.children![0].value, 'LHR');
      expect(arg.group.children![1].start, 4);
      expect(arg.group.children![1].value, 'CDG');
    });

    test('regular-expression (RegExp step definition with optional capture groups)', () async {
      final captured = <List<String?>>[];
      final registry = StepRegistry<void>()
        ..regex(RegExp(r'^a (.*?)(?: and a (.*?))?(?: and a (.*?))?$'), (_, ctx) async {
          captured.add(ctx.args.cast<String?>());
        });

      final actual = await _executeCckSample(
        featurePaths: ['test/compliance/cck/regular-expression/regular-expression.feature'],
        registry: registry,
      );
      final expected = await _loadReferenceEnvelopes(
        'test/compliance/cck/regular-expression/regular-expression.ndjson',
      );
      _assertCckConformance(actual, expected, suiteName: 'regular-expression');

      final stepDef = actual.singleWhere((e) => e.stepDefinition != null).stepDefinition!;
      expect(stepDef.pattern.type, cm.StepDefinitionPatternType.regularExpression);
      expect(captured, [
        ['cucumber', null, null],
        ['cucumber', 'zucchini', null],
        ['cucumber', 'zucchini', 'gourd'],
      ]);
    });

    test('data-tables-with-expression (Cucumber Expression {string} + DataTable)', () async {
      final registry = StepRegistry<void>()
        ..given('a {string} with a table', (_, ctx) async {
          expect(ctx.arg<String>(0), 'Cucumber');
          expect(ctx.table!.allRows, [
            ['Species', 'Cucumis sativus'],
          ]);
        });

      final actual = await _executeCckSample(
        featurePaths: ['test/compliance/cck/data-tables-with-expression/data-tables-with-expression.feature'],
        registry: registry,
      );
      final expected = await _loadReferenceEnvelopes(
        'test/compliance/cck/data-tables-with-expression/data-tables-with-expression.ndjson',
      );
      _assertCckConformance(actual, expected, suiteName: 'data-tables-with-expression');
    });

    test('doc-strings-with-expression (Cucumber Expression {string} + DocString)', () async {
      final registry = StepRegistry<void>()
        ..given('a {string} with a doc string:', (_, ctx) async {
          expect(ctx.arg<String>(0), 'Cucumber');
          expect(ctx.docContent, 'Cucumis sativus');
        });

      final actual = await _executeCckSample(
        featurePaths: ['test/compliance/cck/doc-strings-with-expression/doc-strings-with-expression.feature'],
        registry: registry,
      );
      final expected = await _loadReferenceEnvelopes(
        'test/compliance/cck/doc-strings-with-expression/doc-strings-with-expression.ndjson',
      );
      _assertCckConformance(actual, expected, suiteName: 'doc-strings-with-expression');
    });
  });
}

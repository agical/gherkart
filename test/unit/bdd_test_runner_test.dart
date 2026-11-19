// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:gherkart/gherkart.dart';
import 'package:test/test.dart';

Future<void> _defaultCallback(void _) async {}

TestAdapter<void> _createRecordingAdapter({
  required Map<String, Future<void> Function()> runnableTests,
  void Function(String msg)? onFail,
}) {
  return TestAdapter<void>(
    testFunction: (name, {tags, skip = false, callback = _defaultCallback}) {
      runnableTests[name] = () => callback(null);
    },
    group: (_, body) => body(),
    setUpAll: (_) {},
    tearDownAll: (_) {},
    fail: (msg) {
      if (onFail != null) onFail(msg);
      throw Exception(msg);
    },
  );
}

void main() {
  group('BddTestRunner integration with standard Gherkin features', () {
    test('executes Rule: with correct order: feature background -> rule background -> scenario steps', () async {
      final executionOrder = <String>[];

      final registry = StepRegistry<void>.fromMap({
        'feature background step'.mapper(): (_, __) async {
          executionOrder.add('feature_bg');
        },
        'rule background step'.mapper(): (_, __) async {
          executionOrder.add('rule_bg');
        },
        'first action'.mapper(): (_, __) async {
          executionOrder.add('action_1');
        },
        'outcome verified'.mapper(): (_, __) async {
          executionOrder.add('outcome');
        },
      });

      const featureContent = '''
Feature: Rule Execution Order
  Background:
    Given feature background step

  Rule: User authorization rule
    Background:
      Given rule background step

    Scenario: Authorized action
      When first action
      Then outcome verified
''';

      final source = AssetSource.fromMap({'rules/order.feature': featureContent});
      final runnableTests = <String, Future<void> Function()>{};
      final adapter = _createRecordingAdapter(runnableTests: runnableTests);

      final runner = BddTestRunner<void>(
        rootPaths: ['rules/order.feature'],
        registry: registry,
        adapter: adapter,
        source: source,
        structure: TestStructure.flat,
      );

      await runner.run();

      expect(runnableTests.keys, contains('Authorized action'));
      await runnableTests['Authorized action']!();

      expect(executionOrder, ['feature_bg', 'rule_bg', 'action_1', 'outcome']);
    });

    test('executes Scenario Outline with legacy {param} syntax and passes arguments to steps', () async {
      final receivedParams = <String>[];

      final registry = StepRegistry<void>.fromMap({
        'I enter {user} and {password}'.mapper(): (_, ctx) async {
          receivedParams.add('${ctx.arg<String>(0)}:${ctx.arg<String>(1)}');
        },
        'status is {status}'.mapper(): (_, ctx) async {
          receivedParams.add(ctx.arg<String>(0));
        },
      });

      const featureContent = '''
Feature: Legacy Outline
  Scenario Outline: Login test
    When I enter {user} and {password}
    Then status is {status}

    Examples:
      | user  | password | status  |
      | alice | secret1  | success |
      | bob   | wrong    | failure |
''';

      final source = AssetSource.fromMap({'login.feature': featureContent});
      final runnableTests = <String, Future<void> Function()>{};
      final adapter = _createRecordingAdapter(runnableTests: runnableTests);

      final runner = BddTestRunner<void>(
        rootPaths: ['login.feature'],
        registry: registry,
        adapter: adapter,
        source: source,
        structure: TestStructure.flat,
      );

      await runner.run();

      expect(runnableTests.length, 2);
      expect(runnableTests.keys, contains('Login test (Example 1)'));
      expect(runnableTests.keys, contains('Login test (Example 2)'));

      await runnableTests['Login test (Example 1)']!();
      expect(receivedParams, ['alice:secret1', 'success']);

      await runnableTests['Login test (Example 2)']!();
      expect(receivedParams, ['alice:secret1', 'success', 'bob:wrong', 'failure']);
    });

    test('executes Scenario Outline with standard <param> syntax and passes arguments to steps', () async {
      final captured = <int>[];

      final registry = StepRegistry<void>.fromMap({
        'value is {n}'.mapper(types: {'n': int}): (_, ctx) async {
          captured.add(ctx.arg<int>(0));
        },
        'result is {n}'.mapper(types: {'n': int}): (_, ctx) async {
          captured.add(ctx.arg<int>(0));
        },
      });

      const featureContent = '''
Feature: Standard Outline
  Scenario Outline: Calculation
    Given value is <a>
    Then result is <sum>

    Examples: Numbers
      | a  | sum |
      | 10 | 20  |
''';

      final source = AssetSource.fromMap({'calc.feature': featureContent});
      final runnableTests = <String, Future<void> Function()>{};
      final adapter = _createRecordingAdapter(runnableTests: runnableTests);

      final runner = BddTestRunner<void>(
        rootPaths: ['calc.feature'],
        registry: registry,
        adapter: adapter,
        source: source,
        structure: TestStructure.flat,
      );

      await runner.run();

      expect(runnableTests.keys, contains('Calculation (Numbers #1)'));
      await runnableTests['Calculation (Numbers #1)']!();

      expect(captured, [10, 20]);
    });

    test('executes bullet (*) steps mixed with Given, When, Then', () async {
      final bulletStepsRun = <String>[];

      final registry = StepRegistry<void>.fromMap({
        'setup database'.mapper(): (_, __) async {
          bulletStepsRun.add('setup');
        },
        'send request'.mapper(): (_, __) async {
          bulletStepsRun.add('send');
        },
        'receive 200 ok'.mapper(): (_, __) async {
          bulletStepsRun.add('200');
        },
        'cleanup resources'.mapper(): (_, __) async {
          bulletStepsRun.add('cleanup');
        },
      });

      const featureContent = '''
Feature: Bullet Steps
  Background:
    * setup database

  Scenario: Mixed bullets and keywords
    When send request
    * receive 200 ok
    * cleanup resources
''';

      final source = AssetSource.fromMap({'bullet.feature': featureContent});
      final runnableTests = <String, Future<void> Function()>{};
      final adapter = _createRecordingAdapter(runnableTests: runnableTests);

      final runner = BddTestRunner<void>(
        rootPaths: ['bullet.feature'],
        registry: registry,
        adapter: adapter,
        source: source,
        structure: TestStructure.flat,
      );

      await runner.run();
      await runnableTests['Mixed bullets and keywords']!();

      expect(bulletStepsRun, ['setup', 'send', '200', 'cleanup']);
    });

    test('executes Example: keyword as synonym for Scenario', () async {
      var exampleExecuted = false;

      final registry = StepRegistry<void>.fromMap({
        'an example step'.mapper(): (_, __) async {
          exampleExecuted = true;
        },
      });

      const featureContent = '''
Feature: Example Synonym
  Example: Demonstrate example keyword
    Given an example step
''';

      final source = AssetSource.fromMap({'example.feature': featureContent});
      final runnableTests = <String, Future<void> Function()>{};
      final adapter = _createRecordingAdapter(runnableTests: runnableTests);

      final runner = BddTestRunner<void>(
        rootPaths: ['example.feature'],
        registry: registry,
        adapter: adapter,
        source: source,
        structure: TestStructure.flat,
      );

      await runner.run();
      await runnableTests['Demonstrate example keyword']!();

      expect(exampleExecuted, isTrue);
    });

    test('executes multi-language Gherkin in German (# language: de)', () async {
      final deStepsRun = <String>[];

      final registry = StepRegistry<void>.fromMap({
        'das System ist bereit'.mapper(): (_, __) async {
          deStepsRun.add('bereit');
        },
        'der Benutzer sich anmeldet'.mapper(): (_, __) async {
          deStepsRun.add('anmeldet');
        },
        'das Dashboard angezeigt wird'.mapper(): (_, __) async {
          deStepsRun.add('dashboard');
        },
      });

      const featureContent = '''
# language: de
Funktionalität: Deutsche Sprachtests
  Grundlage:
    Angenommen das System ist bereit

  Szenario: Anmeldung erfolgreich
    Wenn der Benutzer sich anmeldet
    Dann das Dashboard angezeigt wird
''';

      final source = AssetSource.fromMap({'de.feature': featureContent});
      final runnableTests = <String, Future<void> Function()>{};
      final adapter = _createRecordingAdapter(runnableTests: runnableTests);

      final runner = BddTestRunner<void>(
        rootPaths: ['de.feature'],
        registry: registry,
        adapter: adapter,
        source: source,
        structure: TestStructure.flat,
      );

      await runner.run();
      await runnableTests['Anmeldung erfolgreich']!();

      expect(deStepsRun, ['bereit', 'anmeldet', 'dashboard']);
    });

    test('executes multi-language Gherkin in Swedish (# language: sv)', () async {
      final svStepsRun = <String>[];

      final registry = StepRegistry<void>.fromMap({
        'att användaren är inloggad'.mapper(): (_, __) async {
          svStepsRun.add('inloggad');
        },
        'användaren klickar på spara'.mapper(): (_, __) async {
          svStepsRun.add('spara');
        },
        'visas en bekräftelse'.mapper(): (_, __) async {
          svStepsRun.add('bekräftelse');
        },
      });

      const featureContent = '''
# language: sv
Egenskap: Svenska tester
  Scenario: Spara ändringar
    Givet att användaren är inloggad
    När användaren klickar på spara
    Så visas en bekräftelse
''';

      final source = AssetSource.fromMap({'sv.feature': featureContent});
      final runnableTests = <String, Future<void> Function()>{};
      final adapter = _createRecordingAdapter(runnableTests: runnableTests);

      final runner = BddTestRunner<void>(
        rootPaths: ['sv.feature'],
        registry: registry,
        adapter: adapter,
        source: source,
        structure: TestStructure.flat,
      );

      await runner.run();
      await runnableTests['Spara ändringar']!();

      expect(svStepsRun, ['inloggad', 'spara', 'bekräftelse']);
    });

    test('substitutes outline parameters in step DataTables and passes them to StepContext', () async {
      final tableData = <Map<String, String>>[];

      final registry = StepRegistry<void>.fromMap({
        'the following entries:'.mapper(): (_, ctx) async {
          tableData.addAll(ctx.tableRows);
        },
      });

      const featureContent = '''
Feature: Outline with Table
  Scenario Outline: Table outline test
    Given the following entries:
      | item   | count   |
      | <item> | <count> |

    Examples:
      | item  | count |
      | Apple | 3     |
''';

      final source = AssetSource.fromMap({'table_outline.feature': featureContent});
      final runnableTests = <String, Future<void> Function()>{};
      final adapter = _createRecordingAdapter(runnableTests: runnableTests);

      final runner = BddTestRunner<void>(
        rootPaths: ['table_outline.feature'],
        registry: registry,
        adapter: adapter,
        source: source,
        structure: TestStructure.flat,
      );

      await runner.run();
      await runnableTests['Table outline test (Example 1)']!();

      expect(tableData, [
        {'item': 'Apple', 'count': '3'},
      ]);
    });

    test('substitutes outline parameters in step DocStrings and passes them to StepContext', () async {
      String? capturedDoc;

      final registry = StepRegistry<void>.fromMap({
        'the payload:'.mapper(): (_, ctx) async {
          capturedDoc = ctx.docContent;
        },
      });

      const featureContent = '''
Feature: Outline with DocString
  Scenario Outline: Docstring outline test
    Given the payload:
      ```json
      {"target": "<target>"}
      ```

    Examples:
      | target     |
      | production |
''';

      final source = AssetSource.fromMap({'docstring_outline.feature': featureContent});
      final runnableTests = <String, Future<void> Function()>{};
      final adapter = _createRecordingAdapter(runnableTests: runnableTests);

      final runner = BddTestRunner<void>(
        rootPaths: ['docstring_outline.feature'],
        registry: registry,
        adapter: adapter,
        source: source,
        structure: TestStructure.flat,
      );

      await runner.run();
      await runnableTests['Docstring outline test (Example 1)']!();

      expect(capturedDoc, contains('"target": "production"'));
    });

    test('fails via adapter when step is missing in registered steps', () async {
      String? failureMessage;

      final registry = StepRegistry<void>(); // empty registry

      const featureContent = '''
Feature: Missing Step
  Scenario: Unregistered
    Given this step does not exist
''';

      final source = AssetSource.fromMap({'missing.feature': featureContent});
      final runnableTests = <String, Future<void> Function()>{};
      final adapter = _createRecordingAdapter(runnableTests: runnableTests, onFail: (msg) => failureMessage = msg);

      final runner = BddTestRunner<void>(
        rootPaths: ['missing.feature'],
        registry: registry,
        adapter: adapter,
        source: source,
        structure: TestStructure.flat,
      );

      await runner.run();
      expect(() async => await runnableTests['Unregistered']!(), throwsException);

      expect(failureMessage, contains('1 missing step(s)'));
      expect(failureMessage, contains('missing.feature:3:5: Given this step does not exist'));
    });

    test('reports missing feature files if rootPath has no matching files', () async {
      String? failureMessage;

      final source = AssetSource.fromMap({});
      final runnableTests = <String, Future<void> Function()>{};
      final adapter = _createRecordingAdapter(runnableTests: runnableTests, onFail: (msg) => failureMessage = msg);

      final runner = BddTestRunner<void>(
        rootPaths: ['nonexistent.feature'],
        registry: StepRegistry<void>(),
        adapter: adapter,
        source: source,
        structure: TestStructure.flat,
      );

      await runner.run();
      expect(() async => await runnableTests['No feature files found']!(), throwsException);

      expect(failureMessage, contains('No .feature files found'));
    });

    test('supports top-level runBddTests and BddTestRunner.singleRoot with SchemeResolver', () async {
      final resolvedValues = <String>[];

      final registry = StepRegistry<void>.fromMap({
        'I greet "{name}"'.mapper(): (_, ctx) async {
          resolvedValues.add(ctx.arg<String>(0));
        },
      });

      final resolver = SchemeResolver()..register('t', (key, params) async => 'Translated: $key');

      const featureContent = '''
Feature: Scheme Resolution in Runner
  Scenario: Resolving translation
    Given I greet "{t:hello}"
''';

      final source = AssetSource.fromMap({'scheme.feature': featureContent});
      final runnableTests = <String, Future<void> Function()>{};
      final adapter = _createRecordingAdapter(runnableTests: runnableTests);

      // Verify BddTestRunner.singleRoot convenience constructor
      final runner = BddTestRunner<void>.singleRoot(
        rootPath: 'scheme.feature',
        registry: registry,
        adapter: adapter,
        source: source,
        schemeResolver: resolver,
      );
      expect(runner.rootPaths, ['scheme.feature']);

      // Run via top-level runBddTests
      await runBddTests<void>(
        rootPaths: ['scheme.feature'],
        registry: registry,
        adapter: adapter,
        source: source,
        schemeResolver: resolver,
        structure: TestStructure.flat,
      );

      await runnableTests['Resolving translation']!();
      expect(resolvedValues, ['Translated: hello']);
    });

    test('executes lifecycle hooks: beforeAll, beforeEach, afterEach, afterAll', () async {
      final hookEvents = <String>[];

      FutureOr<void> Function()? recordedSetUpAll;
      FutureOr<void> Function()? recordedTearDownAll;
      Future<void> Function()? pendingTest;

      final adapter = TestAdapter<void>(
        testFunction: (name, {tags, skip = false, callback = _defaultCallback}) {
          pendingTest = () => callback(null);
        },
        group: (_, body) => body(),
        setUpAll: (fn) => recordedSetUpAll = fn,
        tearDownAll: (fn) => recordedTearDownAll = fn,
        fail: (msg) => throw Exception(msg),
      );

      final registry = StepRegistry<void>.fromMap({
        'a step'.mapper(): (_, __) async {
          hookEvents.add('step');
        },
      });

      final hooks = BddHooks<void>(
        beforeAll: () async => hookEvents.add('beforeAll'),
        afterAll: () async => hookEvents.add('afterAll'),
        beforeEach: (scenarioName, tags) async => hookEvents.add('beforeEach:$scenarioName'),
        afterEach: (scenarioName, success, tags) async => hookEvents.add('afterEach:$scenarioName'),
      );

      const featureContent = '''
Feature: Hooks Test
  Scenario: Hooked Scenario
    Given a step
''';

      final source = AssetSource.fromMap({'hooks.feature': featureContent});

      await runBddTests<void>(
        rootPaths: ['hooks.feature'],
        registry: registry,
        adapter: adapter,
        source: source,
        hooks: hooks,
        structure: TestStructure.flat,
      );

      if (recordedSetUpAll != null) await recordedSetUpAll!();
      if (pendingTest != null) await pendingTest!();
      if (recordedTearDownAll != null) await recordedTearDownAll!();

      expect(hookEvents, ['beforeAll', 'beforeEach:Hooked Scenario', 'step', 'afterEach:Hooked Scenario', 'afterAll']);
    });

    test('automatically skips scenarios tagged with @wip', () async {
      final skippedStatus = <String, bool>{};

      final adapter = TestAdapter<void>(
        testFunction: (name, {tags, skip = false, callback = _defaultCallback}) {
          skippedStatus[name] = skip;
        },
        group: (_, body) => body(),
        setUpAll: (_) {},
        tearDownAll: (_) {},
        fail: (msg) => throw Exception(msg),
      );

      const featureContent = '''
Feature: Tag Skipping
  @wip
  Scenario: Work in progress scenario
    Given step

  Scenario: Normal scenario
    Given step
''';

      final source = AssetSource.fromMap({'skip.feature': featureContent});

      await runBddTests<void>(
        rootPaths: ['skip.feature'],
        registry: StepRegistry<void>()..register('step'.mapper(), (_, __) async {}),
        adapter: adapter,
        source: source,
        structure: TestStructure.flat,
      );

      expect(skippedStatus['Work in progress scenario'], isTrue);
      expect(skippedStatus['Normal scenario'], isFalse);
    });

    test('routes events to BddReporter including passing and failing steps', () async {
      final events = <String>[];
      BufferedResults? completedResults;

      final reporter = BufferedReporter(
        onComplete: (results) {
          completedResults = results;
          events.add('report_flushed:${results.features.length}');
        },
      );

      FutureOr<void> Function()? recordedTearDownAll;
      final scenarioCallbacks = <Future<void> Function()>[];

      final adapter = TestAdapter<void>(
        testFunction: (name, {tags, skip = false, callback = _defaultCallback}) {
          scenarioCallbacks.add(() async {
            try {
              await callback(null);
            } catch (_) {}
          });
        },
        group: (_, body) => body(),
        setUpAll: (_) {},
        tearDownAll: (fn) => recordedTearDownAll = fn,
        fail: (msg) => throw Exception(msg),
      );

      final registry = StepRegistry<void>.fromMap({
        'pass step'.mapper(): (_, __) async {},
        'fail step'.mapper(): (_, __) async {
          throw Exception('Step failed intentionally');
        },
      });

      const featureContent = '''
Feature: Reporter Events
  Scenario: Pass scenario
    Given pass step

  Scenario: Fail scenario
    When fail step
''';

      final source = AssetSource.fromMap({'rep.feature': featureContent});

      await runBddTests<void>(
        rootPaths: ['rep.feature'],
        registry: registry,
        adapter: adapter,
        source: source,
        reporter: reporter,
        structure: TestStructure.flat,
      );

      // Execute the test scenarios
      for (final cb in scenarioCallbacks) {
        await cb();
      }

      if (recordedTearDownAll != null) await recordedTearDownAll!();

      expect(events, contains('report_flushed:1'));
      expect(completedResults, isNotNull);
      expect(completedResults!.features.length, 1);
      final feature = completedResults!.features.first;
      expect(feature.feature.name, 'Reporter Events');
      expect(feature.scenarios.length, 2);
      expect(feature.scenarios[0].scenario.name, 'Pass scenario');
      expect(feature.scenarios[0].result?.status, ScenarioStatus.passed);
      expect(feature.scenarios[1].scenario.name, 'Fail scenario');
      expect(feature.scenarios[1].result?.status, ScenarioStatus.failed);
    });
  });
}

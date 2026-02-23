// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'bdd_output.dart';
import 'bdd_reporter.dart';
import 'feature_parser.dart';
import 'feature_source.dart';
import 'feature_test_factory.dart';
import 'scheme_resolver.dart';
import 'step_registry.dart';

/// Configuration for hooks that run during test execution.
class BddHooks<T> {
  /// Called once before all tests.
  final FutureOr<void> Function()? beforeAll;

  /// Called once after all tests.
  final FutureOr<void> Function()? afterAll;

  /// Called before each scenario.
  final FutureOr<void> Function(String scenarioName, List<String> tags)? beforeEach;

  /// Called after each scenario.
  final FutureOr<void> Function(String scenarioName, bool success, List<String> tags)? afterEach;

  const BddHooks({
    this.beforeAll,
    this.afterAll,
    this.beforeEach,
    this.afterEach,
  });
}

/// Signature for the test function that creates a test case.
///
/// This allows plugging in different test frameworks:
/// - `patrolWidgetTest` for Patrol
/// - `testWidgets` for Flutter
/// - `test` for pure Dart
///
/// Parameters:
/// - [name]: The test case name (scenario name)
/// - [tags]: Optional tags for filtering
/// - [skip]: Whether to skip this test
/// - [callback]: The test body to execute
typedef TestFunction<T> = void Function(
  String name, {
  List<String>? tags,
  bool skip,
  Future<void> Function(T context) callback,
});

/// Signature for the group function that creates a test group.
typedef GroupFunction = void Function(String name, void Function() body);

/// Signature for setUpAll function.
typedef SetUpAllFunction = void Function(FutureOr<void> Function() body);

/// Signature for tearDownAll function.
typedef TearDownAllFunction = void Function(FutureOr<void> Function() body);

/// Signature for failing a test.
typedef FailFunction = Never Function(String message);

/// Test framework adapter for plugging in different test runners.
///
/// Example with Patrol:
/// ```dart
/// final adapter = TestAdapter<PatrolTester>(
///   testFunction: (name, {tags, skip = false, required callback}) {
///     patrolWidgetTest(name, tags: tags, skip: skip, ($) async => callback($));
///   },
///   group: group,
///   setUpAll: setUpAll,
///   tearDownAll: tearDownAll,
///   fail: fail,
/// );
/// ```
class TestAdapter<T> {
  final TestFunction<T> testFunction;
  final GroupFunction group;
  final SetUpAllFunction setUpAll;
  final TearDownAllFunction tearDownAll;
  final FailFunction fail;

  const TestAdapter({
    required this.testFunction,
    required this.group,
    required this.setUpAll,
    required this.tearDownAll,
    required this.fail,
  });
}

/// Runs BDD tests using a pluggable test framework.
///
/// Example with Patrol:
/// ```dart
/// void main() {
///   final adapter = TestAdapter<PatrolTester>(
///     testFunction: (name, {tags, skip = false, required callback}) {
///       patrolWidgetTest(name, tags: tags, skip: skip, ($) async => callback($));
///     },
///     group: group,
///     setUpAll: setUpAll,
///     tearDownAll: tearDownAll,
///     fail: fail,
///   );
///
///   BddTestRunner<PatrolTester>(
///     rootPaths: ['test/features'],
///     registry: stepRegistry,
///     adapter: adapter,
///     source: FileSystemSource(),
///   ).run();
/// }
/// ```
class BddTestRunner<T> {
  /// Set to true at compile time to run @wip tests: --dart-define=RUN_WIP=true
  static const _runWip = bool.fromEnvironment('RUN_WIP');

  /// Paths to search for .feature files. Can be directories or single files.
  final List<String> rootPaths;

  /// Step registry mapping step patterns to functions.
  final StepRegistry<T> registry;

  /// Test framework adapter.
  final TestAdapter<T> adapter;

  /// Source for reading feature files.
  final FeatureSource source;

  /// How to structure test groups.
  final TestStructure structure;

  /// Output verbosity configuration.
  final BddOutput output;

  /// Lifecycle hooks.
  final BddHooks<T> hooks;

  /// Optional scheme resolver for parameter value transformation.
  final SchemeResolver? schemeResolver;

  /// Optional reporter for collecting and outputting test results.
  final BddReporter? reporter;

  // Cache for features (loaded in setUpAll)
  List<Feature>? _features;
  TestPlan? _plan;

  // Current reporting context
  ReportScenario? _currentScenario;

  BddTestRunner({
    required this.rootPaths,
    required this.registry,
    required this.adapter,
    required this.source,
    this.structure = TestStructure.tree,
    this.output = BddOutput.none,
    this.hooks = const BddHooks(),
    this.schemeResolver,
    this.reporter,
  });

  /// Single root path convenience constructor.
  factory BddTestRunner.singleRoot({
    required String rootPath,
    required StepRegistry<T> registry,
    required TestAdapter<T> adapter,
    required FeatureSource source,
    TestStructure structure = TestStructure.tree,
    BddOutput output = BddOutput.none,
    BddHooks<T> hooks = const BddHooks(),
    SchemeResolver? schemeResolver,
  }) {
    return BddTestRunner(
      rootPaths: [rootPath],
      registry: registry,
      adapter: adapter,
      source: source,
      structure: structure,
      output: output,
      hooks: hooks,
      schemeResolver: schemeResolver,
      reporter: null,
    );
  }

  /// Discovers features and runs tests.
  ///
  /// This is the main entry point. It:
  /// 1. Discovers all .feature files asynchronously
  /// 2. Parses them into Feature objects
  /// 3. Builds a test plan
  /// 4. Runs the tests using the configured adapter
  ///
  /// Call this from an async main():
  /// ```dart
  /// void main() async {
  ///   await BddTestRunner(...).run();
  /// }
  /// ```
  Future<void> run() async {
    await _discoverAndBuildPlan();

    if (_plan == null || _plan!.groups.isEmpty) {
      adapter.testFunction(
        'No feature files found',
        callback: (_) async {
          adapter.fail('No .feature files found in: ${rootPaths.join(', ')}');
        },
      );
      return;
    }

    _runTestPlan(_plan!);
  }

  /// Async discovery and parsing of feature files.
  Future<void> _discoverAndBuildPlan() async {
    final filePaths = <String>[];
    for (final root in rootPaths) {
      final paths = await source.list(root);
      filePaths.addAll(paths);
    }

    if (filePaths.isEmpty) return;

    // Parse features in parallel for faster loading
    final futures = filePaths.map((path) async {
      final content = await source.read(path);
      return parseFeature(content, path);
    });
    _features = await Future.wait(futures);

    final factory = FeatureTestFactory<T>(
      rootPath: rootPaths.first,
      registry: registry,
      structure: structure,
    );

    _plan = factory.buildTestPlan(_features!);
  }

  void _runTestPlan(TestPlan plan) {
    if (hooks.beforeAll != null) {
      adapter.setUpAll(() async {
        await hooks.beforeAll!();
      });
    }

    // Always set up tearDownAll to flush reporter
    adapter.tearDownAll(() async {
      if (hooks.afterAll != null) {
        await hooks.afterAll!();
      }
      // Flush reporter at the end
      if (reporter != null) {
        reporter!.flush();
      }
    });

    for (var i = 0; i < plan.groups.length; i++) {
      final testGroup = plan.groups[i];
      final feature = _features != null && i < _features!.length ? _features![i] : null;
      _runGroup(testGroup, feature: feature);
    }
  }

  void _runGroup(TestGroup testGroup, {Feature? feature}) {
    adapter.group(testGroup.name, () {
      output.printFeature(testGroup.name);

      // Only report feature start for leaf groups (those with tests, not folder groups)
      ReportFeature? reportFeature;
      final isFeatureGroup = testGroup.tests.isNotEmpty;
      if (isFeatureGroup && feature != null && reporter != null) {
        reportFeature = ReportFeature(
          name: feature.name,
          path: feature.filePath,
          tags: feature.tags,
          sourceScenarios: feature.allScenarios,
        );
        reporter!.onFeatureStart(reportFeature);
      }

      // Run child groups (these are feature groups within a folder)
      // Find matching features for children by name
      for (final child in testGroup.children) {
        final childFeature = _features?.firstWhere(
          (f) => f.name == child.name,
          orElse: () => feature!,
        );
        _runGroup(child, feature: childFeature);
      }

      // Run test cases
      for (final testCase in testGroup.tests) {
        _runTestCase(testCase, testGroup.backgroundSteps, reportFeature);
      }

      // Note: Feature completion is reported in tearDownAll/flush
      // since individual tests may run in any order
    });
  }

  void _runTestCase(
    TestCase testCase,
    List<Step> backgroundSteps,
    ReportFeature? reportFeature,
  ) {
    // Check for @wip tag to skip work-in-progress tests (unless RUN_WIP=true)
    final shouldSkip = testCase.tags.contains('wip') && !_runWip;

    adapter.testFunction(
      testCase.name,
      tags: testCase.tags.isNotEmpty ? testCase.tags : null,
      skip: shouldSkip,
      callback: (context) async {
        output.printScenario(testCase.name);

        // Report scenario start
        if (reporter != null) {
          _currentScenario = ReportScenario(
            name: testCase.name,
            tags: testCase.tags,
            featurePath: reportFeature?.path,
          );
          reporter!.onScenarioStart(_currentScenario!);
        }

        // Check all steps upfront and report all missing at once
        final allSteps = [...backgroundSteps, ...testCase.steps];
        final missingSteps = <Step>[];
        for (final step in allSteps) {
          if (registry.match(step.text) == null) {
            missingSteps.add(step);
          }
        }
        if (missingSteps.isNotEmpty) {
          final errorLines = missingSteps.map((s) {
            final loc = s.location != null ? '${s.location}: ' : '';
            return '  - $loc${s.fullText}';
          }).join('\n');
          adapter.fail('${missingSteps.length} missing step(s):\n$errorLines');
        }

        var success = true;
        try {
          if (hooks.beforeEach != null) {
            await hooks.beforeEach!(testCase.name, testCase.tags);
          }

          // Run background steps first
          for (final step in backgroundSteps) {
            await _runStep(context, step);
          }

          // Run scenario steps
          for (final step in testCase.steps) {
            await _runStep(context, step);
          }
        } catch (e) {
          success = false;
          rethrow;
        } finally {
          // Report scenario end
          if (reporter != null && _currentScenario != null) {
            final result = success ? ScenarioResult.passed() : ScenarioResult.failed('Scenario failed');
            reporter!.onScenarioComplete(_currentScenario!, result);
          }
          if (hooks.afterEach != null) {
            await hooks.afterEach!(testCase.name, success, testCase.tags);
          }
        }
      },
    );
  }

  Future<void> _runStep(T context, Step step) async {
    final keyword = step.keyword.name[0].toUpperCase() + step.keyword.name.substring(1);
    final stopwatch = Stopwatch()..start();
    final locationInfo = step.location != null ? ' at ${step.location}' : '';

    // Report step start
    final reportStep = ReportStep(
      keyword: keyword,
      text: step.text,
      hasTable: step.dataTable != null,
      hasDocString: step.docString != null,
    );
    if (reporter != null) {
      reporter!.onStepStart(reportStep);
    }

    try {
      final match = registry.match(step.text);
      if (match == null) {
        output.printStepFailed(keyword, step.text);
        adapter.fail('Step not found: ${step.fullText}$locationInfo');
      }

      // Resolve parameter schemes if resolver is configured
      if (schemeResolver != null) {
        final resolved = await schemeResolver!.resolveAll(match.params);
        final resolvedParams = resolved.map((r) => r.resolved).toList();
        await match.execute(
          context,
          table: step.dataTable,
          docString: step.docString,
          location: step.location,
          resolvedArgs: resolvedParams,
        );
      } else {
        await match.execute(
          context,
          table: step.dataTable,
          docString: step.docString,
          location: step.location,
        );
      }

      stopwatch.stop();
      output.printStepComplete(keyword, step.text, stopwatch.elapsed);

      // Report step passed
      if (reporter != null) {
        final result = StepResult.passed(stopwatch.elapsed);
        reporter!.onStepComplete(reportStep, result);
      }
    } catch (e) {
      output.printStepFailed(keyword, step.text);

      // Report step failed
      if (reporter != null) {
        stopwatch.stop();
        final result = StepResult.failed(stopwatch.elapsed, e.toString());
        reporter!.onStepComplete(reportStep, result);
      }

      // Wrap failures with location info and rethrow
      adapter.fail('Step failed$locationInfo: ${step.fullText}\n$e');
    }
  }
}

/// Convenience function to run BDD tests with a pluggable test framework.
///
/// Example with Patrol:
/// ```dart
/// void main() async {
///   await runBddTests<PatrolTester>(
///     rootPaths: ['test/features'],
///     registry: myStepRegistry,
///     adapter: patrolAdapter,
///     source: FileSystemSource(),
///     output: BddOutput.steps(),
///   );
/// }
/// ```
Future<void> runBddTests<T>({
  required List<String> rootPaths,
  required StepRegistry<T> registry,
  required TestAdapter<T> adapter,
  required FeatureSource source,
  TestStructure structure = TestStructure.tree,
  BddOutput output = BddOutput.none,
  BddHooks<T> hooks = const BddHooks(),
  SchemeResolver? schemeResolver,
  BddReporter? reporter,
}) {
  return BddTestRunner<T>(
    rootPaths: rootPaths,
    registry: registry,
    adapter: adapter,
    source: source,
    structure: structure,
    output: output,
    hooks: hooks,
    schemeResolver: schemeResolver,
    reporter: reporter,
  ).run();
}

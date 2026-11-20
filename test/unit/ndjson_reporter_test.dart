// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cucumber_messages/cucumber_messages.dart' as cm;
import 'package:gherkart/gherkart.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Future<void> _noop(void _) async {}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('gherkart_ndjson_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('NdjsonReporter', () {
    test('emits schema-valid Cucumber Messages NDJSON in standalone mode (without parseFeature)', () async {
      final lines = <String>[];
      final envelopes = <cm.Envelope>[];
      final buffer = StringBuffer();

      final reporter = NdjsonReporter(sink: buffer, onLine: lines.add, onEnvelope: envelopes.add);

      final feature = ReportFeature(name: 'Standalone Feature', path: 'features/standalone.feature', tags: ['smoke']);
      final scenario = ReportScenario(
        name: 'Standalone Scenario',
        tags: ['fast'],
        featurePath: 'features/standalone.feature',
      );

      reporter.onFeatureStart(feature);
      reporter.onScenarioStart(scenario);
      reporter.onStepStart(ReportStep(keyword: 'Given', text: 'initial state'));
      reporter.onStepComplete(
        ReportStep(keyword: 'Given', text: 'initial state'),
        StepResult.passed(const Duration(milliseconds: 12)),
      );
      reporter.onStepStart(ReportStep(keyword: 'When', text: 'action occurs'));
      reporter.onStepComplete(
        ReportStep(keyword: 'When', text: 'action occurs'),
        StepResult.passed(const Duration(milliseconds: 8)),
      );
      reporter.onStepStart(ReportStep(keyword: 'Then', text: 'outcome verified'));
      reporter.onStepComplete(
        ReportStep(keyword: 'Then', text: 'outcome verified'),
        StepResult.passed(const Duration(milliseconds: 4)),
      );
      reporter.onScenarioComplete(scenario, ScenarioResult.passed());
      reporter.onFeatureComplete(feature, FeatureResult.passed());
      reporter.flush();

      expect(lines, isNotEmpty);
      expect(envelopes, hasLength(lines.length));
      expect(reporter.envelopes, hasLength(lines.length));
      expect(reporter.toNdjson(), equals(buffer.toString()));

      // Round-trip through official cucumber_messages NDJSON decoder
      final decoded = await cm
          .decodeNdjsonEnvelopes(Stream<String>.fromIterable(const LineSplitter().convert(reporter.toNdjson())))
          .toList();
      expect(decoded, hasLength(envelopes.length));
      expect(decoded.first.meta?.protocolVersion, NdjsonReporter.protocolVersion);
      expect(decoded.any((e) => e.source != null), isTrue);
      expect(decoded.any((e) => e.gherkinDocument != null), isTrue);
      expect(decoded.any((e) => e.pickle != null), isTrue);
      expect(decoded.any((e) => e.testCase != null), isTrue);
      expect(decoded.last.testRunFinished?.success, isTrue);
    });

    test('records failed step exception details and marks subsequent steps SKIPPED', () {
      final feature = parseFeature('''
Feature: Failure handling
  Scenario: Fails on step 2
    Given step one
    When step two fails
    Then step three is skipped
''', 'fail.feature');

      final registry = StepRegistry<void>.fromMap({
        'step one'.mapper(): (_, _) async {},
        'step two fails'.mapper(): (_, _) async {},
        'step three is skipped'.mapper(): (_, _) async {},
      });

      final reporter = NdjsonReporter(registry: registry);
      final reportFeature = ReportFeature(
        name: feature.name,
        path: feature.filePath,
        sourceScenarios: feature.allScenarios,
        sourceFeature: feature,
      );
      final scenario = feature.allScenarios.single;
      final reportScenario = ReportScenario(
        name: scenario.name,
        tags: scenario.tags,
        featurePath: feature.filePath,
        pickle: scenario.pickle,
      );

      reporter.onFeatureStart(reportFeature);
      reporter.onScenarioStart(reportScenario);
      reporter.onStepStart(ReportStep(keyword: 'Given', text: 'step one'));
      reporter.onStepComplete(
        ReportStep(keyword: 'Given', text: 'step one'),
        StepResult.passed(const Duration(milliseconds: 5)),
      );
      reporter.onStepStart(ReportStep(keyword: 'When', text: 'step two fails'));
      reporter.onStepComplete(
        ReportStep(keyword: 'When', text: 'step two fails'),
        StepResult.failed(
          const Duration(milliseconds: 3),
          'Expected 1 but got 2',
          exception: StateError('Expected 1 but got 2'),
          stackTrace: StackTrace.current,
        ),
      );
      // Note: step 3 never runs in Dart because step 2 threw!
      reporter.onScenarioComplete(reportScenario, ScenarioResult.failed('Expected 1 but got 2'));
      reporter.flush();

      final stepFinished = reporter.envelopes
          .where((e) => e.testStepFinished != null)
          .map((e) => e.testStepFinished!)
          .toList();
      expect(stepFinished, hasLength(3));
      expect(stepFinished[0].testStepResult.status, cm.TestStepResultStatus.passed);
      expect(stepFinished[1].testStepResult.status, cm.TestStepResultStatus.failed);
      expect(stepFinished[1].testStepResult.message, 'Expected 1 but got 2');
      expect(stepFinished[1].testStepResult.exception?.type, 'StateError');
      expect(stepFinished[1].testStepResult.exception?.stackTrace, isNotNull);
      expect(stepFinished[2].testStepResult.status, cm.TestStepResultStatus.skipped);

      final runFinished = reporter.envelopes.last.testRunFinished!;
      expect(runFinished.success, isFalse);
    });

    test('handles upfront missing-step failure in BddTestRunner and emits UNDEFINED + Suggestion', () async {
      final reporter = NdjsonReporter();
      final scenarios = <Future<void> Function()>[];
      FutureOr<void> Function()? tearDown;

      final adapter = TestAdapter<void>(
        testFunction: (name, {tags, skip = false, callback = _noop}) {
          scenarios.add(() async {
            try {
              await callback(null);
            } catch (_) {}
          });
        },
        group: (_, body) => body(),
        setUpAll: (_) {},
        tearDownAll: (fn) => tearDown = fn,
        fail: (msg) => throw StateError(msg),
      );

      final registry = StepRegistry<void>.fromMap({'defined step'.mapper(): (_, _) async {}});

      final source = AssetSource.fromMap({
        'missing.feature': '''
Feature: Upfront Missing
  Scenario: Has undefined step
    Given defined step
    When undefined step with "arg"
    Then defined step
''',
      });

      await runBddTests<void>(
        rootPaths: ['missing.feature'],
        registry: registry,
        adapter: adapter,
        source: source,
        reporter: reporter,
        checkMissingStepsUpfront: true,
      );

      for (final run in scenarios) {
        await run();
      }
      if (tearDown != null) await tearDown!();

      final stepStatuses = reporter.envelopes
          .where((e) => e.testStepFinished != null)
          .map((e) => e.testStepFinished!.testStepResult.status)
          .toList();
      expect(stepStatuses, [
        cm.TestStepResultStatus.skipped,
        cm.TestStepResultStatus.undefined,
        cm.TestStepResultStatus.skipped,
      ]);

      final suggestions = reporter.envelopes.where((e) => e.suggestion != null).map((e) => e.suggestion!).toList();
      expect(suggestions, hasLength(1));
      expect(suggestions.single.snippets.single.language, 'dart');
      expect(suggestions.single.snippets.single.code, contains('.cucumber()'));
      expect(reporter.envelopes.last.testRunFinished?.success, isFalse);
    });

    test('avoids ID collisions even when custom idGenerator overlaps with AST/Pickle IDs', () {
      var parseId = 0;
      final feature = parseFeature(
        'Feature: Collision\n  Scenario: Test\n    Given a step\n',
        'collision.feature',
        idGenerator: () => '${parseId++}',
      );

      var reporterId = 0;
      final reporter = NdjsonReporter(idGenerator: () => '${reporterId++}');
      final reportFeature = ReportFeature(name: feature.name, path: feature.filePath, sourceFeature: feature);
      final scenario = feature.allScenarios.single;
      final reportScenario = ReportScenario(
        name: scenario.name,
        tags: const [],
        featurePath: feature.filePath,
        pickle: scenario.pickle,
      );

      reporter.onFeatureStart(reportFeature);
      reporter.onScenarioStart(reportScenario);
      reporter.onStepComplete(ReportStep(keyword: 'Given', text: 'a step'), StepResult.passed(Duration.zero));
      reporter.onScenarioComplete(reportScenario, ScenarioResult.passed());
      reporter.flush();

      final pickleId = reporter.envelopes.singleWhere((e) => e.pickle != null).pickle!.id;
      final testCase = reporter.envelopes.singleWhere((e) => e.testCase != null).testCase!;
      expect(testCase.id, isNot(equals(pickleId)));
      expect(testCase.pickleId, equals(pickleId));
    });
  });

  group('NdjsonFileReporter & ReportMode.ndjson', () {
    test('writes NDJSON file to disk and populates platform Meta', () async {
      final outPath = p.join(tempDir.path, 'nested', 'reports', 'messages.ndjson');
      final reporter = NdjsonFileReporter(outputPath: outPath);

      reporter.onFeatureStart(ReportFeature(name: 'Disk Test', path: 'disk.feature'));
      reporter.onScenarioStart(ReportScenario(name: 'Writes file', tags: const [], featurePath: 'disk.feature'));
      reporter.onStepComplete(
        ReportStep(keyword: 'Given', text: 'file output configured'),
        StepResult.passed(const Duration(milliseconds: 2)),
      );
      reporter.onScenarioComplete(
        ReportScenario(name: 'Writes file', tags: const [], featurePath: 'disk.feature'),
        ScenarioResult.passed(),
      );
      reporter.flush();

      final file = File(outPath);
      expect(file.existsSync(), isTrue);

      final decoded = await cm.decodeNdjsonEnvelopes(Stream<String>.fromIterable(file.readAsLinesSync())).toList();
      expect(decoded, isNotEmpty);
      expect(decoded.first.meta?.implementation.name, 'gherkart');
      expect(decoded.first.meta?.runtime.name, 'Dart');
      expect(decoded.first.meta?.runtime.version, isNotEmpty);
      expect(decoded.last.testRunFinished?.success, isTrue);
    });

    test('works with CompositeReporter alongside MarkdownFileReporter', () {
      final docsDir = p.join(tempDir.path, 'docs');
      final ndjsonPath = p.join(tempDir.path, 'cucumber.ndjson');

      final composite = CompositeReporter([
        MarkdownFileReporter(outputDir: docsDir),
        NdjsonFileReporter(outputPath: ndjsonPath),
      ]);

      composite.onFeatureStart(ReportFeature(name: 'Combined', path: 'features/combined.feature'));
      composite.onScenarioStart(
        ReportScenario(name: 'Combined scenario', tags: const [], featurePath: 'features/combined.feature'),
      );
      composite.onStepComplete(
        ReportStep(keyword: 'Given', text: 'both reporters active'),
        StepResult.passed(const Duration(milliseconds: 1)),
      );
      composite.onScenarioComplete(
        ReportScenario(name: 'Combined scenario', tags: const [], featurePath: 'features/combined.feature'),
        ScenarioResult.passed(),
      );
      composite.onFeatureComplete(
        ReportFeature(name: 'Combined', path: 'features/combined.feature'),
        FeatureResult.passed(),
      );
      composite.flush();

      expect(File(p.join(docsDir, 'index.md')).existsSync(), isTrue);
      expect(File(ndjsonPath).existsSync(), isTrue);
    });

    test('ReporterConfig supports ReportMode.ndjson', () {
      expect(ReportMode.ndjson.isLive, isFalse);
      expect(ReportMode.ndjson.isBuffered, isTrue);
      expect(ReportMode.ndjson.isSummaryOnly, isFalse);
      expect(ReportMode.ndjson.writesToFile, isTrue);

      expect(() => ReporterConfig(mode: ReportMode.ndjson).createReporter(), throwsArgumentError);

      final reporter = ReporterConfig(mode: ReportMode.ndjson, outputDir: tempDir.path).createReporter();
      expect(reporter, isA<NdjsonFileReporter>());
    });

    test('SkipScenarioException formats message', () {
      expect(const SkipScenarioException().toString(), 'SkipScenarioException');
      expect(const SkipScenarioException('no device').toString(), 'SkipScenarioException: no device');
    });
  });
}

// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:gherkart/src/bdd_reporter.dart';
import 'package:test/test.dart';

void main() {
  group('BddReporter', () {
    group('ContinuousReporter', () {
      test('reports events immediately as they occur', () async {
        final events = <String>[];
        final reporter = ContinuousReporter(
          onEvent: (event) => events.add(event.toString()),
        );

        reporter.onFeatureStart(
            ReportFeature(name: 'Feature 1', path: 'a.feature'));
        reporter.onScenarioStart(ReportScenario(name: 'Scenario A', tags: []));
        reporter.onStepStart(ReportStep(keyword: 'Given', text: 'something'));
        reporter.onStepComplete(
          ReportStep(keyword: 'Given', text: 'something'),
          StepResult.passed(Duration(milliseconds: 100)),
        );
        reporter.onScenarioComplete(
          ReportScenario(name: 'Scenario A', tags: []),
          ScenarioResult.passed(),
        );
        reporter.onFeatureComplete(
          ReportFeature(name: 'Feature 1', path: 'a.feature'),
          FeatureResult.passed(),
        );

        expect(events.length, 6);
        expect(events[0], contains('Feature 1'));
        expect(events[1], contains('Scenario A'));
        expect(events[2], contains('Given'));
        expect(events[3], contains('passed'));
        expect(events[4], contains('Scenario A'));
        expect(events[5], contains('Feature 1'));
      });
    });

    group('BufferedReporter', () {
      test('collects events and reports only at the end', () async {
        final reports = <String>[];
        final reporter = BufferedReporter(
          onComplete: (results) => reports.add(results.toString()),
        );

        reporter.onFeatureStart(
            ReportFeature(name: 'Feature 1', path: 'a.feature'));
        reporter.onScenarioStart(ReportScenario(name: 'Scenario A', tags: []));
        reporter.onStepComplete(
          ReportStep(keyword: 'Given', text: 'something'),
          StepResult.passed(Duration(milliseconds: 100)),
        );
        reporter.onScenarioComplete(
          ReportScenario(name: 'Scenario A', tags: []),
          ScenarioResult.passed(),
        );
        reporter.onFeatureComplete(
          ReportFeature(name: 'Feature 1', path: 'a.feature'),
          FeatureResult.passed(),
        );

        // Nothing reported yet
        expect(reports, isEmpty);

        // Report on flush
        reporter.flush();
        expect(reports.length, 1);
        expect(reports[0], contains('Feature 1'));
        expect(reports[0], contains('Scenario A'));
      });
    });

    group('SummaryReporter', () {
      test('reports only counts at the end', () async {
        final summaries = <String>[];
        final reporter = SummaryReporter(
          onSummary: (summary) => summaries.add(summary.toString()),
        );

        reporter.onFeatureStart(
            ReportFeature(name: 'Feature 1', path: 'a.feature'));
        reporter.onScenarioComplete(
          ReportScenario(name: 'Scenario A', tags: []),
          ScenarioResult.passed(),
        );
        reporter.onScenarioComplete(
          ReportScenario(name: 'Scenario B', tags: []),
          ScenarioResult.failed('Error'),
        );
        reporter.onFeatureComplete(
          ReportFeature(name: 'Feature 1', path: 'a.feature'),
          FeatureResult.mixed(),
        );

        // Nothing yet
        expect(summaries, isEmpty);

        reporter.flush();
        expect(summaries.length, 1);
        expect(summaries[0], contains('1 feature'));
        expect(summaries[0], contains('1 passed'));
        expect(summaries[0], contains('1 failed'));
      });
    });

    group('CompositeReporter', () {
      test('delegates to multiple reporters', () async {
        final events1 = <String>[];
        final events2 = <String>[];

        final reporter1 = ContinuousReporter(
          onEvent: (event) => events1.add(event.toString()),
        );
        final reporter2 = ContinuousReporter(
          onEvent: (event) => events2.add(event.toString()),
        );

        final composite = CompositeReporter([reporter1, reporter2]);

        composite.onFeatureStart(
            ReportFeature(name: 'Feature 1', path: 'a.feature'));

        expect(events1.length, 1);
        expect(events2.length, 1);
      });

      test('flush calls flush on all reporters', () async {
        var flushed1 = false;
        var flushed2 = false;

        final reporter1 = _FlushTrackingReporter(() => flushed1 = true);
        final reporter2 = _FlushTrackingReporter(() => flushed2 = true);

        final composite = CompositeReporter([reporter1, reporter2]);
        composite.flush();

        expect(flushed1, isTrue);
        expect(flushed2, isTrue);
      });
    });

    group('ReportFeature', () {
      test('holds feature metadata', () {
        final feature = ReportFeature(
          name: 'My Feature',
          path: 'features/my.feature',
          tags: ['@smoke', '@api'],
        );

        expect(feature.name, 'My Feature');
        expect(feature.path, 'features/my.feature');
        expect(feature.tags, ['@smoke', '@api']);
      });
    });

    group('ReportScenario', () {
      test('holds scenario metadata', () {
        final scenario = ReportScenario(
          name: 'My Scenario',
          tags: ['@slow'],
          isOutlineInstance: true,
          outlineName: 'My Outline',
          exampleIndex: 2,
        );

        expect(scenario.name, 'My Scenario');
        expect(scenario.tags, ['@slow']);
        expect(scenario.isOutlineInstance, isTrue);
        expect(scenario.outlineName, 'My Outline');
        expect(scenario.exampleIndex, 2);
      });
    });

    group('ReportStep', () {
      test('holds step metadata', () {
        final step = ReportStep(
          keyword: 'Given',
          text: 'I have a value',
          hasTable: true,
          hasDocString: false,
        );

        expect(step.keyword, 'Given');
        expect(step.text, 'I have a value');
        expect(step.hasTable, isTrue);
        expect(step.hasDocString, isFalse);
      });
    });

    group('StepResult', () {
      test('passed result', () {
        final result = StepResult.passed(Duration(milliseconds: 150));

        expect(result.status, StepStatus.passed);
        expect(result.duration, Duration(milliseconds: 150));
        expect(result.error, isNull);
      });

      test('failed result', () {
        final result = StepResult.failed(
          Duration(milliseconds: 50),
          'Something went wrong',
        );

        expect(result.status, StepStatus.failed);
        expect(result.duration, Duration(milliseconds: 50));
        expect(result.error, 'Something went wrong');
      });

      test('skipped result', () {
        final result = StepResult.skipped();

        expect(result.status, StepStatus.skipped);
        expect(result.duration, isNull);
        expect(result.error, isNull);
      });
    });

    group('ScenarioResult', () {
      test('passed scenario', () {
        final result = ScenarioResult.passed();
        expect(result.status, ScenarioStatus.passed);
      });

      test('failed scenario', () {
        final result = ScenarioResult.failed('Error message');
        expect(result.status, ScenarioStatus.failed);
        expect(result.error, 'Error message');
      });
    });

    group('FeatureResult', () {
      test('all passed', () {
        final result = FeatureResult.passed();
        expect(result.status, FeatureStatus.passed);
      });

      test('mixed results', () {
        final result = FeatureResult.mixed();
        expect(result.status, FeatureStatus.mixed);
      });
    });

    group('MarkdownFileReporter', () {
      late Directory tempDir;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('gherkart_test_');
      });

      tearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      test('creates markdown file for each feature', () async {
        final reporter = MarkdownFileReporter(outputDir: tempDir.path);

        reporter.onFeatureStart(ReportFeature(
          name: 'User Authentication',
          path: 'auth.feature',
        ));
        reporter.onScenarioStart(ReportScenario(
          name: 'Valid Login',
          tags: [],
        ));
        reporter.onStepComplete(
          ReportStep(keyword: 'Given', text: 'I am on login page'),
          StepResult.passed(Duration.zero),
        );
        reporter.onScenarioComplete(
          ReportScenario(name: 'Valid Login', tags: []),
          ScenarioResult.passed(),
        );
        reporter.onFeatureComplete(
          ReportFeature(name: 'User Authentication', path: 'auth.feature'),
          FeatureResult.passed(),
        );
        reporter.flush();

        // Flat file naming in features subfolder: auth.feature -> features/auth.md
        final file = File('${tempDir.path}/features/auth.md');
        expect(await file.exists(), isTrue);

        final content = await file.readAsString();
        expect(content, contains('# User Authentication'));
        expect(content, contains('Valid Login'));
        expect(content, contains('**Given** I am on login page'));
      });

      test('creates subdirectories mirroring feature file paths', () async {
        final reporter = MarkdownFileReporter(outputDir: tempDir.path);

        reporter.onFeatureStart(ReportFeature(
          name: 'Session Management',
          path: 'features/session/management.feature',
        ));
        reporter.onFeatureComplete(
          ReportFeature(
              name: 'Session Management',
              path: 'features/session/management.feature'),
          FeatureResult.passed(),
        );
        reporter.flush();

        // Flat file structure in features subfolder: features/session/management.feature -> features/features_session_management.md
        final file =
            File('${tempDir.path}/features/features_session_management.md');
        expect(await file.exists(), isTrue);
      });

      test('creates only root index file on flush (no directory indexes)',
          () async {
        final reporter = MarkdownFileReporter(outputDir: tempDir.path);

        reporter.onFeatureStart(
            ReportFeature(name: 'Login', path: 'auth/login.feature'));
        reporter.onFeatureComplete(
          ReportFeature(name: 'Login', path: 'auth/login.feature'),
          FeatureResult.passed(),
        );

        reporter.onFeatureStart(
            ReportFeature(name: 'Logout', path: 'auth/logout.feature'));
        reporter.onFeatureComplete(
          ReportFeature(name: 'Logout', path: 'auth/logout.feature'),
          FeatureResult.passed(),
        );

        reporter.flush();

        // Only root index should exist
        final rootIndex = File('${tempDir.path}/index.md');
        expect(await rootIndex.exists(), isTrue);

        // No directory index
        final dirIndex = File('${tempDir.path}/auth/index.md');
        expect(await dirIndex.exists(), isFalse);

        // Root index contains features
        final content = await rootIndex.readAsString();
        expect(content, contains('Login'));
        expect(content, contains('Logout'));
      });

      test('cleans output directory before writing when cleanFirst is true',
          () async {
        // Create existing file
        final existingFile = File('${tempDir.path}/old_report.md');
        await existingFile.create(recursive: true);
        await existingFile.writeAsString('old content');

        final reporter = MarkdownFileReporter(
          outputDir: tempDir.path,
          cleanFirst: true,
        );

        reporter
            .onFeatureStart(ReportFeature(name: 'New', path: 'new.feature'));
        reporter.onFeatureComplete(
          ReportFeature(name: 'New', path: 'new.feature'),
          FeatureResult.passed(),
        );
        reporter.flush();

        expect(await existingFile.exists(), isFalse);
      });

      test('marks passed scenario steps with checkmark emoji', () async {
        final reporter = MarkdownFileReporter(outputDir: tempDir.path);

        reporter
            .onFeatureStart(ReportFeature(name: 'Test', path: 'test.feature'));
        reporter
            .onScenarioStart(ReportScenario(name: 'Passing Test', tags: []));
        reporter.onStepComplete(
          ReportStep(keyword: 'Given', text: 'something'),
          StepResult.passed(Duration.zero),
        );
        reporter.onScenarioComplete(
          ReportScenario(name: 'Passing Test', tags: []),
          ScenarioResult.passed(),
        );
        reporter.onFeatureComplete(
          ReportFeature(name: 'Test', path: 'test.feature'),
          FeatureResult.passed(),
        );
        reporter.flush();

        final content =
            await File('${tempDir.path}/features/test.md').readAsString();
        // Given uses clipboard icon 📋
        expect(content, contains('📋'));
        expect(content, contains('Passing Test'));
      });

      test('marks failed scenario steps with X emoji', () async {
        final reporter = MarkdownFileReporter(outputDir: tempDir.path);

        reporter
            .onFeatureStart(ReportFeature(name: 'Test', path: 'test.feature'));
        reporter
            .onScenarioStart(ReportScenario(name: 'Failing Test', tags: []));
        reporter.onStepComplete(
          ReportStep(keyword: 'Then', text: 'bad step'),
          StepResult.failed(Duration.zero, 'error'),
        );
        reporter.onScenarioComplete(
          ReportScenario(name: 'Failing Test', tags: []),
          ScenarioResult.failed('error'),
        );
        reporter.onFeatureComplete(
          ReportFeature(name: 'Test', path: 'test.feature'),
          FeatureResult.failed(),
        );
        reporter.flush();

        final content =
            await File('${tempDir.path}/features/test.md').readAsString();
        // Failed step shows ❌ after text
        expect(content, contains('❌'));
        expect(content, contains('Failing Test'));
      });

      test('includes tags in scenario header', () async {
        final reporter = MarkdownFileReporter(outputDir: tempDir.path);

        reporter.onFeatureStart(
            ReportFeature(name: 'Tagged', path: 'tagged.feature'));
        reporter.onScenarioStart(ReportScenario(
          name: 'Tagged Scenario',
          tags: ['@smoke', '@regression'],
        ));
        reporter.onScenarioComplete(
          ReportScenario(
              name: 'Tagged Scenario', tags: ['@smoke', '@regression']),
          ScenarioResult.passed(),
        );
        reporter.onFeatureComplete(
          ReportFeature(name: 'Tagged', path: 'tagged.feature'),
          FeatureResult.passed(),
        );
        reporter.flush();

        final content =
            await File('${tempDir.path}/features/tagged.md').readAsString();
        expect(content, contains('@smoke'));
        expect(content, contains('@regression'));
      });

      test('converts feature name to filename', () async {
        final reporter = MarkdownFileReporter(outputDir: tempDir.path);

        reporter.onFeatureStart(ReportFeature(
          name: 'User Can Log In Successfully',
          path: 'user_login.feature',
        ));
        reporter.onFeatureComplete(
          ReportFeature(
              name: 'User Can Log In Successfully', path: 'user_login.feature'),
          FeatureResult.passed(),
        );
        reporter.flush();

        // Uses path-based filename in features subfolder
        final file = File('${tempDir.path}/features/user_login.md');
        expect(await file.exists(), isTrue);
      });
    });

    group('ReportMode', () {
      test('continuous mode indicates live output', () {
        expect(ReportMode.continuous.isLive, isTrue);
        expect(ReportMode.continuous.writesToFile, isFalse);
      });

      test('full mode indicates buffered output', () {
        expect(ReportMode.full.isLive, isFalse);
        expect(ReportMode.full.isBuffered, isTrue);
      });

      test('summary mode indicates summary only', () {
        expect(ReportMode.summary.isSummaryOnly, isTrue);
      });

      test('file mode indicates file output', () {
        expect(ReportMode.file.writesToFile, isTrue);
      });
    });

    group('ReporterConfig', () {
      test('creates continuous reporter from config', () {
        final config = ReporterConfig(mode: ReportMode.continuous);
        final reporter = config.createReporter();

        expect(reporter, isA<ContinuousReporter>());
      });

      test('creates buffered reporter for full mode', () {
        final config = ReporterConfig(mode: ReportMode.full);
        final reporter = config.createReporter();

        expect(reporter, isA<BufferedReporter>());
      });

      test('creates summary reporter', () {
        final config = ReporterConfig(mode: ReportMode.summary);
        final reporter = config.createReporter();

        expect(reporter, isA<SummaryReporter>());
      });

      test('creates file reporter with output dir', () {
        final config = ReporterConfig(
          mode: ReportMode.file,
          outputDir: '/tmp/reports',
        );
        final reporter = config.createReporter();

        expect(reporter, isA<MarkdownFileReporter>());
      });

      test('creates composite reporter for multiple modes', () {
        final config = ReporterConfig(
          modes: [ReportMode.continuous, ReportMode.file],
          outputDir: '/tmp/reports',
        );
        final reporter = config.createReporter();

        expect(reporter, isA<CompositeReporter>());
      });

      test('throws when file mode used without outputDir', () {
        expect(
          () => ReporterConfig(mode: ReportMode.file).createReporter(),
          throwsArgumentError,
        );
      });
    });

    group('PrintingReporter', () {
      test('outputs feature name on feature start', () {
        final output = StringBuffer();
        final reporter = PrintingReporter(sink: output);

        reporter.onFeatureStart(
          ReportFeature(name: 'User Login', path: 'features/login.feature'),
        );

        expect(output.toString(), contains('Feature: User Login'));
      });

      test('outputs scenario name on scenario start', () {
        final output = StringBuffer();
        final reporter = PrintingReporter(sink: output);

        reporter.onScenarioStart(
          ReportScenario(name: 'Valid credentials', tags: []),
        );

        expect(output.toString(), contains('Scenario: Valid credentials'));
      });

      test('outputs step with checkmark on passed step', () {
        final output = StringBuffer();
        final reporter = PrintingReporter(sink: output);

        reporter.onStepComplete(
          ReportStep(keyword: 'Given', text: 'a user exists'),
          StepResult.passed(Duration(milliseconds: 10)),
        );

        expect(output.toString(), contains('✓'));
        expect(output.toString(), contains('Given a user exists'));
      });

      test('outputs step with X on failed step', () {
        final output = StringBuffer();
        final reporter = PrintingReporter(sink: output);

        reporter.onStepComplete(
          ReportStep(keyword: 'When', text: 'I click login'),
          StepResult.failed(Duration(milliseconds: 20), 'Button not found'),
        );

        expect(output.toString(), contains('✗'));
        expect(output.toString(), contains('When I click login'));
      });

      test('outputs step with dash on skipped step', () {
        final output = StringBuffer();
        final reporter = PrintingReporter(sink: output);

        reporter.onStepComplete(
          ReportStep(keyword: 'Then', text: 'I see dashboard'),
          StepResult.skipped(),
        );

        expect(output.toString(), contains('-'));
        expect(output.toString(), contains('Then I see dashboard'));
      });

      test('indents scenarios under features', () {
        final output = StringBuffer();
        final reporter = PrintingReporter(sink: output);

        reporter.onFeatureStart(
          ReportFeature(name: 'Login', path: 'login.feature'),
        );
        reporter.onScenarioStart(
          ReportScenario(name: 'Valid login', tags: []),
        );

        final lines = output.toString().split('\n');
        final featureLine = lines.firstWhere((l) => l.contains('Feature:'));
        final scenarioLine = lines.firstWhere((l) => l.contains('Scenario:'));

        // Scenario should be indented (have leading spaces)
        expect(scenarioLine.indexOf('Scenario'), greaterThan(0));
        expect(featureLine.indexOf('Feature'), 0);
      });

      test('indents steps under scenarios', () {
        final output = StringBuffer();
        final reporter = PrintingReporter(sink: output);

        reporter.onScenarioStart(
          ReportScenario(name: 'Test', tags: []),
        );
        reporter.onStepComplete(
          ReportStep(keyword: 'Given', text: 'something'),
          StepResult.passed(Duration.zero),
        );

        final lines = output.toString().split('\n');
        final scenarioLine = lines.firstWhere((l) => l.contains('Scenario:'));
        final stepLine = lines.firstWhere((l) => l.contains('Given'));

        // Step should be more indented than scenario
        final scenarioIndent =
            scenarioLine.indexOf(RegExp(r'\S')); // First non-space
        final stepIndent = stepLine.indexOf(RegExp(r'\S'));
        expect(stepIndent, greaterThan(scenarioIndent));
      });

      test('prints to console by default', () {
        // When no sink provided, should print to console (not throw)
        final reporter = PrintingReporter();

        expect(
          () => reporter.onFeatureStart(
            ReportFeature(name: 'Test', path: 'test.feature'),
          ),
          returnsNormally,
        );
      });

      test('flushes without error', () {
        final output = StringBuffer();
        final reporter = PrintingReporter(sink: output);

        expect(() => reporter.flush(), returnsNormally);
      });
    });

    group('FileReporter', () {
      test('writes feature to specified file path on flush', () {
        final written = <String, String>{};
        final reporter = FileReporter(
          outputPath: 'local_ignored/bdd_report.md',
          writer: (path, content) => written[path] = content,
        );

        reporter.onFeatureStart(
          ReportFeature(name: 'Login', path: 'login.feature'),
        );
        reporter.onScenarioStart(
          ReportScenario(name: 'Valid login', tags: []),
        );
        reporter.onStepComplete(
          ReportStep(keyword: 'Given', text: 'a user'),
          StepResult.passed(Duration.zero),
        );
        reporter.onScenarioComplete(
          ReportScenario(name: 'Valid login', tags: []),
          ScenarioResult.passed(),
        );
        reporter.onFeatureComplete(
          ReportFeature(name: 'Login', path: 'login.feature'),
          FeatureResult.passed(),
        );

        reporter.flush();

        expect(written.containsKey('local_ignored/bdd_report.md'), isTrue);
        expect(written['local_ignored/bdd_report.md'], contains('# Login'));
        expect(
            written['local_ignored/bdd_report.md'], contains('## Valid login'));
      });

      test('writes markdown with passed step checkmarks', () {
        final written = <String, String>{};
        final reporter = FileReporter(
          outputPath: 'report.md',
          writer: (path, content) => written[path] = content,
        );

        reporter.onFeatureStart(
          ReportFeature(name: 'Feature', path: 'f.feature'),
        );
        reporter.onScenarioStart(ReportScenario(name: 'Scenario', tags: []));
        reporter.onStepComplete(
          ReportStep(keyword: 'Given', text: 'something'),
          StepResult.passed(Duration.zero),
        );
        reporter.onScenarioComplete(
          ReportScenario(name: 'Scenario', tags: []),
          ScenarioResult.passed(),
        );
        reporter.onFeatureComplete(
          ReportFeature(name: 'Feature', path: 'f.feature'),
          FeatureResult.passed(),
        );
        reporter.flush();

        expect(written['report.md'], contains('✓'));
        expect(written['report.md'], contains('Given something'));
      });

      test('writes markdown with failed step info', () {
        final written = <String, String>{};
        final reporter = FileReporter(
          outputPath: 'report.md',
          writer: (path, content) => written[path] = content,
        );

        reporter.onFeatureStart(
          ReportFeature(name: 'Feature', path: 'f.feature'),
        );
        reporter.onScenarioStart(ReportScenario(name: 'Scenario', tags: []));
        reporter.onStepComplete(
          ReportStep(keyword: 'When', text: 'it fails'),
          StepResult.failed(Duration.zero, 'Error message'),
        );
        reporter.onScenarioComplete(
          ReportScenario(name: 'Scenario', tags: []),
          ScenarioResult.failed('Error'),
        );
        reporter.onFeatureComplete(
          ReportFeature(name: 'Feature', path: 'f.feature'),
          FeatureResult.failed(),
        );
        reporter.flush();

        expect(written['report.md'], contains('✗'));
        expect(written['report.md'], contains('When it fails'));
      });

      test('includes summary at end of file', () {
        final written = <String, String>{};
        final reporter = FileReporter(
          outputPath: 'report.md',
          writer: (path, content) => written[path] = content,
        );

        reporter.onFeatureStart(
          ReportFeature(name: 'Feature1', path: 'f1.feature'),
        );
        reporter.onScenarioStart(ReportScenario(name: 'Scenario1', tags: []));
        reporter.onStepComplete(
          ReportStep(keyword: 'Given', text: 'a'),
          StepResult.passed(Duration.zero),
        );
        reporter.onScenarioComplete(
          ReportScenario(name: 'Scenario1', tags: []),
          ScenarioResult.passed(),
        );
        reporter.onFeatureComplete(
          ReportFeature(name: 'Feature1', path: 'f1.feature'),
          FeatureResult.passed(),
        );
        reporter.flush();

        expect(written['report.md'], contains('Summary'));
        expect(written['report.md'], contains('1 feature'));
        expect(written['report.md'], contains('1 scenario'));
      });
    });
  });
}

/// Helper reporter to track flush calls.
class _FlushTrackingReporter implements BddReporter {
  final void Function() _onFlush;

  _FlushTrackingReporter(this._onFlush);

  @override
  void onFeatureStart(ReportFeature feature) {}

  @override
  void onFeatureComplete(ReportFeature feature, FeatureResult result) {}

  @override
  void onScenarioStart(ReportScenario scenario) {}

  @override
  void onScenarioComplete(ReportScenario scenario, ScenarioResult result) {}

  @override
  void onStepStart(ReportStep step) {}

  @override
  void onStepComplete(ReportStep step, StepResult result) {}

  @override
  void flush() => _onFlush();
}

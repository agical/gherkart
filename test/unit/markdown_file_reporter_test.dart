// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:gherkart/src/bdd_reporter.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('gherkart_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('MarkdownFileReporter', () {
    test('creates output directory on construction', () {
      final outputDir = p.join(tempDir.path, 'reports');
      MarkdownFileReporter(outputDir: outputDir);

      expect(Directory(outputDir).existsSync(), isTrue);
    });

    test('cleans output directory if cleanFirst is true', () {
      final outputDir = p.join(tempDir.path, 'reports');
      Directory(outputDir).createSync();
      File(p.join(outputDir, 'old_file.md')).writeAsStringSync('old content');

      MarkdownFileReporter(outputDir: outputDir, cleanFirst: true);

      expect(File(p.join(outputDir, 'old_file.md')).existsSync(), isFalse);
    });

    test('preserves existing files if cleanFirst is false', () {
      final outputDir = p.join(tempDir.path, 'reports');
      Directory(outputDir).createSync();
      File(p.join(outputDir, 'old_file.md')).writeAsStringSync('old content');

      MarkdownFileReporter(outputDir: outputDir, cleanFirst: false);

      expect(File(p.join(outputDir, 'old_file.md')).existsSync(), isTrue);
    });

    test('generates markdown file for feature on flush', () {
      final outputDir = p.join(tempDir.path, 'reports');
      final reporter = MarkdownFileReporter(outputDir: outputDir);

      reporter.onFeatureStart(ReportFeature(
        name: 'User Login',
        path: 'features/auth/login.feature',
      ));
      reporter.onScenarioStart(ReportScenario(
        name: 'Successful login',
        tags: [],
      ));
      reporter.onStepComplete(
        ReportStep(keyword: 'Given', text: 'I am on the login page'),
        StepResult.passed(Duration(milliseconds: 50)),
      );
      reporter.onStepComplete(
        ReportStep(keyword: 'When', text: 'I enter valid credentials'),
        StepResult.passed(Duration(milliseconds: 100)),
      );
      reporter.onStepComplete(
        ReportStep(keyword: 'Then', text: 'I am logged in'),
        StepResult.passed(Duration(milliseconds: 75)),
      );
      reporter.onScenarioComplete(
        ReportScenario(name: 'Successful login', tags: []),
        ScenarioResult.passed(),
      );
      reporter.onFeatureComplete(
        ReportFeature(name: 'User Login', path: 'features/auth/login.feature'),
        FeatureResult.passed(),
      );

      reporter.flush();

      final expectedFile = File(p.join(outputDir, 'features', 'features_auth_login.md'));
      expect(expectedFile.existsSync(), isTrue);
    });

    test('uses flat file structure for all features in features subfolder', () {
      final outputDir = p.join(tempDir.path, 'reports');
      final reporter = MarkdownFileReporter(outputDir: outputDir);

      reporter.onFeatureStart(ReportFeature(
        name: 'Feature A',
        path: 'features/module1/a.feature',
      ));
      reporter.onFeatureComplete(
        ReportFeature(name: 'Feature A', path: 'features/module1/a.feature'),
        FeatureResult.passed(),
      );
      reporter.onFeatureStart(ReportFeature(
        name: 'Feature B',
        path: 'features/module2/b.feature',
      ));
      reporter.onFeatureComplete(
        ReportFeature(name: 'Feature B', path: 'features/module2/b.feature'),
        FeatureResult.passed(),
      );

      reporter.flush();

      // Files should be flat in features subfolder
      expect(
        File(p.join(outputDir, 'features', 'features_module1_a.md')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(outputDir, 'features', 'features_module2_b.md')).existsSync(),
        isTrue,
      );
      // Only features subfolder should exist, not nested structure
      expect(
        Directory(p.join(outputDir, 'features', 'module1')).existsSync(),
        isFalse,
      );
    });

    test('does not generate directory index files (only root index)', () {
      final outputDir = p.join(tempDir.path, 'reports');
      final reporter = MarkdownFileReporter(outputDir: outputDir);

      reporter.onFeatureStart(ReportFeature(
        name: 'Login',
        path: 'features/auth/login.feature',
      ));
      reporter.onFeatureComplete(
        ReportFeature(name: 'Login', path: 'features/auth/login.feature'),
        FeatureResult.passed(),
      );
      reporter.onFeatureStart(ReportFeature(
        name: 'Logout',
        path: 'features/auth/logout.feature',
      ));
      reporter.onFeatureComplete(
        ReportFeature(name: 'Logout', path: 'features/auth/logout.feature'),
        FeatureResult.passed(),
      );

      reporter.flush();

      // No directory index files should exist
      final dirIndexFile = File(p.join(outputDir, 'features', 'auth', 'index.md'));
      expect(dirIndexFile.existsSync(), isFalse);

      // Only root index should exist with all features
      final rootIndex = File(p.join(outputDir, 'index.md'));
      expect(rootIndex.existsSync(), isTrue);
      final content = rootIndex.readAsStringSync();
      expect(content, contains('Login'));
      expect(content, contains('Logout'));
    });

    test('feature with @wip tag and no scenarios shows skipped icon', () {
      final outputDir = p.join(tempDir.path, 'reports');
      final reporter = MarkdownFileReporter(outputDir: outputDir);

      // Feature with @wip tag - scenarios are skipped at test runtime
      // so onScenarioStart/Complete are never called
      reporter.onFeatureStart(ReportFeature(
        name: 'Work In Progress Feature',
        path: 'features/wip.feature',
        tags: ['@wip'],
      ));
      reporter.onFeatureComplete(
        ReportFeature(
          name: 'Work In Progress Feature',
          path: 'features/wip.feature',
          tags: ['@wip'],
        ),
        FeatureResult.passed(), // Result may still be "passed" but no scenarios ran
      );

      reporter.flush();

      final indexContent = File(p.join(outputDir, 'index.md')).readAsStringSync();
      // Should show skipped icon, not question mark
      expect(indexContent, contains('⏭️'), reason: '@wip features should show skipped');
      expect(indexContent, isNot(contains('❓')), reason: '@wip features should not show unknown status');
    });

    test('generates root index file', () {
      final outputDir = p.join(tempDir.path, 'reports');
      final reporter = MarkdownFileReporter(outputDir: outputDir);

      reporter.onFeatureStart(ReportFeature(
        name: 'Feature 1',
        path: 'features/a.feature',
      ));
      reporter.onFeatureComplete(
        ReportFeature(name: 'Feature 1', path: 'features/a.feature'),
        FeatureResult.passed(),
      );

      reporter.flush();

      final rootIndex = File(p.join(outputDir, 'index.md'));
      expect(rootIndex.existsSync(), isTrue);
    });

    test('markdown contains feature name as heading', () {
      final outputDir = p.join(tempDir.path, 'reports');
      final reporter = MarkdownFileReporter(outputDir: outputDir);

      reporter.onFeatureStart(ReportFeature(
        name: 'User Authentication',
        path: 'features/auth.feature',
      ));
      reporter.onFeatureComplete(
        ReportFeature(name: 'User Authentication', path: 'features/auth.feature'),
        FeatureResult.passed(),
      );

      reporter.flush();

      final content = File(p.join(outputDir, 'features', 'features_auth.md')).readAsStringSync();
      expect(content, contains('# User Authentication'));
    });

    test('markdown contains scenarios as subheadings', () {
      final outputDir = p.join(tempDir.path, 'reports');
      final reporter = MarkdownFileReporter(outputDir: outputDir);

      reporter.onFeatureStart(ReportFeature(
        name: 'Auth',
        path: 'features/auth.feature',
      ));
      reporter.onScenarioStart(ReportScenario(
        name: 'Login successfully',
        tags: [],
      ));
      reporter.onScenarioComplete(
        ReportScenario(name: 'Login successfully', tags: []),
        ScenarioResult.passed(),
      );
      reporter.onScenarioStart(ReportScenario(
        name: 'Login fails with wrong password',
        tags: [],
      ));
      reporter.onScenarioComplete(
        ReportScenario(name: 'Login fails with wrong password', tags: []),
        ScenarioResult.passed(),
      );
      reporter.onFeatureComplete(
        ReportFeature(name: 'Auth', path: 'features/auth.feature'),
        FeatureResult.passed(),
      );

      reporter.flush();

      final content = File(p.join(outputDir, 'features', 'features_auth.md')).readAsStringSync();
      // Scenario headings now include status icon
      expect(content, contains('## ✅ Login successfully'));
      expect(content, contains('## ✅ Login fails with wrong password'));
    });

    test('markdown contains steps with status indicators', () {
      final outputDir = p.join(tempDir.path, 'reports');
      final reporter = MarkdownFileReporter(outputDir: outputDir);

      reporter.onFeatureStart(ReportFeature(
        name: 'Test',
        path: 'features/test.feature',
      ));
      reporter.onScenarioStart(ReportScenario(name: 'Scenario', tags: []));
      reporter.onStepComplete(
        ReportStep(keyword: 'Given', text: 'something passed'),
        StepResult.passed(Duration(milliseconds: 50)),
      );
      reporter.onStepComplete(
        ReportStep(keyword: 'When', text: 'something failed'),
        StepResult.failed(Duration(milliseconds: 50), 'Error occurred'),
      );
      reporter.onScenarioComplete(
        ReportScenario(name: 'Scenario', tags: []),
        ScenarioResult.failed('Error occurred'),
      );
      reporter.onFeatureComplete(
        ReportFeature(name: 'Test', path: 'features/test.feature'),
        FeatureResult.failed(),
      );

      reporter.flush();

      final content = File(p.join(outputDir, 'features', 'features_test.md')).readAsStringSync();
      // Given uses clipboard icon, When uses action icon with failure mark
      expect(content, contains('📋 **Given** something passed'));
      expect(content, contains('⚡ **When** something failed ❌'));
      expect(content, contains('**Given**'));
      expect(content, contains('something passed'));
      expect(content, contains('**When**'));
      expect(content, contains('something failed'));
    });

    test('markdown includes tags', () {
      final outputDir = p.join(tempDir.path, 'reports');
      final reporter = MarkdownFileReporter(outputDir: outputDir);

      reporter.onFeatureStart(ReportFeature(
        name: 'Tagged Feature',
        path: 'features/tagged.feature',
        tags: ['@smoke', '@api'],
      ));
      reporter.onScenarioStart(ReportScenario(
        name: 'Tagged scenario',
        tags: ['@slow'],
      ));
      reporter.onScenarioComplete(
        ReportScenario(name: 'Tagged scenario', tags: ['@slow']),
        ScenarioResult.passed(),
      );
      reporter.onFeatureComplete(
        ReportFeature(name: 'Tagged Feature', path: 'features/tagged.feature', tags: ['@smoke', '@api']),
        FeatureResult.passed(),
      );

      reporter.flush();

      final content = File(p.join(outputDir, 'features', 'features_tagged.md')).readAsStringSync();
      expect(content, contains('@smoke'));
      expect(content, contains('@api'));
      expect(content, contains('@slow'));
    });

    test('root index shows pass/fail status for features', () {
      final outputDir = p.join(tempDir.path, 'reports');
      final reporter = MarkdownFileReporter(outputDir: outputDir);

      reporter.onFeatureStart(ReportFeature(
        name: 'Passing Feature',
        path: 'features/pass.feature',
      ));
      reporter.onFeatureComplete(
        ReportFeature(name: 'Passing Feature', path: 'features/pass.feature'),
        FeatureResult.passed(),
      );
      reporter.onFeatureStart(ReportFeature(
        name: 'Failing Feature',
        path: 'features/fail.feature',
      ));
      reporter.onFeatureComplete(
        ReportFeature(name: 'Failing Feature', path: 'features/fail.feature'),
        FeatureResult.failed(),
      );

      reporter.flush();

      final content = File(p.join(outputDir, 'index.md')).readAsStringSync();
      expect(content, contains('✅'));
      expect(content, contains('❌'));
    });

    test('scenario result is recorded when multiple scenarios start before completing (async execution)', () {
      // This simulates async test execution where scenario B starts before scenario A completes
      // BUG: _currentScenario gets overwritten, so scenario A's result is lost
      final outputDir = p.join(tempDir.path, 'reports');
      final reporter = MarkdownFileReporter(outputDir: outputDir);

      reporter.onFeatureStart(ReportFeature(
        name: 'Feature A',
        path: 'features/a.feature',
      ));
      reporter.onFeatureStart(ReportFeature(
        name: 'Feature B',
        path: 'features/b.feature',
      ));

      // Scenario A starts
      reporter.onScenarioStart(ReportScenario(
        name: 'Scenario in A',
        tags: [],
        featurePath: 'features/a.feature',
      ));

      // Scenario B starts BEFORE A completes (async interleaving)
      reporter.onScenarioStart(ReportScenario(
        name: 'Scenario in B',
        tags: [],
        featurePath: 'features/b.feature',
      ));

      // Now Scenario A completes - but _currentScenario points to B!
      reporter.onScenarioComplete(
        ReportScenario(name: 'Scenario in A', tags: [], featurePath: 'features/a.feature'),
        ScenarioResult.passed(),
      );

      // Scenario B completes
      reporter.onScenarioComplete(
        ReportScenario(name: 'Scenario in B', tags: [], featurePath: 'features/b.feature'),
        ScenarioResult.passed(),
      );

      reporter.onFeatureComplete(
        ReportFeature(name: 'Feature A', path: 'features/a.feature'),
        FeatureResult.passed(),
      );
      reporter.onFeatureComplete(
        ReportFeature(name: 'Feature B', path: 'features/b.feature'),
        FeatureResult.passed(),
      );

      reporter.flush();

      // Check root index - no question marks should appear
      final indexContent = File(p.join(outputDir, 'index.md')).readAsStringSync();
      expect(indexContent, isNot(contains('❓')), reason: 'All scenarios should have status, not unknown');
      expect(indexContent, contains('✅ Scenario in A'));
      expect(indexContent, contains('✅ Scenario in B'));
    });

    test('associates scenarios with correct feature when features start before scenarios (async execution)', () {
      // This simulates async test execution where all onFeatureStart calls
      // happen before any onScenarioStart calls
      final outputDir = p.join(tempDir.path, 'reports');
      final reporter = MarkdownFileReporter(outputDir: outputDir);

      // All features start first (simulating async test framework behavior)
      reporter.onFeatureStart(ReportFeature(
        name: 'Feature A',
        path: 'features/a.feature',
      ));
      reporter.onFeatureStart(ReportFeature(
        name: 'Feature B',
        path: 'features/b.feature',
      ));

      // Scenario for Feature A runs (with featurePath to identify parent)
      reporter.onScenarioStart(ReportScenario(
        name: 'Scenario in A',
        tags: [],
        featurePath: 'features/a.feature',
      ));
      reporter.onStepComplete(
        ReportStep(keyword: 'Given', text: 'step in A'),
        StepResult.passed(Duration(milliseconds: 10)),
      );
      reporter.onScenarioComplete(
        ReportScenario(name: 'Scenario in A', tags: [], featurePath: 'features/a.feature'),
        ScenarioResult.passed(),
      );

      // Scenario for Feature B runs
      reporter.onScenarioStart(ReportScenario(
        name: 'Scenario in B',
        tags: [],
        featurePath: 'features/b.feature',
      ));
      reporter.onStepComplete(
        ReportStep(keyword: 'Given', text: 'step in B'),
        StepResult.passed(Duration(milliseconds: 10)),
      );
      reporter.onScenarioComplete(
        ReportScenario(name: 'Scenario in B', tags: [], featurePath: 'features/b.feature'),
        ScenarioResult.passed(),
      );

      // Features complete
      reporter.onFeatureComplete(
        ReportFeature(name: 'Feature A', path: 'features/a.feature'),
        FeatureResult.passed(),
      );
      reporter.onFeatureComplete(
        ReportFeature(name: 'Feature B', path: 'features/b.feature'),
        FeatureResult.passed(),
      );

      reporter.flush();

      // Feature A should contain only its scenario
      final contentA = File(p.join(outputDir, 'features', 'features_a.md')).readAsStringSync();
      expect(contentA, contains('Scenario in A'));
      expect(contentA, contains('step in A'));
      expect(contentA, isNot(contains('Scenario in B')));
      expect(contentA, isNot(contains('step in B')));

      // Feature B should contain only its scenario
      final contentB = File(p.join(outputDir, 'features', 'features_b.md')).readAsStringSync();
      expect(contentB, contains('Scenario in B'));
      expect(contentB, contains('step in B'));
      expect(contentB, isNot(contains('Scenario in A')));
      expect(contentB, isNot(contains('step in A')));
    });

    test('computes feature status from scenario results when onFeatureComplete has unknown status', () {
      final outputDir = p.join(tempDir.path, 'reports');
      final reporter = MarkdownFileReporter(outputDir: outputDir);

      reporter.onFeatureStart(ReportFeature(
        name: 'Feature With Steps',
        path: 'features/computed.feature',
      ));
      reporter.onScenarioStart(ReportScenario(
        name: 'Passing scenario',
        tags: [],
        featurePath: 'features/computed.feature',
      ));
      reporter.onStepComplete(
        ReportStep(keyword: 'Given', text: 'a passing step'),
        StepResult.passed(Duration(milliseconds: 10)),
      );
      reporter.onScenarioComplete(
        ReportScenario(name: 'Passing scenario', tags: [], featurePath: 'features/computed.feature'),
        ScenarioResult.passed(),
      );
      // Feature completes but result may not reflect actual scenario results
      reporter.onFeatureComplete(
        ReportFeature(name: 'Feature With Steps', path: 'features/computed.feature'),
        FeatureResult.passed(),
      );

      reporter.flush();

      final indexContent = File(p.join(outputDir, 'index.md')).readAsStringSync();
      // Should show passed status (✅) computed from scenario results
      expect(indexContent, contains('✅'));
      expect(indexContent, isNot(contains('❓')));
    });

    test('step icons are based on keyword type', () {
      final outputDir = p.join(tempDir.path, 'reports');
      final reporter = MarkdownFileReporter(outputDir: outputDir);

      reporter.onFeatureStart(ReportFeature(
        name: 'Keyword Icons',
        path: 'features/icons.feature',
      ));
      reporter.onScenarioStart(ReportScenario(name: 'Test Steps', tags: []));
      reporter.onStepComplete(
        ReportStep(keyword: 'Given', text: 'a precondition'),
        StepResult.passed(Duration.zero),
      );
      reporter.onStepComplete(
        ReportStep(keyword: 'When', text: 'an action'),
        StepResult.passed(Duration.zero),
      );
      reporter.onStepComplete(
        ReportStep(keyword: 'Then', text: 'a result'),
        StepResult.passed(Duration.zero),
      );
      reporter.onStepComplete(
        ReportStep(keyword: 'And', text: 'another thing'),
        StepResult.passed(Duration.zero),
      );
      reporter.onScenarioComplete(
        ReportScenario(name: 'Test Steps', tags: []),
        ScenarioResult.passed(),
      );
      reporter.onFeatureComplete(
        ReportFeature(name: 'Keyword Icons', path: 'features/icons.feature'),
        FeatureResult.passed(),
      );

      reporter.flush();

      final content = File(p.join(outputDir, 'features', 'features_icons.md')).readAsStringSync();
      // Given uses clipboard icon
      expect(content, contains('📋'));
      expect(content, contains('📋 **Given**'));
      // When uses action/lightning icon
      expect(content, contains('⚡'));
      expect(content, contains('⚡ **When**'));
      // Then uses green checkmark icon
      expect(content, contains('✅ **Then**'));
      // And uses plus icon
      expect(content, contains('➕'));
      expect(content, contains('➕ **And**'));
    });

    test('failed steps show failure indicator after text', () {
      final outputDir = p.join(tempDir.path, 'reports');
      final reporter = MarkdownFileReporter(outputDir: outputDir);

      reporter.onFeatureStart(ReportFeature(
        name: 'Failure Indicator',
        path: 'features/fail.feature',
      ));
      reporter.onScenarioStart(ReportScenario(name: 'Failing', tags: []));
      reporter.onStepComplete(
        ReportStep(keyword: 'Given', text: 'something ok'),
        StepResult.passed(Duration.zero),
      );
      reporter.onStepComplete(
        ReportStep(keyword: 'When', text: 'something fails'),
        StepResult.failed(Duration.zero, 'Error'),
      );
      reporter.onScenarioComplete(
        ReportScenario(name: 'Failing', tags: []),
        ScenarioResult.failed('Error'),
      );
      reporter.onFeatureComplete(
        ReportFeature(name: 'Failure Indicator', path: 'features/fail.feature'),
        FeatureResult.failed(),
      );

      reporter.flush();

      final content = File(p.join(outputDir, 'features', 'features_fail.md')).readAsStringSync();
      // Passed step has no failure indicator
      expect(content, contains('📋 **Given** something ok'));
      expect(content, isNot(contains('something ok ❌')));
      // Failed step has failure indicator after text
      expect(content, contains('something fails ❌'));
    });

    test('Then step uses green checkmark icon', () {
      final outputDir = p.join(tempDir.path, 'reports');
      final reporter = MarkdownFileReporter(outputDir: outputDir);

      reporter.onFeatureStart(ReportFeature(
        name: 'Then Icon',
        path: 'features/then.feature',
      ));
      reporter.onScenarioStart(ReportScenario(name: 'Verify', tags: []));
      reporter.onStepComplete(
        ReportStep(keyword: 'Then', text: 'result is correct'),
        StepResult.passed(Duration.zero),
      );
      reporter.onScenarioComplete(
        ReportScenario(name: 'Verify', tags: []),
        ScenarioResult.passed(),
      );
      reporter.onFeatureComplete(
        ReportFeature(name: 'Then Icon', path: 'features/then.feature'),
        FeatureResult.passed(),
      );

      reporter.flush();

      final content = File(p.join(outputDir, 'features', 'features_then.md')).readAsStringSync();
      // Then uses green checkmark ✅
      expect(content, contains('✅ **Then**'));
    });

    test('passing scenario headline shows green checkmark', () {
      final outputDir = p.join(tempDir.path, 'reports');
      final reporter = MarkdownFileReporter(outputDir: outputDir);

      reporter.onFeatureStart(ReportFeature(
        name: 'Headline Test',
        path: 'features/headline.feature',
      ));
      reporter.onScenarioStart(ReportScenario(name: 'Passing Scenario', tags: []));
      reporter.onStepComplete(
        ReportStep(keyword: 'Given', text: 'something'),
        StepResult.passed(Duration.zero),
      );
      reporter.onScenarioComplete(
        ReportScenario(name: 'Passing Scenario', tags: []),
        ScenarioResult.passed(),
      );
      reporter.onFeatureComplete(
        ReportFeature(name: 'Headline Test', path: 'features/headline.feature'),
        FeatureResult.passed(),
      );

      reporter.flush();

      final content = File(p.join(outputDir, 'features', 'features_headline.md')).readAsStringSync();
      // Passing scenario headline has green checkmark
      expect(content, contains('## ✅ Passing Scenario'));
    });

    test('failed scenario headline shows red X', () {
      final outputDir = p.join(tempDir.path, 'reports');
      final reporter = MarkdownFileReporter(outputDir: outputDir);

      reporter.onFeatureStart(ReportFeature(
        name: 'Failed Headline',
        path: 'features/failed.feature',
      ));
      reporter.onScenarioStart(ReportScenario(name: 'Failing Scenario', tags: []));
      reporter.onStepComplete(
        ReportStep(keyword: 'Given', text: 'something'),
        StepResult.failed(Duration.zero, 'Error'),
      );
      reporter.onScenarioComplete(
        ReportScenario(name: 'Failing Scenario', tags: []),
        ScenarioResult.failed('Error'),
      );
      reporter.onFeatureComplete(
        ReportFeature(name: 'Failed Headline', path: 'features/failed.feature'),
        FeatureResult.failed(),
      );

      reporter.flush();

      final content = File(p.join(outputDir, 'features', 'features_failed.md')).readAsStringSync();
      // Failed scenario headline has red X
      expect(content, contains('## ❌ Failing Scenario'));
    });

    test('skipped scenario headline shows skip icon', () {
      final outputDir = p.join(tempDir.path, 'reports');
      final reporter = MarkdownFileReporter(outputDir: outputDir);

      reporter.onFeatureStart(ReportFeature(
        name: 'Skipped Test',
        path: 'features/skipped.feature',
      ));
      reporter.onScenarioStart(ReportScenario(
        name: 'WIP Scenario',
        tags: ['@wip', '@skip'],
      ));
      reporter.onScenarioComplete(
        ReportScenario(name: 'WIP Scenario', tags: ['@wip', '@skip']),
        ScenarioResult.skipped(),
      );
      reporter.onFeatureComplete(
        ReportFeature(name: 'Skipped Test', path: 'features/skipped.feature'),
        FeatureResult.passed(),
      );

      reporter.flush();

      final content = File(p.join(outputDir, 'features', 'features_skipped.md')).readAsStringSync();
      // Skipped scenario headline has skip icon
      expect(content, contains('## ⏭️ WIP Scenario'));
      // Tags are shown
      expect(content, contains('@wip'));
      expect(content, contains('@skip'));
    });

    test('feature tags always shown in header', () {
      final outputDir = p.join(tempDir.path, 'reports');
      final reporter = MarkdownFileReporter(outputDir: outputDir);

      reporter.onFeatureStart(ReportFeature(
        name: 'Tagged Feature',
        path: 'features/tagged.feature',
        tags: ['@smoke', '@api', '@wip'],
      ));
      reporter.onScenarioStart(ReportScenario(name: 'Test', tags: []));
      reporter.onScenarioComplete(
        ReportScenario(name: 'Test', tags: []),
        ScenarioResult.passed(),
      );
      reporter.onFeatureComplete(
        ReportFeature(
          name: 'Tagged Feature',
          path: 'features/tagged.feature',
          tags: ['@smoke', '@api', '@wip'],
        ),
        FeatureResult.passed(),
      );

      reporter.flush();

      final content = File(p.join(outputDir, 'features', 'features_tagged.md')).readAsStringSync();
      // Feature tags shown
      expect(content, contains('@smoke'));
      expect(content, contains('@api'));
      expect(content, contains('@wip'));
    });

    test('scenario tags always shown after headline', () {
      final outputDir = p.join(tempDir.path, 'reports');
      final reporter = MarkdownFileReporter(outputDir: outputDir);

      reporter.onFeatureStart(ReportFeature(
        name: 'Scenario Tags',
        path: 'features/scenario_tags.feature',
      ));
      reporter.onScenarioStart(ReportScenario(
        name: 'Tagged Scenario',
        tags: ['@critical', '@regression'],
      ));
      reporter.onStepComplete(
        ReportStep(keyword: 'Given', text: 'something'),
        StepResult.passed(Duration.zero),
      );
      reporter.onScenarioComplete(
        ReportScenario(name: 'Tagged Scenario', tags: ['@critical', '@regression']),
        ScenarioResult.passed(),
      );
      reporter.onFeatureComplete(
        ReportFeature(name: 'Scenario Tags', path: 'features/scenario_tags.feature'),
        FeatureResult.passed(),
      );

      reporter.flush();

      final content = File(p.join(outputDir, 'features', 'features_scenario_tags.md')).readAsStringSync();
      // Scenario tags shown
      expect(content, contains('@critical'));
      expect(content, contains('@regression'));
    });

    test('feature markdown includes back link to index', () {
      final outputDir = p.join(tempDir.path, 'reports');
      final reporter = MarkdownFileReporter(outputDir: outputDir);

      reporter.onFeatureStart(ReportFeature(
        name: 'Back Link Test',
        path: 'features/backlink.feature',
      ));
      reporter.onScenarioStart(ReportScenario(name: 'Test', tags: []));
      reporter.onScenarioComplete(
        ReportScenario(name: 'Test', tags: []),
        ScenarioResult.passed(),
      );
      reporter.onFeatureComplete(
        ReportFeature(name: 'Back Link Test', path: 'features/backlink.feature'),
        FeatureResult.passed(),
      );

      reporter.flush();

      final content = File(p.join(outputDir, 'features', 'features_backlink.md')).readAsStringSync();
      // Back link at top of file (features are in features/ subfolder, so link to ../index.md)
      expect(content, contains('[← Back to index](../index.md)'));
    });

    test('only root index exists (no directory index files)', () {
      final outputDir = p.join(tempDir.path, 'reports');
      final reporter = MarkdownFileReporter(outputDir: outputDir);

      reporter.onFeatureStart(ReportFeature(
        name: 'Root Link Test',
        path: 'features/rootlink.feature',
      ));
      reporter.onScenarioStart(ReportScenario(name: 'Test', tags: []));
      reporter.onScenarioComplete(
        ReportScenario(name: 'Test', tags: []),
        ScenarioResult.passed(),
      );
      reporter.onFeatureComplete(
        ReportFeature(name: 'Root Link Test', path: 'features/rootlink.feature'),
        FeatureResult.passed(),
      );

      reporter.flush();

      // No directory index should exist
      final dirIndex = File(p.join(outputDir, 'features', 'index.md'));
      expect(dirIndex.existsSync(), isFalse);

      // Root index should exist
      final rootIndex = File(p.join(outputDir, 'index.md'));
      expect(rootIndex.existsSync(), isTrue);
      expect(rootIndex.readAsStringSync(), contains('Root Link Test'));
    });

    test('root index shows full tree of features and scenarios', () {
      final outputDir = p.join(tempDir.path, 'reports');
      final reporter = MarkdownFileReporter(outputDir: outputDir);

      // Feature 1 with 2 scenarios
      reporter.onFeatureStart(ReportFeature(
        name: 'Login Feature',
        path: 'features/auth/login.feature',
      ));
      reporter.onScenarioStart(ReportScenario(name: 'Successful login', tags: []));
      reporter.onStepComplete(
        ReportStep(keyword: 'Given', text: 'user exists'),
        StepResult.passed(Duration.zero),
      );
      reporter.onScenarioComplete(
        ReportScenario(name: 'Successful login', tags: []),
        ScenarioResult.passed(),
      );
      reporter.onScenarioStart(ReportScenario(name: 'Failed login', tags: []));
      reporter.onStepComplete(
        ReportStep(keyword: 'Given', text: 'wrong password'),
        StepResult.failed(Duration.zero, 'Error'),
      );
      reporter.onScenarioComplete(
        ReportScenario(name: 'Failed login', tags: []),
        ScenarioResult.failed('Error'),
      );
      reporter.onFeatureComplete(
        ReportFeature(name: 'Login Feature', path: 'features/auth/login.feature'),
        FeatureResult.mixed(),
      );

      // Feature 2 in different directory
      reporter.onFeatureStart(ReportFeature(
        name: 'Home Feature',
        path: 'features/home/home.feature',
      ));
      reporter.onScenarioStart(ReportScenario(name: 'View home', tags: []));
      reporter.onScenarioComplete(
        ReportScenario(name: 'View home', tags: []),
        ScenarioResult.passed(),
      );
      reporter.onFeatureComplete(
        ReportFeature(name: 'Home Feature', path: 'features/home/home.feature'),
        FeatureResult.passed(),
      );

      reporter.flush();

      final rootIndex = File(p.join(outputDir, 'index.md')).readAsStringSync();

      // Root index should show feature names with status
      expect(rootIndex, contains('Login Feature'));
      expect(rootIndex, contains('Home Feature'));

      // Root index should show scenario names with status
      expect(rootIndex, contains('Successful login'));
      expect(rootIndex, contains('Failed login'));
      expect(rootIndex, contains('View home'));

      // Should have links to feature files (flat structure)
      expect(rootIndex, contains('features_auth_login.md'));
      expect(rootIndex, contains('features_home_home.md'));

      // Should show status icons
      expect(rootIndex, contains('✅')); // passed scenarios/features
      expect(rootIndex, contains('❌')); // failed scenario
    });

    test('feature files are in flat structure with back link to root', () {
      final outputDir = p.join(tempDir.path, 'reports');
      final reporter = MarkdownFileReporter(outputDir: outputDir);

      reporter.onFeatureStart(ReportFeature(
        name: 'Nested Feature',
        path: 'features/deep/nested/test.feature',
      ));
      reporter.onScenarioStart(ReportScenario(name: 'Test', tags: []));
      reporter.onScenarioComplete(
        ReportScenario(name: 'Test', tags: []),
        ScenarioResult.passed(),
      );
      reporter.onFeatureComplete(
        ReportFeature(name: 'Nested Feature', path: 'features/deep/nested/test.feature'),
        FeatureResult.passed(),
      );

      reporter.flush();

      // Feature file should be in features subfolder (flat naming in features dir)
      final flatFile = File(p.join(outputDir, 'features', 'features_deep_nested_test.md'));
      expect(flatFile.existsSync(), isTrue);

      final content = flatFile.readAsStringSync();
      // Back link should go to root index (one level up from features/)
      expect(content, contains('[← Back to index](../index.md)'));
    });

    test('no directory index files are created', () {
      final outputDir = p.join(tempDir.path, 'reports');
      final reporter = MarkdownFileReporter(outputDir: outputDir);

      reporter.onFeatureStart(ReportFeature(
        name: 'Test Feature',
        path: 'features/auth/login.feature',
      ));
      reporter.onScenarioStart(ReportScenario(name: 'Test', tags: []));
      reporter.onScenarioComplete(
        ReportScenario(name: 'Test', tags: []),
        ScenarioResult.passed(),
      );
      reporter.onFeatureComplete(
        ReportFeature(name: 'Test Feature', path: 'features/auth/login.feature'),
        FeatureResult.passed(),
      );

      reporter.flush();

      // No subdirectory index should exist
      final dirIndex = File(p.join(outputDir, 'features', 'auth', 'index.md'));
      expect(dirIndex.existsSync(), isFalse);

      // Only root index should exist
      final rootIndex = File(p.join(outputDir, 'index.md'));
      expect(rootIndex.existsSync(), isTrue);
    });

    test('feature files are in features subfolder', () {
      final outputDir = p.join(tempDir.path, 'reports');
      final reporter = MarkdownFileReporter(outputDir: outputDir);

      reporter.onFeatureStart(ReportFeature(
        name: 'Login',
        path: 'features/auth/login.feature',
      ));
      reporter.onScenarioStart(ReportScenario(name: 'Test', tags: []));
      reporter.onScenarioComplete(
        ReportScenario(name: 'Test', tags: []),
        ScenarioResult.passed(),
      );
      reporter.onFeatureComplete(
        ReportFeature(name: 'Login', path: 'features/auth/login.feature'),
        FeatureResult.passed(),
      );

      reporter.flush();

      // Feature file should be in features/ subfolder
      final featureFile = File(p.join(outputDir, 'features', 'features_auth_login.md'));
      expect(featureFile.existsSync(), isTrue);

      // Back link should go up to root index
      final content = featureFile.readAsStringSync();
      expect(content, contains('[← Back to index](../index.md)'));
    });
  });
}

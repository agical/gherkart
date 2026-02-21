// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;

import 'bdd_reporter.dart';

/// A reporter that generates Markdown files for non-technical readers.
///
/// Features are written as individual Markdown files mirroring the directory
/// structure of the source .feature files. Index files are generated for each
/// directory to provide navigation.
///
/// Example usage:
/// ```dart
/// final reporter = MarkdownFileReporter(
///   outputDir: 'build/docs/features',
///   cleanFirst: true,
/// );
/// ```
class MarkdownFileReporter implements BddReporter {
  final String outputDir;
  final bool cleanFirst;

  final List<_FeatureReport> _features = [];
  _FeatureReport? _currentFeature;
  _ScenarioReport? _currentScenario;

  /// Creates a new MarkdownFileReporter.
  ///
  /// [outputDir] - Directory where markdown files will be written.
  /// [cleanFirst] - If true, deletes all existing files in outputDir first.
  MarkdownFileReporter({
    required this.outputDir,
    this.cleanFirst = true,
  }) {
    final dir = Directory(outputDir);
    if (cleanFirst && dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    dir.createSync(recursive: true);
  }

  @override
  void onFeatureStart(ReportFeature feature) {
    _currentFeature = _FeatureReport(feature);
    _features.add(_currentFeature!);
  }

  @override
  void onFeatureComplete(ReportFeature feature, FeatureResult result) {
    _currentFeature?.result = result;
    _currentFeature = null;
    _currentScenario = null;
  }

  @override
  void onScenarioStart(ReportScenario scenario) {
    final scenarioReport = _ScenarioReport(scenario);
    // Find the correct feature by path (handles async test execution)
    final targetFeature = scenario.featurePath != null
        ? _features.cast<_FeatureReport?>().firstWhere(
              (f) => f?.feature.path == scenario.featurePath,
              orElse: () => _currentFeature,
            )
        : _currentFeature;
    targetFeature?.scenarios.add(scenarioReport);
    _currentScenario = scenarioReport;
  }

  @override
  void onScenarioComplete(ReportScenario scenario, ScenarioResult result) {
    // Find scenario by name and featurePath to handle async interleaving
    // where multiple scenarios may start before any complete
    _ScenarioReport? target;
    if (scenario.featurePath != null) {
      final feature = _features.cast<_FeatureReport?>().firstWhere(
            (f) => f?.feature.path == scenario.featurePath,
            orElse: () => null,
          );
      target = feature?.scenarios.cast<_ScenarioReport?>().firstWhere(
            (s) => s?.scenario.name == scenario.name,
            orElse: () => null,
          );
    }
    target ??= _currentScenario;
    target?.result = result;
    if (target == _currentScenario) {
      _currentScenario = null;
    }
  }

  @override
  void onStepStart(ReportStep step) {
    // We report on complete, not start
  }

  @override
  void onStepComplete(ReportStep step, StepResult result) {
    _currentScenario?.steps.add(_StepReport(step, result));
  }

  @override
  void flush() {
    // Write feature files
    for (final feature in _features) {
      _writeFeatureFile(feature);
    }

    // Generate index files
    _generateIndexFiles();
  }

  void _writeFeatureFile(_FeatureReport feature) {
    // Flatten path: features/auth/login.feature -> features_auth_login.md
    final flatName = feature.feature.path
        .replaceAll('.feature', '')
        .replaceAll('/', '_')
        .replaceAll(r'\', '_');
    final outputPath = p.join(outputDir, 'features', '$flatName.md');

    // Create features directory
    final featuresDir = Directory(p.join(outputDir, 'features'));
    if (!featuresDir.existsSync()) {
      featuresDir.createSync(recursive: true);
    }

    final buffer = StringBuffer();

    // Back link to root index (one level up)
    buffer.writeln('[← Back to index](../index.md)');
    buffer.writeln();

    // Feature heading
    buffer.writeln('# ${feature.feature.name}');
    buffer.writeln();

    // Tags
    if (feature.feature.tags.isNotEmpty) {
      buffer.writeln('**Tags:** ${feature.feature.tags.join(', ')}');
      buffer.writeln();
    }

    // Executed scenarios
    for (final scenario in feature.scenarios) {
      _writeScenario(buffer, scenario);
    }

    // Find unexecuted scenarios (e.g., @wip scenarios that were skipped)
    final executedNames = feature.scenarios.map((s) => s.scenario.name).toSet();
    final unexecutedScenarios = feature.feature.sourceScenarios
        .where((s) => !executedNames.contains(s.name))
        .toList();

    if (unexecutedScenarios.isNotEmpty) {
      buffer.writeln('---');
      buffer.writeln();
      buffer.writeln('## 🚧 Not Yet Implemented');
      buffer.writeln();

      for (final scenario in unexecutedScenarios) {
        _writeUnexecutedScenario(buffer, scenario);
      }
    }

    File(outputPath).writeAsStringSync(buffer.toString());
  }

  void _writeScenario(StringBuffer buffer, _ScenarioReport scenario) {
    // Scenario headline with status indicator
    final scenarioIcon = switch (scenario.computedStatus) {
      ScenarioStatus.passed => '✅',
      ScenarioStatus.failed => '❌',
      ScenarioStatus.skipped => '⏭️',
      null => '',
    };
    final iconPrefix = scenarioIcon.isNotEmpty ? '$scenarioIcon ' : '';
    buffer.writeln('## $iconPrefix${scenario.scenario.name}');
    buffer.writeln();

    // Tags
    if (scenario.scenario.tags.isNotEmpty) {
      buffer.writeln('**Tags:** ${scenario.scenario.tags.join(', ')}');
      buffer.writeln();
    }

    // Steps - icon based on keyword, failure indicator after text if failed
    for (final step in scenario.steps) {
      final keywordIcon = switch (step.step.keyword.trim()) {
        'Given' => '📋',
        'When' => '⚡',
        'Then' => '✅',
        'And' || 'But' => '➕',
        _ => '•',
      };
      final failureMark = switch (step.result.status) {
        StepStatus.passed => '',
        StepStatus.failed => ' ❌',
        StepStatus.skipped => ' ⏭️',
      };
      buffer.writeln(
          '- $keywordIcon **${step.step.keyword}** ${step.step.text}$failureMark');
    }
    buffer.writeln();
  }

  void _writeUnexecutedScenario(StringBuffer buffer, Scenario scenario) {
    buffer.writeln('### 🚧 ${scenario.name}');
    buffer.writeln();

    // Tags
    if (scenario.tags.isNotEmpty) {
      buffer.writeln('**Tags:** ${scenario.tags.join(', ')}');
      buffer.writeln();
    }

    // Steps - show what needs to be implemented
    for (final step in scenario.steps) {
      final keywordIcon = switch (step.keyword) {
        StepKeyword.given => '📋',
        StepKeyword.when => '⚡',
        StepKeyword.then => '✅',
        StepKeyword.and || StepKeyword.but => '➕',
      };
      final keywordText =
          step.keyword.name[0].toUpperCase() + step.keyword.name.substring(1);
      buffer.writeln('- $keywordIcon **$keywordText** ${step.text}');
    }
    buffer.writeln();
  }

  void _generateIndexFiles() {
    // Only generate root index - no directory indexes needed with flat structure
    _writeRootIndex();
  }

  void _writeRootIndex() {
    final indexPath = p.join(outputDir, 'index.md');

    final buffer = StringBuffer();
    buffer.writeln('# Test Results');
    buffer.writeln();

    // Count results
    var passed = 0;
    var failed = 0;
    var mixed = 0;

    for (final feature in _features) {
      switch (feature.computedStatus) {
        case FeatureStatus.passed:
          passed++;
        case FeatureStatus.failed:
          failed++;
        case FeatureStatus.mixed:
          mixed++;
        case null:
          break;
      }
    }

    buffer.writeln('**Summary:** $passed passed, $failed failed, $mixed mixed');
    buffer.writeln();

    // Group features by directory
    final featuresByDir = <String, List<_FeatureReport>>{};
    for (final feature in _features) {
      final dir = p.dirname(feature.feature.path);
      featuresByDir.putIfAbsent(dir, () => []).add(feature);
    }

    // Sort directories
    final directories = featuresByDir.keys.toList()..sort();

    buffer.writeln('## Features');
    buffer.writeln();

    // Write tree structure
    for (final dir in directories) {
      buffer.writeln('### $dir');
      buffer.writeln();

      final features = featuresByDir[dir]!;
      for (final feature in features) {
        // Use skip icon for @wip/@skip features with no scenarios
        final featureIcon = feature.wasSkipped
            ? '⏭️'
            : switch (feature.computedStatus) {
                FeatureStatus.passed => '✅',
                FeatureStatus.failed => '❌',
                FeatureStatus.mixed => '⚠️',
                null => '❓',
              };
        // Flat file name in features subfolder: features/auth/login.feature -> features/features_auth_login.md
        final flatName = feature.feature.path
            .replaceAll('.feature', '')
            .replaceAll('/', '_')
            .replaceAll(r'\', '_');
        buffer.writeln(
            '- $featureIcon [${feature.feature.name}](features/$flatName.md)');

        // List scenarios under each feature
        for (final scenario in feature.scenarios) {
          final scenarioIcon = switch (scenario.computedStatus) {
            ScenarioStatus.passed => '✅',
            ScenarioStatus.failed => '❌',
            ScenarioStatus.skipped => '⏭️',
            null => '❓',
          };
          buffer.writeln('  - $scenarioIcon ${scenario.scenario.name}');
        }
      }
      buffer.writeln();
    }

    File(indexPath).writeAsStringSync(buffer.toString());
  }
}

class _FeatureReport {
  final ReportFeature feature;
  FeatureResult? result;
  final List<_ScenarioReport> scenarios = [];

  _FeatureReport(this.feature);

  /// Check if feature has skip-related tags (@wip, @skip)
  bool get hasSkipTag {
    final tags = feature.tags;
    return tags
        .any((t) => t == '@wip' || t == '@skip' || t == 'wip' || t == 'skip');
  }

  /// Compute status from scenarios if result not set
  FeatureStatus? get computedStatus {
    if (result?.status != null) return result!.status;

    // If no scenarios recorded and has skip tag, consider it skipped (not unknown)
    if (scenarios.isEmpty) {
      return hasSkipTag ? FeatureStatus.passed : null;
    }

    final hasFailure =
        scenarios.any((s) => s.computedStatus == ScenarioStatus.failed);
    final hasPassed =
        scenarios.any((s) => s.computedStatus == ScenarioStatus.passed);

    if (hasFailure && hasPassed) return FeatureStatus.mixed;
    if (hasFailure) return FeatureStatus.failed;
    if (hasPassed) return FeatureStatus.passed;
    return null;
  }

  /// Whether this feature was skipped (has skip tag and no scenarios ran)
  bool get wasSkipped => scenarios.isEmpty && hasSkipTag;
}

class _ScenarioReport {
  final ReportScenario scenario;
  ScenarioResult? result;
  final List<_StepReport> steps = [];

  _ScenarioReport(this.scenario);

  /// Compute status from steps if result not set
  ScenarioStatus? get computedStatus {
    if (result?.status != null) return result!.status;
    if (steps.isEmpty) return null;

    final hasFailure = steps.any((s) => s.result.status == StepStatus.failed);
    if (hasFailure) return ScenarioStatus.failed;
    return ScenarioStatus.passed;
  }
}

class _StepReport {
  final ReportStep step;
  final StepResult result;

  _StepReport(this.step, this.result);
}

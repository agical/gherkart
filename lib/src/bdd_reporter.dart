// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/// BDD Reporter interface and implementations for test output.
///
/// This module provides a flexible reporting system for BDD tests with four
/// built-in reporter modes:
/// - [ContinuousReporter]: Reports events as they happen
/// - [BufferedReporter]: Collects all events and reports at the end
/// - [SummaryReporter]: Reports only summary counts
/// - [CompositeReporter]: Combines multiple reporters
/// - [MarkdownFileReporter]: Writes markdown files for non-technical readers
library;

import 'feature_parser.dart' as parser;
import 'markdown_file_reporter.dart';

// Re-export types needed by other modules
export 'feature_parser.dart' show Scenario, Step, StepKeyword;
export 'markdown_file_reporter.dart' show MarkdownFileReporter;

// === Enums for result statuses ===

/// Status of a step execution.
enum StepStatus { passed, failed, skipped }

/// Status of a scenario execution.
enum ScenarioStatus { passed, failed, skipped }

/// Status of a feature execution.
enum FeatureStatus { passed, failed, mixed }

// === Data classes for reporting ===

/// Metadata about a feature being reported.
class ReportFeature {
  final String name;
  final String path;
  final List<String> tags;

  /// The parsed scenarios from the feature file (for showing unexecuted scenarios).
  final List<parser.Scenario> sourceScenarios;

  ReportFeature({
    required this.name,
    required this.path,
    this.tags = const [],
    this.sourceScenarios = const [],
  });

  @override
  String toString() => 'ReportFeature($name, $path, $tags)';
}

/// Metadata about a scenario being reported.
class ReportScenario {
  final String name;
  final List<String> tags;
  final bool isOutlineInstance;
  final String? outlineName;
  final int? exampleIndex;
  final String? featurePath;

  ReportScenario({
    required this.name,
    required this.tags,
    this.isOutlineInstance = false,
    this.outlineName,
    this.exampleIndex,
    this.featurePath,
  });

  @override
  String toString() => 'ReportScenario($name, tags: $tags, outline: $isOutlineInstance)';
}

/// Metadata about a step being reported.
class ReportStep {
  final String keyword;
  final String text;
  final bool hasTable;
  final bool hasDocString;

  ReportStep({
    required this.keyword,
    required this.text,
    this.hasTable = false,
    this.hasDocString = false,
  });

  @override
  String toString() => 'ReportStep($keyword $text)';
}

// === Result classes ===

/// Result of a step execution.
class StepResult {
  final StepStatus status;
  final Duration? duration;
  final String? error;

  const StepResult._({
    required this.status,
    this.duration,
    this.error,
  });

  factory StepResult.passed(Duration duration) => StepResult._(
        status: StepStatus.passed,
        duration: duration,
      );

  factory StepResult.failed(Duration duration, String error) => StepResult._(
        status: StepStatus.failed,
        duration: duration,
        error: error,
      );

  factory StepResult.skipped() => const StepResult._(
        status: StepStatus.skipped,
      );

  @override
  String toString() => 'StepResult($status, ${duration?.inMilliseconds}ms)';
}

/// Result of a scenario execution.
class ScenarioResult {
  final ScenarioStatus status;
  final String? error;

  const ScenarioResult._({
    required this.status,
    this.error,
  });

  factory ScenarioResult.passed() => const ScenarioResult._(
        status: ScenarioStatus.passed,
      );

  factory ScenarioResult.failed(String error) => ScenarioResult._(
        status: ScenarioStatus.failed,
        error: error,
      );

  factory ScenarioResult.skipped() => const ScenarioResult._(
        status: ScenarioStatus.skipped,
      );

  @override
  String toString() => 'ScenarioResult($status)';
}

/// Result of a feature execution.
class FeatureResult {
  final FeatureStatus status;

  const FeatureResult._({required this.status});

  factory FeatureResult.passed() => const FeatureResult._(
        status: FeatureStatus.passed,
      );

  factory FeatureResult.failed() => const FeatureResult._(
        status: FeatureStatus.failed,
      );

  factory FeatureResult.mixed() => const FeatureResult._(
        status: FeatureStatus.mixed,
      );

  @override
  String toString() => 'FeatureResult($status)';
}

// === Reporter interface ===

/// Interface for BDD test reporters.
///
/// Reporters receive events as tests execute and can output results
/// in various formats and at different times.
abstract class BddReporter {
  /// Called when a feature starts executing.
  void onFeatureStart(ReportFeature feature);

  /// Called when a feature finishes executing.
  void onFeatureComplete(ReportFeature feature, FeatureResult result);

  /// Called when a scenario starts executing.
  void onScenarioStart(ReportScenario scenario);

  /// Called when a scenario finishes executing.
  void onScenarioComplete(ReportScenario scenario, ScenarioResult result);

  /// Called when a step starts executing.
  void onStepStart(ReportStep step);

  /// Called when a step finishes executing.
  void onStepComplete(ReportStep step, StepResult result);

  /// Called to flush any buffered output.
  void flush();
}

// === Reporter implementations ===

/// Reporter event type for continuous reporting.
sealed class ReporterEvent {
  @override
  String toString();
}

class FeatureStartEvent extends ReporterEvent {
  final ReportFeature feature;
  FeatureStartEvent(this.feature);

  @override
  String toString() => 'FeatureStart: ${feature.name}';
}

class FeatureCompleteEvent extends ReporterEvent {
  final ReportFeature feature;
  final FeatureResult result;
  FeatureCompleteEvent(this.feature, this.result);

  @override
  String toString() => 'FeatureComplete: ${feature.name} (${result.status})';
}

class ScenarioStartEvent extends ReporterEvent {
  final ReportScenario scenario;
  ScenarioStartEvent(this.scenario);

  @override
  String toString() => 'ScenarioStart: ${scenario.name}';
}

class ScenarioCompleteEvent extends ReporterEvent {
  final ReportScenario scenario;
  final ScenarioResult result;
  ScenarioCompleteEvent(this.scenario, this.result);

  @override
  String toString() => 'ScenarioComplete: ${scenario.name} (${result.status})';
}

class StepStartEvent extends ReporterEvent {
  final ReportStep step;
  StepStartEvent(this.step);

  @override
  String toString() => 'StepStart: ${step.keyword} ${step.text}';
}

class StepCompleteEvent extends ReporterEvent {
  final ReportStep step;
  final StepResult result;
  StepCompleteEvent(this.step, this.result);

  @override
  String toString() => 'StepComplete: ${step.keyword} ${step.text} (${result.status})';
}

/// Reports events immediately as they occur.
class ContinuousReporter implements BddReporter {
  final void Function(ReporterEvent event) onEvent;

  ContinuousReporter({required this.onEvent});

  @override
  void onFeatureStart(ReportFeature feature) => onEvent(FeatureStartEvent(feature));

  @override
  void onFeatureComplete(ReportFeature feature, FeatureResult result) => onEvent(FeatureCompleteEvent(feature, result));

  @override
  void onScenarioStart(ReportScenario scenario) => onEvent(ScenarioStartEvent(scenario));

  @override
  void onScenarioComplete(ReportScenario scenario, ScenarioResult result) =>
      onEvent(ScenarioCompleteEvent(scenario, result));

  @override
  void onStepStart(ReportStep step) => onEvent(StepStartEvent(step));

  @override
  void onStepComplete(ReportStep step, StepResult result) => onEvent(StepCompleteEvent(step, result));

  @override
  void flush() {
    // No-op for continuous reporter
  }
}

/// Buffered results from a test run.
class BufferedResults {
  final List<_BufferedFeature> features;

  BufferedResults(this.features);

  @override
  String toString() {
    final buffer = StringBuffer();
    for (final feature in features) {
      buffer.writeln('Feature: ${feature.feature.name}');
      for (final scenario in feature.scenarios) {
        buffer.writeln('  Scenario: ${scenario.scenario.name}');
      }
    }
    return buffer.toString();
  }
}

class _BufferedFeature {
  final ReportFeature feature;
  FeatureResult? result;
  final List<_BufferedScenario> scenarios = [];

  _BufferedFeature(this.feature);
}

class _BufferedScenario {
  final ReportScenario scenario;
  ScenarioResult? result;
  final List<_BufferedStep> steps = [];

  _BufferedScenario(this.scenario);
}

class _BufferedStep {
  final ReportStep step;
  StepResult? result;

  _BufferedStep(this.step);
}

/// Collects all events and reports them at the end.
class BufferedReporter implements BddReporter {
  final void Function(BufferedResults results) onComplete;
  final List<_BufferedFeature> _features = [];
  _BufferedFeature? _currentFeature;
  _BufferedScenario? _currentScenario;

  BufferedReporter({required this.onComplete});

  @override
  void onFeatureStart(ReportFeature feature) {
    _currentFeature = _BufferedFeature(feature);
    _features.add(_currentFeature!);
  }

  @override
  void onFeatureComplete(ReportFeature feature, FeatureResult result) {
    _currentFeature?.result = result;
    _currentFeature = null;
  }

  @override
  void onScenarioStart(ReportScenario scenario) {
    _currentScenario = _BufferedScenario(scenario);
    _currentFeature?.scenarios.add(_currentScenario!);
  }

  @override
  void onScenarioComplete(ReportScenario scenario, ScenarioResult result) {
    _currentScenario?.result = result;
    _currentScenario = null;
  }

  @override
  void onStepStart(ReportStep step) {
    _currentScenario?.steps.add(_BufferedStep(step));
  }

  @override
  void onStepComplete(ReportStep step, StepResult result) {
    final currentStep = _currentScenario?.steps.lastOrNull;
    if (currentStep != null) {
      currentStep.result = result;
    }
  }

  @override
  void flush() {
    onComplete(BufferedResults(_features));
  }
}

/// Summary of test results for reporting.
class TestSummary {
  final int featureCount;
  final int scenarioPassed;
  final int scenarioFailed;
  final int scenarioSkipped;
  final int stepPassed;
  final int stepFailed;
  final int stepSkipped;

  const TestSummary({
    required this.featureCount,
    required this.scenarioPassed,
    required this.scenarioFailed,
    required this.scenarioSkipped,
    required this.stepPassed,
    required this.stepFailed,
    required this.stepSkipped,
  });

  int get scenarioTotal => scenarioPassed + scenarioFailed + scenarioSkipped;
  int get stepTotal => stepPassed + stepFailed + stepSkipped;

  @override
  String toString() {
    final parts = <String>[];
    parts.add('$featureCount feature${featureCount == 1 ? '' : 's'}');
    parts.add('$scenarioTotal scenario${scenarioTotal == 1 ? '' : 's'}');
    parts.add('($scenarioPassed passed, $scenarioFailed failed)');
    return parts.join(', ');
  }
}

/// Reports only summary counts at the end.
class SummaryReporter implements BddReporter {
  final void Function(TestSummary summary) onSummary;

  int _featureCount = 0;
  int _scenarioPassed = 0;
  int _scenarioFailed = 0;
  int _scenarioSkipped = 0;
  int _stepPassed = 0;
  int _stepFailed = 0;
  int _stepSkipped = 0;

  SummaryReporter({required this.onSummary});

  @override
  void onFeatureStart(ReportFeature feature) {
    _featureCount++;
  }

  @override
  void onFeatureComplete(ReportFeature feature, FeatureResult result) {
    // Counted on start
  }

  @override
  void onScenarioStart(ReportScenario scenario) {
    // Wait for completion
  }

  @override
  void onScenarioComplete(ReportScenario scenario, ScenarioResult result) {
    switch (result.status) {
      case ScenarioStatus.passed:
        _scenarioPassed++;
      case ScenarioStatus.failed:
        _scenarioFailed++;
      case ScenarioStatus.skipped:
        _scenarioSkipped++;
    }
  }

  @override
  void onStepStart(ReportStep step) {
    // Wait for completion
  }

  @override
  void onStepComplete(ReportStep step, StepResult result) {
    switch (result.status) {
      case StepStatus.passed:
        _stepPassed++;
      case StepStatus.failed:
        _stepFailed++;
      case StepStatus.skipped:
        _stepSkipped++;
    }
  }

  @override
  void flush() {
    onSummary(TestSummary(
      featureCount: _featureCount,
      scenarioPassed: _scenarioPassed,
      scenarioFailed: _scenarioFailed,
      scenarioSkipped: _scenarioSkipped,
      stepPassed: _stepPassed,
      stepFailed: _stepFailed,
      stepSkipped: _stepSkipped,
    ));
  }
}

/// Combines multiple reporters, delegating to all of them.
class CompositeReporter implements BddReporter {
  final List<BddReporter> reporters;

  CompositeReporter(this.reporters);

  @override
  void onFeatureStart(ReportFeature feature) {
    for (final reporter in reporters) {
      reporter.onFeatureStart(feature);
    }
  }

  @override
  void onFeatureComplete(ReportFeature feature, FeatureResult result) {
    for (final reporter in reporters) {
      reporter.onFeatureComplete(feature, result);
    }
  }

  @override
  void onScenarioStart(ReportScenario scenario) {
    for (final reporter in reporters) {
      reporter.onScenarioStart(scenario);
    }
  }

  @override
  void onScenarioComplete(ReportScenario scenario, ScenarioResult result) {
    for (final reporter in reporters) {
      reporter.onScenarioComplete(scenario, result);
    }
  }

  @override
  void onStepStart(ReportStep step) {
    for (final reporter in reporters) {
      reporter.onStepStart(step);
    }
  }

  @override
  void onStepComplete(ReportStep step, StepResult result) {
    for (final reporter in reporters) {
      reporter.onStepComplete(step, result);
    }
  }

  @override
  void flush() {
    for (final reporter in reporters) {
      reporter.flush();
    }
  }
}

/// Formats and prints BDD output in a human-readable format.
///
/// This reporter prints features, scenarios, and steps as they occur
/// with proper indentation and status indicators:
/// - ✓ for passed steps
/// - ✗ for failed steps
/// - - for skipped steps
class PrintingReporter implements BddReporter {
  /// Sink to write to. If null, prints to console.
  final StringSink? sink;

  /// Creates a PrintingReporter.
  ///
  /// If [sink] is provided, output is written there. Otherwise, prints to console.
  PrintingReporter({this.sink});

  void _writeLine(String line) {
    if (sink != null) {
      sink!.writeln(line);
    } else {
      // ignore: avoid_print
      print(line);
    }
  }

  @override
  void onFeatureStart(ReportFeature feature) {
    _writeLine('Feature: ${feature.name}');
  }

  @override
  void onFeatureComplete(ReportFeature feature, FeatureResult result) {
    // No-op
  }

  @override
  void onScenarioStart(ReportScenario scenario) {
    _writeLine('  Scenario: ${scenario.name}');
  }

  @override
  void onScenarioComplete(ReportScenario scenario, ScenarioResult result) {
    // No-op
  }

  @override
  void onStepStart(ReportStep step) {
    // No-op - we report on completion
  }

  @override
  void onStepComplete(ReportStep step, StepResult result) {
    final indicator = switch (result.status) {
      StepStatus.passed => '✓',
      StepStatus.failed => '✗',
      StepStatus.skipped => '-',
    };
    _writeLine('    $indicator ${step.keyword} ${step.text}');
  }

  @override
  void flush() {
    // No-op for printing reporter
  }
}

/// Writes BDD test results to a markdown file.
///
/// This reporter buffers all events and writes them to a markdown file
/// when flush() is called. The output includes:
/// - Features as H1 headers
/// - Scenarios as H2 headers
/// - Steps with status indicators
/// - Summary counts at the end
class FileReporter implements BddReporter {
  /// Path to the output file.
  final String outputPath;

  /// Custom writer function for testing. If null, writes to file system.
  final void Function(String path, String content)? writer;

  // Buffered data
  final List<_FileFeature> _features = [];
  _FileFeature? _currentFeature;
  _FileScenario? _currentScenario;

  /// Creates a FileReporter that writes to [outputPath].
  ///
  /// [writer] can be provided for testing to capture output instead of
  /// writing to the file system.
  FileReporter({
    required this.outputPath,
    this.writer,
  });

  @override
  void onFeatureStart(ReportFeature feature) {
    _currentFeature = _FileFeature(feature);
    _features.add(_currentFeature!);
  }

  @override
  void onFeatureComplete(ReportFeature feature, FeatureResult result) {
    _currentFeature?.result = result;
    _currentFeature = null;
  }

  @override
  void onScenarioStart(ReportScenario scenario) {
    _currentScenario = _FileScenario(scenario);
    _currentFeature?.scenarios.add(_currentScenario!);
  }

  @override
  void onScenarioComplete(ReportScenario scenario, ScenarioResult result) {
    _currentScenario?.result = result;
    _currentScenario = null;
  }

  @override
  void onStepStart(ReportStep step) {
    // No-op - we track on completion
  }

  @override
  void onStepComplete(ReportStep step, StepResult result) {
    _currentScenario?.steps.add(_FileStep(step, result));
  }

  @override
  void flush() {
    final buffer = StringBuffer();

    // Count for summary
    var scenarioCount = 0;

    for (final feature in _features) {
      buffer.writeln('# ${feature.feature.name}');
      buffer.writeln();

      for (final scenario in feature.scenarios) {
        scenarioCount++;
        buffer.writeln('## ${scenario.scenario.name}');
        buffer.writeln();

        for (final step in scenario.steps) {
          final indicator = switch (step.result.status) {
            StepStatus.passed => '✓',
            StepStatus.failed => '✗',
            StepStatus.skipped => '-',
          };
          buffer.writeln('$indicator ${step.step.keyword} ${step.step.text}');
        }
        buffer.writeln();
      }
    }

    // Add summary
    buffer.writeln('---');
    buffer.writeln();
    buffer.writeln('## Summary');
    buffer.writeln();
    buffer.writeln('${_features.length} feature${_features.length == 1 ? '' : 's'}, '
        '$scenarioCount scenario${scenarioCount == 1 ? '' : 's'}');

    final content = buffer.toString();
    if (writer != null) {
      writer!(outputPath, content);
    } else {
      // Real file writing would go here
      // ignore: avoid_print
      print('Would write to $outputPath:\n$content');
    }
  }
}

/// Internal class for buffering feature data in FileReporter.
class _FileFeature {
  final ReportFeature feature;
  FeatureResult? result;
  final List<_FileScenario> scenarios = [];

  _FileFeature(this.feature);
}

/// Internal class for buffering scenario data in FileReporter.
class _FileScenario {
  final ReportScenario scenario;
  ScenarioResult? result;
  final List<_FileStep> steps = [];

  _FileScenario(this.scenario);
}

/// Internal class for buffering step data in FileReporter.
class _FileStep {
  final ReportStep step;
  final StepResult result;

  _FileStep(this.step, this.result);
}

// === Report Mode Enum ===

/// Available reporting modes for BDD test output.
enum ReportMode {
  /// Reports events immediately as they occur during test execution.
  continuous,

  /// Buffers all events and reports them at the end of each scenario.
  full,

  /// Reports only summary counts at the end of the test run.
  summary,

  /// Writes markdown files for each feature (for non-technical readers).
  file;

  /// Whether this mode outputs live during execution.
  bool get isLive => this == ReportMode.continuous;

  /// Whether this mode buffers output.
  bool get isBuffered => this == ReportMode.full;

  /// Whether this mode shows only summary.
  bool get isSummaryOnly => this == ReportMode.summary;

  /// Whether this mode writes to files.
  bool get writesToFile => this == ReportMode.file;
}

// === Reporter Configuration ===

/// Configuration for creating BDD reporters.
class ReporterConfig {
  /// The primary reporting mode.
  final ReportMode mode;

  /// Additional reporting modes to combine with the primary mode.
  final List<ReportMode> modes;

  /// Output directory for file-based reporters.
  final String? outputDir;

  /// Whether to clean the output directory before writing.
  final bool cleanFirst;

  /// Custom print function (defaults to print).
  final void Function(String)? printer;

  /// Creates a reporter configuration.
  ///
  /// Use [mode] for a single reporter or [modes] for multiple combined reporters.
  /// When [mode] is [ReportMode.file] or [modes] contains [ReportMode.file],
  /// [outputDir] must be provided.
  ReporterConfig({
    this.mode = ReportMode.continuous,
    this.modes = const [],
    this.outputDir,
    this.cleanFirst = false,
    this.printer,
  });

  /// Creates a [BddReporter] based on this configuration.
  BddReporter createReporter() {
    final allModes = modes.isEmpty ? [mode] : modes;

    if (allModes.length == 1) {
      return _createSingleReporter(allModes.first);
    }

    return CompositeReporter(
      allModes.map(_createSingleReporter).toList(),
    );
  }

  BddReporter _createSingleReporter(ReportMode mode) {
    final print = printer ?? _defaultPrint;

    switch (mode) {
      case ReportMode.continuous:
        return ContinuousReporter(
          onEvent: (event) => print(_formatEvent(event)),
        );
      case ReportMode.full:
        return BufferedReporter(
          onComplete: (results) => print(results.toString()),
        );
      case ReportMode.summary:
        return SummaryReporter(
          onSummary: (summary) => print(summary.toString()),
        );
      case ReportMode.file:
        if (outputDir == null) {
          throw ArgumentError('outputDir is required for file mode');
        }
        return MarkdownFileReporter(
          outputDir: outputDir!,
          cleanFirst: cleanFirst,
        );
    }
  }

  String _formatEvent(ReporterEvent event) {
    return switch (event) {
      FeatureStartEvent e => '\n📋 Feature: ${e.feature.name}',
      FeatureCompleteEvent _ => '',
      ScenarioStartEvent e => '  🎬 Scenario: ${e.scenario.name}',
      ScenarioCompleteEvent _ => '',
      StepStartEvent e => '    ${e.step.keyword} ${e.step.text}',
      StepCompleteEvent e => e.result.status == StepStatus.passed
          ? '    ✓ ${e.step.keyword} ${e.step.text}'
          : '    ✗ ${e.step.keyword} ${e.step.text}',
    };
  }

  static void _defaultPrint(String message) {
    // ignore: avoid_print
    print(message);
  }
}

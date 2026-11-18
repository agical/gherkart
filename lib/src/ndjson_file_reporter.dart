// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:cucumber_messages/cucumber_messages.dart' as cm;
import 'package:path/path.dart' as p;

import 'bdd_reporter.dart';
import 'step_registry.dart';

/// A file-based [BddReporter] that writes Cucumber Messages as NDJSON to disk.
///
/// Output files conform to the official Cucumber Messages protocol and can be
/// fed directly into standard Cucumber HTML, JSON, and JUnit formatters.
///
/// Example usage:
/// ```dart
/// final reporter = NdjsonFileReporter(
///   outputPath: 'build/reports/cucumber-messages.ndjson',
/// );
///
/// await runBddTests<PatrolTester>(
///   rootPaths: ['test/features'],
///   registry: registry,
///   adapter: adapter,
///   source: FileSystemSource(),
///   reporter: reporter,
/// );
/// ```
class NdjsonFileReporter implements BddReporter {
  /// Path to the `.ndjson` file to write when [flush] is called.
  final String outputPath;

  final NdjsonReporter _delegate;

  /// Creates a new [NdjsonFileReporter] writing to [outputPath].
  ///
  /// Parent directories are created automatically if they do not exist.
  NdjsonFileReporter({
    required this.outputPath,
    StepDefinitionProvider? registry,
    String stepDefinitionsUri = 'steps.dart',
    String Function()? idGenerator,
    DateTime Function()? clock,
    cm.Meta? meta,
  }) : _delegate = NdjsonReporter(
         registry: registry,
         stepDefinitionsUri: stepDefinitionsUri,
         idGenerator: idGenerator,
         clock: clock,
         meta: meta ?? _buildPlatformMeta(),
       ) {
    final parentDir = Directory(p.dirname(outputPath));
    if (!parentDir.existsSync()) {
      parentDir.createSync(recursive: true);
    }
  }

  /// Attaches a [StepDefinitionProvider] if none was explicitly configured.
  void attachRegistry(StepDefinitionProvider registry) {
    _delegate.attachRegistry(registry);
  }

  /// All Cucumber Message [cm.Envelope]s emitted during the most recent [flush].
  List<cm.Envelope> get envelopes => _delegate.envelopes;

  @override
  void onFeatureStart(ReportFeature feature) => _delegate.onFeatureStart(feature);

  @override
  void onFeatureComplete(ReportFeature feature, FeatureResult result) => _delegate.onFeatureComplete(feature, result);

  @override
  void onScenarioStart(ReportScenario scenario) => _delegate.onScenarioStart(scenario);

  @override
  void onScenarioComplete(ReportScenario scenario, ScenarioResult result) =>
      _delegate.onScenarioComplete(scenario, result);

  @override
  void onStepStart(ReportStep step) => _delegate.onStepStart(step);

  @override
  void onStepComplete(ReportStep step, StepResult result) => _delegate.onStepComplete(step, result);

  @override
  void flush() {
    _delegate.flush();
    final file = File(outputPath);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    file.writeAsStringSync(_delegate.toNdjson());
  }

  static cm.Meta _buildPlatformMeta() {
    final dartVersion = Platform.version.split(' ').first;
    return cm.Meta(
      protocolVersion: NdjsonReporter.protocolVersion,
      implementation: const cm.Product(name: 'gherkart', version: '0.3.0'),
      runtime: cm.Product(name: 'Dart', version: dartVersion),
      os: cm.Product(name: Platform.operatingSystem, version: Platform.operatingSystemVersion),
      cpu: cm.Product(name: _inferCpuArchitecture()),
    );
  }

  static String _inferCpuArchitecture() {
    final version = Platform.version.toLowerCase();
    if (version.contains('arm64')) return 'arm64';
    if (version.contains('x64')) return 'x64';
    if (version.contains('ia32')) return 'ia32';
    if (version.contains('riscv64')) return 'riscv64';
    return 'unknown';
  }
}

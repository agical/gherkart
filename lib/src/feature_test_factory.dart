import 'feature_parser.dart';
import 'step_registry.dart';

/// How to structure the test groups.
enum TestStructure {
  /// One group per feature, no folder nesting.
  flat,

  /// Groups nested by folder structure.
  tree,
}

/// Factory for creating test plans from feature files.
///
/// Example:
/// ```dart
/// void main() async {
///   final factory = FeatureTestFactory(
///     rootPath: 'test/features',
///     registry: myStepRegistry,
///   );
///   final plan = factory.buildTestPlan(features);
/// }
/// ```
class FeatureTestFactory<T> {
  final String rootPath;
  final StepRegistry<T> registry;
  final TestStructure structure;

  FeatureTestFactory({
    required this.rootPath,
    required this.registry,
    this.structure = TestStructure.tree,
  });

  /// Builds a test plan from parsed features.
  TestPlan buildTestPlan(List<Feature> features) {
    if (structure == TestStructure.flat) {
      return _buildFlatPlan(features);
    }
    return _buildTreePlan(features);
  }

  TestPlan _buildFlatPlan(List<Feature> features) {
    final groups = features.map((f) => _featureToGroup(f)).toList();
    return TestPlan(groups: groups);
  }

  TestPlan _buildTreePlan(List<Feature> features) {
    // Group features by their relative folder path
    final byFolder = <String, List<Feature>>{};

    for (final feature in features) {
      final relativePath = _getRelativePath(feature.filePath);
      final folder = _getFolder(relativePath);
      byFolder.putIfAbsent(folder, () => []).add(feature);
    }

    // If all features are in the same folder (or root), just do flat
    if (byFolder.length == 1 && byFolder.keys.first.isEmpty) {
      return _buildFlatPlan(features);
    }

    // Build nested groups
    final rootGroups = <TestGroup>[];

    for (final entry in byFolder.entries) {
      final folder = entry.key;
      final folderFeatures = entry.value;

      if (folder.isEmpty) {
        // Root level features
        rootGroups.addAll(folderFeatures.map(_featureToGroup));
      } else {
        // Nested folder
        final children = folderFeatures.map(_featureToGroup).toList();
        rootGroups.add(TestGroup(
          name: folder,
          children: children,
        ));
      }
    }

    return TestPlan(groups: rootGroups);
  }

  TestGroup _featureToGroup(Feature feature) {
    final tests = feature.allScenarios.map((scenario) {
      // Merge feature tags with scenario tags (deduplicated via Set)
      final mergedTags = {...feature.tags, ...scenario.tags}.toList();
      return TestCase(
        name: scenario.name,
        steps: scenario.steps,
        tags: mergedTags,
      );
    }).toList();

    return TestGroup(
      name: feature.name,
      tests: tests,
      backgroundSteps: feature.background?.steps ?? [],
    );
  }

  String _getRelativePath(String filePath) {
    if (filePath.startsWith(rootPath)) {
      var relative = filePath.substring(rootPath.length);
      if (relative.startsWith('/')) relative = relative.substring(1);
      return relative;
    }
    return filePath;
  }

  String _getFolder(String relativePath) {
    final lastSlash = relativePath.lastIndexOf('/');
    if (lastSlash == -1) return '';
    return relativePath.substring(0, lastSlash);
  }

  /// Finds steps that are not registered in the registry.
  /// Returns Steps with location info for error reporting.
  List<Step> findMissingSteps(List<Feature> features) {
    final seen = <String>{};
    final missing = <Step>[];

    for (final feature in features) {
      if (feature.background != null) {
        for (final step in feature.background!.steps) {
          if (!seen.contains(step.text) && registry.match(step.text) == null) {
            seen.add(step.text);
            missing.add(step);
          }
        }
      }
      for (final scenario in feature.allScenarios) {
        for (final step in scenario.steps) {
          if (!seen.contains(step.text) && registry.match(step.text) == null) {
            seen.add(step.text);
            missing.add(step);
          }
        }
      }
    }

    return missing;
  }

  /// Generates placeholder code for missing steps.
  String generatePlaceholders(List<Step> missingSteps) {
    final buffer = StringBuffer();
    buffer.writeln('// Add these step definitions to your registry:');
    buffer.writeln('');

    for (final step in missingSteps) {
      buffer.write(StepRegistry.suggestPlaceholder(step.text));
      buffer.writeln('');
    }

    return buffer.toString();
  }
}

/// A plan describing how tests should be structured and run.
class TestPlan {
  final List<TestGroup> groups;

  TestPlan({required this.groups});

  /// Total number of test cases across all groups.
  int get totalTests => groups.fold(0, (sum, g) => sum + g.totalTests);
}

/// A group of tests (corresponds to a Gherkin Feature or folder).
class TestGroup {
  final String name;
  final List<TestCase> tests;
  final List<TestGroup> children;
  final List<Step> backgroundSteps;

  TestGroup({
    required this.name,
    this.tests = const [],
    this.children = const [],
    this.backgroundSteps = const [],
  });

  int get totalTests =>
      tests.length + children.fold(0, (sum, c) => sum + c.totalTests);
}

/// A single test case (corresponds to a Gherkin Scenario).
class TestCase {
  final String name;
  final List<Step> steps;
  final List<String> tags;

  TestCase({
    required this.name,
    required this.steps,
    this.tags = const [],
  });
}

/// Thrown when feature files reference steps that aren't registered.
class MissingStepsException implements Exception {
  final List<Step> missingSteps;

  MissingStepsException(this.missingSteps);

  @override
  String toString() =>
      'MissingStepsException: ${missingSteps.length} step(s) not found:\n'
      '${missingSteps.map((s) => '  - ${s.location}: ${s.text}').join('\n')}';
}

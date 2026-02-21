/// Configuration for BDD test output verbosity.
///
/// Controls what gets printed during test execution:
/// - Feature names (group headers)
/// - Scenario names (test headers)
/// - Individual steps as they execute
/// - Timing information for each step
class BddOutput {
  /// Whether to print feature names when entering a feature group.
  final bool showFeatureNames;

  /// Whether to print scenario names when starting a scenario.
  final bool showScenarioNames;

  /// Whether to print each step as it executes.
  final bool showSteps;

  /// Whether to include timing for each step (requires showSteps).
  final bool showStepTiming;

  /// Creates a custom output configuration.
  const BddOutput({
    this.showFeatureNames = false,
    this.showScenarioNames = false,
    this.showSteps = false,
    this.showStepTiming = false,
  });

  /// No extra output - rely on test framework's default output.
  static const none = BddOutput();

  /// Show feature and scenario names.
  const BddOutput.scenarios()
      : showFeatureNames = true,
        showScenarioNames = true,
        showSteps = false,
        showStepTiming = false;

  /// Show feature, scenario, and step execution.
  const BddOutput.steps()
      : showFeatureNames = true,
        showScenarioNames = true,
        showSteps = true,
        showStepTiming = false;

  /// Full verbose output including step timing.
  const BddOutput.verbose()
      : showFeatureNames = true,
        showScenarioNames = true,
        showSteps = true,
        showStepTiming = true;

  /// Formats a feature name for display.
  String formatFeature(String name) => '\n📋 Feature: $name';

  /// Formats a scenario name for display.
  String formatScenario(String name) => '  🎬 Scenario: $name';

  /// Formats a step for display (before execution).
  String formatStep(String keyword, String text) => '    $keyword $text';

  /// Formats a completed step with optional timing.
  String formatStepComplete(String keyword, String text, Duration duration) {
    final base = '    ✓ $keyword $text';
    if (showStepTiming) {
      return '$base (${duration.inMilliseconds}ms)';
    }
    return base;
  }

  /// Formats a failed step.
  String formatStepFailed(String keyword, String text) =>
      '    ✗ $keyword $text';

  /// Prints feature name if enabled.
  void printFeature(String name, [void Function(String)? printer]) {
    if (showFeatureNames) {
      (printer ?? _print)(formatFeature(name));
    }
  }

  /// Prints scenario name if enabled.
  void printScenario(String name, [void Function(String)? printer]) {
    if (showScenarioNames) {
      (printer ?? _print)(formatScenario(name));
    }
  }

  /// Prints step if enabled.
  void printStep(String keyword, String text,
      [void Function(String)? printer]) {
    if (showSteps) {
      (printer ?? _print)(formatStep(keyword, text));
    }
  }

  /// Prints completed step if enabled.
  void printStepComplete(
    String keyword,
    String text,
    Duration duration, [
    void Function(String)? printer,
  ]) {
    if (showSteps) {
      (printer ?? _print)(formatStepComplete(keyword, text, duration));
    }
  }

  /// Prints failed step if enabled.
  void printStepFailed(
    String keyword,
    String text, [
    void Function(String)? printer,
  ]) {
    if (showSteps) {
      (printer ?? _print)(formatStepFailed(keyword, text));
    }
  }
}

// ignore: avoid_print
void _print(String s) => print(s);

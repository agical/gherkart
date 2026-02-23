import 'feature_source.dart';

/// Represents a parsed Gherkin feature file.
class Feature {
  final String name;
  final String filePath;
  final String? description;
  final List<String> tags;
  final Background? background;
  final List<Scenario> scenarios;
  final List<ScenarioOutline> scenarioOutlines;

  Feature({
    required this.name,
    required this.filePath,
    this.description,
    this.tags = const [],
    this.background,
    required this.scenarios,
    this.scenarioOutlines = const [],
  });

  /// Returns all scenarios including expanded scenario outlines.
  List<Scenario> get allScenarios => [
        ...scenarios,
        for (final outline in scenarioOutlines) ...outline.expandToScenarios(),
      ];

  @override
  String toString() => 'Feature($name, ${scenarios.length} scenarios, ${scenarioOutlines.length} outlines)';
}

/// Represents the Background section of a feature.
class Background {
  final List<Step> steps;

  Background({required this.steps});
}

/// Represents a Scenario in a feature file.
class Scenario {
  final String name;
  final List<String> tags;
  final List<Step> steps;

  Scenario({
    required this.name,
    this.tags = const [],
    required this.steps,
  });

  @override
  String toString() => 'Scenario($name, ${steps.length} steps)';
}

/// Represents a Scenario Outline with Examples tables.
///
/// A scenario outline is a template that gets expanded into multiple
/// concrete scenarios by substituting placeholders with example values.
///
/// Supports both `<placeholder>` and `{placeholder}` syntax.
class ScenarioOutline {
  final String name;
  final List<String> tags;
  final List<Step> steps;
  final List<ExampleTable> examples;

  ScenarioOutline({
    required this.name,
    this.tags = const [],
    required this.steps,
    required this.examples,
  });

  /// Expands this outline into concrete scenarios by substituting placeholders.
  List<Scenario> expandToScenarios() {
    final result = <Scenario>[];
    for (final exampleTable in examples) {
      for (var rowIndex = 0; rowIndex < exampleTable.rows.length; rowIndex++) {
        final row = exampleTable.rows[rowIndex];
        final values = Map.fromIterables(exampleTable.headers, row);

        // Generate scenario name
        final exampleName =
            exampleTable.name != null ? '${exampleTable.name} #${rowIndex + 1}' : 'Example ${rowIndex + 1}';
        final scenarioName = '$name ($exampleName)';

        // Substitute placeholders in steps
        final expandedSteps = steps.map((step) {
          var text = step.text;
          for (final entry in values.entries) {
            // Support both <placeholder> and {placeholder} syntax
            text = text.replaceAll('<${entry.key}>', entry.value).replaceAll('{${entry.key}}', entry.value);
          }
          return Step(
            keyword: step.keyword,
            text: text,
            location: step.location,
            dataTable: step.dataTable,
            docString: step.docString,
          );
        }).toList();

        result.add(Scenario(
          name: scenarioName,
          tags: [...tags, ...exampleTable.tags],
          steps: expandedSteps,
        ));
      }
    }
    return result;
  }

  @override
  String toString() => 'ScenarioOutline($name, ${steps.length} steps, ${examples.length} examples)';
}

/// Represents an Examples table in a Scenario Outline.
class ExampleTable {
  final String? name;
  final List<String> tags;
  final List<String> headers;
  final List<List<String>> rows;
  final SourceLocation? location;

  ExampleTable({
    this.name,
    this.tags = const [],
    required this.headers,
    required this.rows,
    this.location,
  });

  /// Converts rows to list of maps for easy access.
  List<Map<String, String>> toMaps() => rows.map((row) => Map.fromIterables(headers, row)).toList();

  @override
  String toString() => 'ExampleTable(${name ?? 'unnamed'}, ${headers.length} cols, ${rows.length} rows)';
}

/// Source location for error reporting.
class SourceLocation {
  final String filePath;
  final int line;

  const SourceLocation({required this.filePath, required this.line});

  /// Returns a clickable file:line reference for IDEs.
  @override
  String toString() => '$filePath:$line';
}

/// Represents a data table attached to a step.
///
/// Example in feature file:
/// ```gherkin
/// Given the following users:
///   | name  | email           |
///   | Alice | alice@test.com  |
///   | Bob   | bob@test.com    |
/// ```
class DataTable {
  final List<String> headers;
  final List<List<String>> rows;
  final SourceLocation? location;

  DataTable({
    required this.headers,
    required this.rows,
    this.location,
  });

  /// Converts rows to list of maps using headers as keys.
  List<Map<String, String>> toMaps() => rows.map((row) => Map.fromIterables(headers, row)).toList();

  /// Returns raw rows including header row.
  List<List<String>> get allRows => [headers, ...rows];

  @override
  String toString() => 'DataTable(${headers.length} cols, ${rows.length} rows)';
}

/// Represents a doc string (multi-line string) attached to a step.
///
/// Example in feature file:
/// ```gherkin
/// Given the JSON payload:
///   """json
///   {
///     "name": "Test",
///     "value": 42
///   }
///   """
/// ```
class DocString {
  final String content;
  final String? mediaType;
  final SourceLocation? location;

  DocString({
    required this.content,
    this.mediaType,
    this.location,
  });

  @override
  String toString() => 'DocString(${mediaType ?? 'text'}, ${content.length} chars)';
}

/// Represents a single step (Given/When/Then/And/But).
class Step {
  final StepKeyword keyword;
  final String text;
  final SourceLocation? location;
  final DataTable? dataTable;
  final DocString? docString;

  Step({
    required this.keyword,
    required this.text,
    this.location,
    this.dataTable,
    this.docString,
  });

  /// Returns the full step text including keyword.
  String get fullText => '${keyword.name[0].toUpperCase()}${keyword.name.substring(1)} $text';

  /// Creates a copy with updated fields.
  Step copyWith({
    StepKeyword? keyword,
    String? text,
    SourceLocation? location,
    DataTable? dataTable,
    DocString? docString,
  }) =>
      Step(
        keyword: keyword ?? this.keyword,
        text: text ?? this.text,
        location: location ?? this.location,
        dataTable: dataTable ?? this.dataTable,
        docString: docString ?? this.docString,
      );

  @override
  String toString() => fullText;
}

/// Keywords that can start a step.
enum StepKeyword { given, when, then, and, but }

/// Parses a Gherkin feature file content into a [Feature] object.
Feature parseFeature(String content, String filePath) {
  final lines = content.split('\n');

  String? featureName;
  final featureTags = <String>[];
  final descriptionLines = <String>[];
  Background? background;
  final scenarios = <Scenario>[];
  final scenarioOutlines = <ScenarioOutline>[];

  var currentSection = _Section.none;
  var currentScenarioName = '';
  var currentScenarioTags = <String>[];
  var currentSteps = <Step>[];
  var pendingTags = <String>[];
  var inDescription = false;

  // For Scenario Outline support
  var isOutline = false;
  var currentExamples = <ExampleTable>[];
  var currentExampleName = '';
  var currentExampleTags = <String>[];
  var currentExampleHeaders = <String>[];
  var currentExampleRows = <List<String>>[];
  SourceLocation? exampleLocation;

  // For data table support
  var collectingTable = false;
  var tableHeaders = <String>[];
  var tableRows = <List<String>>[];
  SourceLocation? tableLocation;

  // For doc string support
  var collectingDocString = false;
  var docStringDelimiter = '';
  var docStringMediaType = '';
  var docStringLines = <String>[];
  SourceLocation? docStringLocation;

  void attachTableToLastStep() {
    if (tableHeaders.isNotEmpty && currentSteps.isNotEmpty) {
      final lastStep = currentSteps.removeLast();
      currentSteps.add(lastStep.copyWith(
        dataTable: DataTable(
          headers: tableHeaders,
          rows: tableRows,
          location: tableLocation,
        ),
      ));
    }
    collectingTable = false;
    tableHeaders = [];
    tableRows = [];
    tableLocation = null;
  }

  void attachDocStringToLastStep() {
    if (docStringLines.isNotEmpty && currentSteps.isNotEmpty) {
      final lastStep = currentSteps.removeLast();
      currentSteps.add(lastStep.copyWith(
        docString: DocString(
          content: docStringLines.join('\n'),
          mediaType: docStringMediaType.isNotEmpty ? docStringMediaType : null,
          location: docStringLocation,
        ),
      ));
    }
    collectingDocString = false;
    docStringDelimiter = '';
    docStringMediaType = '';
    docStringLines = [];
    docStringLocation = null;
  }

  void saveCurrentExampleTable() {
    if (currentExampleHeaders.isNotEmpty) {
      currentExamples.add(ExampleTable(
        name: currentExampleName.isNotEmpty ? currentExampleName : null,
        tags: currentExampleTags,
        headers: currentExampleHeaders,
        rows: currentExampleRows,
        location: exampleLocation,
      ));
    }
    currentExampleName = '';
    currentExampleTags = [];
    currentExampleHeaders = [];
    currentExampleRows = [];
    exampleLocation = null;
  }

  void saveCurrentScenarioOrOutline() {
    if (collectingTable) attachTableToLastStep();
    if (collectingDocString) attachDocStringToLastStep();

    if (isOutline) {
      saveCurrentExampleTable();
      if (currentScenarioName.isNotEmpty) {
        scenarioOutlines.add(ScenarioOutline(
          name: currentScenarioName,
          tags: currentScenarioTags,
          steps: currentSteps,
          examples: currentExamples,
        ));
      }
      currentExamples = [];
    } else if (currentScenarioName.isNotEmpty) {
      scenarios.add(Scenario(
        name: currentScenarioName,
        tags: currentScenarioTags,
        steps: currentSteps,
      ));
    }
  }

  for (var lineNumber = 0; lineNumber < lines.length; lineNumber++) {
    final rawLine = lines[lineNumber];
    final line = rawLine.trim();
    // Line numbers are 1-based for user display
    final currentLineNumber = lineNumber + 1;

    // Handle doc string collection
    if (collectingDocString) {
      if (line == docStringDelimiter || line.startsWith(docStringDelimiter)) {
        attachDocStringToLastStep();
        continue;
      }
      // Preserve original indentation relative to the opening delimiter
      docStringLines.add(rawLine);
      continue;
    }

    // Check for doc string start
    if ((line.startsWith('"""') || line.startsWith("'''")) && currentSteps.isNotEmpty) {
      collectingDocString = true;
      docStringDelimiter = line.substring(0, 3);
      // Media type is optional text after the delimiter
      docStringMediaType = line.substring(3).trim();
      docStringLocation = SourceLocation(filePath: filePath, line: currentLineNumber);
      if (collectingTable) attachTableToLastStep();
      continue;
    }

    // Handle data table collection (for steps)
    if (line.startsWith('|') && currentSteps.isNotEmpty && currentSection != _Section.examples) {
      final cells = _parseTableRow(line);
      if (!collectingTable) {
        collectingTable = true;
        tableHeaders = cells;
        tableRows = [];
        tableLocation = SourceLocation(filePath: filePath, line: currentLineNumber);
      } else {
        tableRows.add(cells);
      }
      continue;
    } else if (collectingTable && !line.startsWith('|')) {
      attachTableToLastStep();
    }

    // Handle Examples table collection
    if (line.startsWith('|') && currentSection == _Section.examples) {
      final cells = _parseTableRow(line);
      if (currentExampleHeaders.isEmpty) {
        currentExampleHeaders = cells;
      } else {
        currentExampleRows.add(cells);
      }
      continue;
    }

    // Skip empty lines and comments
    if (line.isEmpty) {
      if (inDescription) inDescription = false;
      continue;
    }
    if (line.startsWith('#')) continue;

    // Skip import statements
    if (line.startsWith('import ')) continue;

    // Parse tags
    if (line.startsWith('@')) {
      final tags = line.split(RegExp(r'\s+')).where((t) => t.startsWith('@')).map((t) => t.substring(1)).toList();
      pendingTags.addAll(tags);
      continue;
    }

    // Parse Feature line
    if (line.startsWith('Feature:')) {
      featureName = line.substring('Feature:'.length).trim();
      featureTags.addAll(pendingTags);
      pendingTags = [];
      currentSection = _Section.feature;
      inDescription = true;
      continue;
    }

    // Parse Background
    if (line.startsWith('Background:')) {
      currentSection = _Section.background;
      currentSteps = [];
      inDescription = false;
      continue;
    }

    // Parse Scenario Outline
    if (line.startsWith('Scenario Outline:') || line.startsWith('Scenario Template:')) {
      // Save previous scenario/outline if exists
      if ((currentSection == _Section.scenario ||
              currentSection == _Section.scenarioOutline ||
              currentSection == _Section.examples) &&
          currentScenarioName.isNotEmpty) {
        saveCurrentScenarioOrOutline();
      }
      // Save background if we were parsing it
      if (currentSection == _Section.background) {
        background = Background(steps: currentSteps);
      }

      final prefix = line.startsWith('Scenario Outline:') ? 'Scenario Outline:' : 'Scenario Template:';
      currentScenarioName = line.substring(prefix.length).trim();
      currentScenarioTags = List.from(pendingTags);
      pendingTags = [];
      currentSteps = [];
      currentExamples = [];
      currentSection = _Section.scenarioOutline;
      isOutline = true;
      inDescription = false;
      continue;
    }

    // Parse Examples
    if (line.startsWith('Examples:') || line.startsWith('Scenarios:')) {
      // Save previous example table if exists
      saveCurrentExampleTable();

      final prefix = line.startsWith('Examples:') ? 'Examples:' : 'Scenarios:';
      currentExampleName = line.substring(prefix.length).trim();
      currentExampleTags = List.from(pendingTags);
      pendingTags = [];
      currentSection = _Section.examples;
      exampleLocation = SourceLocation(filePath: filePath, line: currentLineNumber);
      continue;
    }

    // Parse Scenario
    if (line.startsWith('Scenario:')) {
      // Save previous scenario/outline if exists
      if ((currentSection == _Section.scenario ||
              currentSection == _Section.scenarioOutline ||
              currentSection == _Section.examples) &&
          currentScenarioName.isNotEmpty) {
        saveCurrentScenarioOrOutline();
      }
      // Save background if we were parsing it
      if (currentSection == _Section.background) {
        background = Background(steps: currentSteps);
      }

      currentScenarioName = line.substring('Scenario:'.length).trim();
      currentScenarioTags = List.from(pendingTags);
      pendingTags = [];
      currentSteps = [];
      currentSection = _Section.scenario;
      isOutline = false;
      inDescription = false;
      continue;
    }

    // Parse steps
    final step = _parseStep(line, filePath, currentLineNumber);
    if (step != null) {
      if (collectingTable) attachTableToLastStep();
      currentSteps.add(step);
      inDescription = false;
      continue;
    }

    // Collect description lines (after Feature, before Background/Scenario)
    if (inDescription && currentSection == _Section.feature) {
      descriptionLines.add(line);
    }
  }

  // Finalize any pending table/docstring
  if (collectingTable) attachTableToLastStep();
  if (collectingDocString) attachDocStringToLastStep();

  // Save last scenario/outline
  if ((currentSection == _Section.scenario ||
          currentSection == _Section.scenarioOutline ||
          currentSection == _Section.examples) &&
      currentScenarioName.isNotEmpty) {
    saveCurrentScenarioOrOutline();
  }
  // Save background if feature ends with it (edge case)
  if (currentSection == _Section.background) {
    background = Background(steps: currentSteps);
  }

  return Feature(
    name: featureName ?? 'Unnamed Feature',
    filePath: filePath,
    description: descriptionLines.isNotEmpty ? descriptionLines.join('\n') : null,
    tags: featureTags,
    background: background,
    scenarios: scenarios,
    scenarioOutlines: scenarioOutlines,
  );
}

/// Parses a table row, splitting by | and trimming cells.
List<String> _parseTableRow(String line) {
  return line.split('|').map((cell) => cell.trim()).where((cell) => cell.isNotEmpty).toList();
}

Step? _parseStep(String line, String filePath, int lineNumber) {
  final patterns = {
    'Given ': StepKeyword.given,
    'When ': StepKeyword.when,
    'Then ': StepKeyword.then,
    'And ': StepKeyword.and,
    'But ': StepKeyword.but,
  };

  for (final entry in patterns.entries) {
    if (line.startsWith(entry.key)) {
      return Step(
        keyword: entry.value,
        text: line.substring(entry.key.length).trim(),
        location: SourceLocation(filePath: filePath, line: lineNumber),
      );
    }
  }
  return null;
}

enum _Section { none, feature, background, scenario, scenarioOutline, examples }

/// Discovers all .feature files using the provided source.
///
/// If [rootPath] is a .feature file, returns that single file.
/// If [rootPath] is a directory, recursively finds all .feature files.
Future<List<String>> discoverFeatureFiles(
  String rootPath,
  FeatureSource source,
) async {
  return source.list(rootPath);
}

/// Reads and parses a feature file using the provided source.
Future<Feature> parseFeatureFile(String filePath, FeatureSource source) async {
  final content = await source.read(filePath);
  return parseFeature(content, filePath);
}

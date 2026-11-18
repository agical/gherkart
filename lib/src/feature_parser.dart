import 'package:cucumber_gherkin/cucumber_gherkin.dart';
import 'package:cucumber_messages/cucumber_messages.dart' as cm;

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

  /// Raw Cucumber Messages envelopes (`Source`, `GherkinDocument`, `Pickle`s)
  /// emitted by `cucumber_gherkin` when parsed via [parseFeature].
  final List<cm.Envelope> gherkinEnvelopes;

  final List<Object>? _orderedScenarioItems;

  Feature({
    required this.name,
    required this.filePath,
    this.description,
    this.tags = const [],
    this.background,
    required this.scenarios,
    this.scenarioOutlines = const [],
    this.gherkinEnvelopes = const [],
    List<Object>? orderedScenarioItems,
  }) : _orderedScenarioItems = orderedScenarioItems;

  /// Returns all scenarios including expanded scenario outlines in document order.
  List<Scenario> get allScenarios {
    final ordered = _orderedScenarioItems;
    if (ordered != null) {
      return [
        for (final item in ordered)
          if (item is Scenario) item else if (item is ScenarioOutline) ...item.expandToScenarios(),
      ];
    }
    return [...scenarios, for (final outline in scenarioOutlines) ...outline.expandToScenarios()];
  }

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

  /// Compiled Cucumber [cm.Pickle] associated with this scenario, if parsed via [parseFeature].
  final cm.Pickle? pickle;

  Scenario({required this.name, this.tags = const [], required this.steps, this.pickle});

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

  ScenarioOutline({required this.name, this.tags = const [], required this.steps, required this.examples});

  /// Expands this outline into concrete scenarios by substituting placeholders.
  List<Scenario> expandToScenarios() {
    final result = <Scenario>[];
    for (final exampleTable in examples) {
      for (var rowIndex = 0; rowIndex < exampleTable.rows.length; rowIndex++) {
        final row = exampleTable.rows[rowIndex];
        final headers = exampleTable.headers;

        // Generate scenario name (interpolating any <param> in outline title)
        final interpolatedTitle = _substituteCells(name, headers, row);
        final exampleName = exampleTable.name != null
            ? '${exampleTable.name} #${rowIndex + 1}'
            : 'Example ${rowIndex + 1}';
        final scenarioName = '$interpolatedTitle ($exampleName)';

        // Substitute placeholders in steps, data tables, and doc strings (including mediaType)
        final expandedSteps = steps.map((step) {
          final text = _substituteCells(step.text, headers, row);
          final dataTable = step.dataTable != null
              ? DataTable(
                  headers: step.dataTable!.headers.map((h) => _substituteCells(h, headers, row)).toList(),
                  rows: step.dataTable!.rows
                      .map((r) => r.map((cell) => _substituteCells(cell, headers, row)).toList())
                      .toList(),
                  location: step.dataTable!.location,
                )
              : null;
          final docString = step.docString != null
              ? DocString(
                  content: _substituteCells(step.docString!.content, headers, row),
                  mediaType: step.docString!.mediaType != null
                      ? _substituteCells(step.docString!.mediaType!, headers, row)
                      : null,
                  location: step.docString!.location,
                )
              : null;

          return Step(
            keyword: step.keyword,
            text: text,
            location: step.location,
            dataTable: dataTable,
            docString: docString,
            originalKeyword: step.originalKeyword,
          );
        }).toList();

        final rowPickle = rowIndex < exampleTable.rowPickles.length ? exampleTable.rowPickles[rowIndex] : null;

        result.add(
          Scenario(name: scenarioName, tags: [...tags, ...exampleTable.tags], steps: expandedSteps, pickle: rowPickle),
        );
      }
    }
    return result;
  }

  static String _substituteCells(String template, List<String> headers, List<String> row) {
    if (!template.contains('<') && !template.contains('{')) {
      return template;
    }
    var result = template;
    final len = headers.length < row.length ? headers.length : row.length;
    for (var i = 0; i < len; i++) {
      final key = headers[i];
      final val = row[i];
      // Support both <placeholder> and {placeholder} syntax
      result = result.replaceAll('<$key>', val).replaceAll('{$key}', val);
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
  final List<cm.Pickle?> rowPickles;

  ExampleTable({
    this.name,
    this.tags = const [],
    required this.headers,
    required this.rows,
    this.location,
    this.rowPickles = const [],
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
  final int? column;

  const SourceLocation({required this.filePath, required this.line, this.column});

  /// Returns a clickable file:line reference for IDEs.
  @override
  String toString() => column != null ? '$filePath:$line:$column' : '$filePath:$line';
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

  DataTable({required this.headers, required this.rows, this.location});

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

  DocString({required this.content, this.mediaType, this.location});

  @override
  String toString() => 'DocString(${mediaType ?? 'text'}, ${content.length} chars)';
}

/// Represents a single step (Given/When/Then/And/But/*).
class Step {
  final StepKeyword keyword;
  final String text;
  final SourceLocation? location;
  final DataTable? dataTable;
  final DocString? docString;
  final String? originalKeyword;

  Step({
    required this.keyword,
    required this.text,
    this.location,
    this.dataTable,
    this.docString,
    this.originalKeyword,
  });

  /// Returns the full step text including keyword.
  String get fullText {
    if (originalKeyword != null && originalKeyword!.isNotEmpty) {
      final sep = originalKeyword!.endsWith(' ') ? '' : ' ';
      return '$originalKeyword$sep$text';
    }
    if (keyword == StepKeyword.star) return '* $text';
    return '${keyword.name[0].toUpperCase()}${keyword.name.substring(1)} $text';
  }

  /// Creates a copy with updated fields.
  Step copyWith({
    StepKeyword? keyword,
    String? text,
    SourceLocation? location,
    DataTable? dataTable,
    DocString? docString,
    String? originalKeyword,
  }) => Step(
    keyword: keyword ?? this.keyword,
    text: text ?? this.text,
    location: location ?? this.location,
    dataTable: dataTable ?? this.dataTable,
    docString: docString ?? this.docString,
    originalKeyword: originalKeyword ?? this.originalKeyword,
  );

  @override
  String toString() => fullText;
}

/// Keywords that can start a step.
enum StepKeyword { given, when, then, and, but, star }

/// Thrown when parsing a Gherkin document fails.
class GherkinParseException implements Exception {
  final String message;
  final String filePath;
  final int? line;
  final int? column;
  final List<cm.ParseError> parseErrors;

  GherkinParseException(this.message, {required this.filePath, this.line, this.column, this.parseErrors = const []});

  @override
  String toString() {
    final loc = line != null ? (column != null ? '$filePath:$line:$column' : '$filePath:$line') : filePath;
    return 'GherkinParseException: $message at $loc';
  }
}

/// Sanitizes legacy or non-standard Gherkin syntax before passing to the official parser.
///
/// Converts:
/// - Unused `import` statements at the top of feature files into comments.
/// - Triple single-quote docstrings (`'''`) to triple double-quotes (`"""`).
/// - `{placeholder}` in Scenario Outline steps to `<placeholder>` when matching Examples headers.
///
/// For each deprecated syntax pattern found, emits an actionable warning via [onWarning].
String sanitizeGherkin(String content, String filePath, {void Function(String message)? onWarning}) {
  final warn = onWarning ?? print;
  final lines = content.split('\n');
  var modified = false;

  // 1. Process legacy top-of-file imports and triple-single-quote docstrings,
  //    properly respecting active docstring blocks so content inside """ or ```
  //    is never altered.
  var activeDocDelimiter = '';
  var beforeFeature = true;

  for (var i = 0; i < lines.length; i++) {
    final rawLine = lines[i];
    final trimmed = rawLine.trim();
    final lineNum = i + 1;

    if (activeDocDelimiter.isNotEmpty) {
      if (trimmed.startsWith(activeDocDelimiter)) {
        if (activeDocDelimiter == "'''") {
          warn(
            '[gherkart] Deprecation: Found triple single-quote docstring (\'\'\') at $filePath:$lineNum.\n'
            'Standard Gherkin requires triple double-quotes (""") or backticks (```).\n'
            'Fix with:\n'
            '  sed -i \'\' "s/\'\'\'/\\"\\"\\"/g" $filePath',
          );
          lines[i] = rawLine.replaceFirst("'''", '"""');
          modified = true;
        }
        activeDocDelimiter = '';
      }
      continue;
    }

    if (trimmed.startsWith('"""')) {
      activeDocDelimiter = '"""';
      beforeFeature = false;
      continue;
    }

    if (trimmed.startsWith('```')) {
      activeDocDelimiter = '```';
      beforeFeature = false;
      continue;
    }

    if (trimmed.startsWith("'''")) {
      warn(
        '[gherkart] Deprecation: Found triple single-quote docstring (\'\'\') at $filePath:$lineNum.\n'
        'Standard Gherkin requires triple double-quotes (""") or backticks (```).\n'
        'Fix with:\n'
        '  sed -i \'\' "s/\'\'\'/\\"\\"\\"/g" $filePath',
      );
      lines[i] = rawLine.replaceFirst("'''", '"""');
      activeDocDelimiter = "'''";
      beforeFeature = false;
      modified = true;
      continue;
    }

    // Check for legacy Dart import at the top of the file (before Feature:)
    if (beforeFeature && trimmed.startsWith('import ')) {
      warn(
        '[gherkart] Deprecation: Found unused Dart import in .feature file at $filePath:$lineNum.\n'
        'gherkart parses at runtime and does not need imports in feature files.\n'
        'Remove with:\n'
        "  sed -i '' '/^import /d' $filePath",
      );
      if (rawLine.endsWith('\r')) {
        lines[i] = '# ${rawLine.substring(0, rawLine.length - 1)}\r';
      } else {
        lines[i] = '# $rawLine';
      }
      modified = true;
      continue;
    }

    if (trimmed.isNotEmpty && !trimmed.startsWith('#') && !trimmed.startsWith('@')) {
      beforeFeature = false;
    }
  }

  // 2. Process Scenario Outline {header} placeholders
  var inScenarioBlock = false;
  var inExamplesSection = false;
  var awaitingExampleHeader = false;
  var docDelimiter = '';
  var outlineStepIndices = <int>[];
  var outlineHeaders = <String>{};

  void flushOutline() {
    if (outlineHeaders.isNotEmpty && outlineStepIndices.isNotEmpty) {
      final headerPattern = outlineHeaders.map(RegExp.escape).join('|');
      final placeholderRegex = RegExp('\\{($headerPattern)\\}');
      final foundPlaceholders = <String>{};
      final affectedLines = <int>[];

      for (final stepIdx in outlineStepIndices) {
        final line = lines[stepIdx];
        final matches = placeholderRegex.allMatches(line);
        if (matches.isNotEmpty) {
          affectedLines.add(stepIdx + 1);
          for (final m in matches) {
            foundPlaceholders.add(m.group(1)!);
          }
          lines[stepIdx] = line.replaceAllMapped(placeholderRegex, (m) => '<${m.group(1)}>');
          modified = true;
        }
      }

      if (foundPlaceholders.isNotEmpty) {
        final joinedHeaders = foundPlaceholders.join('|');
        final firstLine = affectedLines.first;
        warn(
          '[gherkart] Deprecation: Scenario Outline in $filePath:$firstLine uses \'{param}\' instead of \'<param>\'.\n'
          'Standard Gherkin requires \'<param>\' for outline substitutions.\n\n'
          '1. Find potential candidate lines:\n'
          '   grep -nE \'\\{($joinedHeaders)\\}\' $filePath\n\n'
          '2. Replace curly braces for the example headers in this file:\n'
          '   sed -i \'\' -E \'s/\\{($joinedHeaders)\\}/<\\1>/g\' $filePath',
        );
      }
    }
    outlineStepIndices = [];
    outlineHeaders = {};
    inExamplesSection = false;
    awaitingExampleHeader = false;
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();

    if (docDelimiter.isNotEmpty) {
      if (line.startsWith(docDelimiter)) {
        docDelimiter = '';
      } else if (inScenarioBlock && !inExamplesSection) {
        outlineStepIndices.add(i);
      }
      continue;
    }

    if (line.startsWith('"""')) {
      docDelimiter = '"""';
      if (inScenarioBlock && !inExamplesSection) {
        outlineStepIndices.add(i);
      }
      continue;
    }

    if (line.startsWith('```')) {
      docDelimiter = '```';
      if (inScenarioBlock && !inExamplesSection) {
        outlineStepIndices.add(i);
      }
      continue;
    }

    if (line.startsWith('Scenario Outline:') ||
        line.startsWith('Scenario Template:') ||
        line.startsWith('Scenario:') ||
        line.startsWith('Example:')) {
      if (inScenarioBlock) {
        flushOutline();
      }
      inScenarioBlock = true;
      inExamplesSection = false;
      awaitingExampleHeader = false;
      outlineStepIndices = [];
      outlineHeaders = {};
      continue;
    }

    if (inScenarioBlock) {
      if (line.startsWith('Rule:') || line.startsWith('Feature:') || line.startsWith('Background:')) {
        flushOutline();
        inScenarioBlock = false;
        continue;
      }

      if (line.startsWith('Examples:') || line.startsWith('Scenarios:')) {
        inExamplesSection = true;
        awaitingExampleHeader = true;
        continue;
      }

      if (inExamplesSection) {
        if (line.startsWith('|') && awaitingExampleHeader) {
          final cells = line.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
          outlineHeaders.addAll(cells);
          awaitingExampleHeader = false;
        }
        continue;
      }

      if (!line.startsWith('@') && !line.startsWith('#') && line.isNotEmpty) {
        outlineStepIndices.add(i);
      }
    }
  }

  if (inScenarioBlock) {
    flushOutline();
  }

  if (!modified) {
    return content;
  }
  return lines.join('\n');
}

/// Parses a Gherkin feature file content into a [Feature] object.
Feature parseFeature(
  String content,
  String filePath, {
  void Function(String message)? onWarning,
  String Function()? idGenerator,
}) {
  final sanitized = sanitizeGherkin(content, filePath, onWarning: onWarning);
  final messages = generateMessages(
    sanitized,
    filePath,
    GherkinOptions(includeSource: true, includeGherkinDocument: true, includePickles: true, idGenerator: idGenerator),
  );

  final parseErrors = <cm.ParseError>[];
  cm.GherkinDocument? document;
  final picklesByAstKey = <String, cm.Pickle>{};

  for (final envelope in messages) {
    if (envelope.parseError != null) {
      parseErrors.add(envelope.parseError!);
    }
    if (envelope.gherkinDocument != null) {
      document = envelope.gherkinDocument;
    }
    if (envelope.pickle != null) {
      final pickle = envelope.pickle!;
      picklesByAstKey[pickle.astNodeIds.join(':')] = pickle;
    }
  }

  if (parseErrors.isNotEmpty) {
    final first = parseErrors.first;
    throw GherkinParseException(
      parseErrors.map((e) => e.message).join('\n'),
      filePath: filePath,
      line: first.source.location?.line,
      column: first.source.location?.column,
      parseErrors: parseErrors,
    );
  }

  final f = document?.feature;
  if (f == null) {
    return Feature(
      name: 'Unnamed Feature',
      filePath: filePath,
      scenarios: [],
      gherkinEnvelopes: messages,
      orderedScenarioItems: const [],
    );
  }

  Background? background;
  final scenarios = <Scenario>[];
  final scenarioOutlines = <ScenarioOutline>[];
  final orderedScenarioItems = <Object>[];

  for (final child in f.children) {
    if (child.background != null) {
      background = _convertBackground(child.background!, filePath);
    }
    if (child.scenario != null) {
      _addScenarioOrOutline(
        child.scenario!,
        filePath,
        scenarios,
        scenarioOutlines,
        orderedScenarioItems,
        picklesByAstKey,
      );
    }
    if (child.rule != null) {
      final rule = child.rule!;
      final ruleTags = rule.tags.map((t) => _cleanTag(t.name)).toList();
      Background? ruleBackground;
      for (final ruleChild in rule.children) {
        if (ruleChild.background != null) {
          ruleBackground = _convertBackground(ruleChild.background!, filePath);
        }
        if (ruleChild.scenario != null) {
          _addScenarioOrOutline(
            ruleChild.scenario!,
            filePath,
            scenarios,
            scenarioOutlines,
            orderedScenarioItems,
            picklesByAstKey,
            ruleTags: ruleTags,
            extraBackground: ruleBackground,
          );
        }
      }
    }
  }

  return Feature(
    name: f.name.isEmpty ? 'Unnamed Feature' : f.name,
    filePath: filePath,
    description: _cleanDescription(f.description),
    tags: f.tags.map((t) => _cleanTag(t.name)).toList(),
    background: background,
    scenarios: scenarios,
    scenarioOutlines: scenarioOutlines,
    gherkinEnvelopes: messages,
    orderedScenarioItems: orderedScenarioItems,
  );
}

void _addScenarioOrOutline(
  cm.Scenario sc,
  String filePath,
  List<Scenario> scenarios,
  List<ScenarioOutline> scenarioOutlines,
  List<Object> orderedScenarioItems,
  Map<String, cm.Pickle> picklesByAstKey, {
  List<String> ruleTags = const [],
  Background? extraBackground,
}) {
  final tags = [...ruleTags, ...sc.tags.map((t) => _cleanTag(t.name))];

  final extraSteps = extraBackground?.steps ?? const <Step>[];
  final scenarioSteps = sc.steps.map((s) => _convertStep(s, filePath)).toList();
  // Per Gherkin Pickle compilation rules, empty scenarios do not inherit background steps.
  final allSteps = scenarioSteps.isEmpty ? const <Step>[] : [...extraSteps, ...scenarioSteps];

  if (sc.examples.isEmpty) {
    final scenario = Scenario(name: sc.name, tags: tags, steps: allSteps, pickle: picklesByAstKey[sc.id]);
    scenarios.add(scenario);
    orderedScenarioItems.add(scenario);
  } else {
    final examples = sc.examples.map((ex) {
      final headers = ex.tableHeader?.cells.map((c) => c.value).toList() ?? [];
      final rows = ex.tableBody.map((r) => r.cells.map((c) => c.value).toList()).toList();
      final rowPickles = ex.tableBody.map((r) => picklesByAstKey['${sc.id}:${r.id}']).toList();
      return ExampleTable(
        name: ex.name.trim().isNotEmpty ? ex.name.trim() : null,
        tags: ex.tags.map((t) => _cleanTag(t.name)).toList(),
        headers: headers,
        rows: rows,
        location: SourceLocation(filePath: filePath, line: ex.location.line, column: ex.location.column),
        rowPickles: rowPickles,
      );
    }).toList();

    final outline = ScenarioOutline(name: sc.name, tags: tags, steps: allSteps, examples: examples);
    scenarioOutlines.add(outline);
    orderedScenarioItems.add(outline);
  }
}

Step _convertStep(cm.Step s, String filePath) {
  final keyword = _mapKeyword(s.keyword, s.keywordType);
  return Step(
    keyword: keyword,
    text: s.text,
    location: SourceLocation(filePath: filePath, line: s.location.line, column: s.location.column),
    dataTable: _mapDataTable(s.dataTable, filePath),
    docString: _mapDocString(s.docString, filePath),
    originalKeyword: s.keyword,
  );
}

StepKeyword _mapKeyword(String keyword, cm.StepKeywordType? keywordType) {
  final trimmed = keyword.trim().toLowerCase();
  switch (trimmed) {
    case 'given':
      return StepKeyword.given;
    case 'when':
      return StepKeyword.when;
    case 'then':
      return StepKeyword.then;
    case 'and':
      return StepKeyword.and;
    case 'but':
      return StepKeyword.but;
    case '*':
      return StepKeyword.star;
    default:
      if (keywordType != null) {
        switch (keywordType) {
          case cm.StepKeywordType.context:
            return StepKeyword.given;
          case cm.StepKeywordType.action:
            return StepKeyword.when;
          case cm.StepKeywordType.outcome:
            return StepKeyword.then;
          case cm.StepKeywordType.conjunction:
            return StepKeyword.and;
          case cm.StepKeywordType.unknown:
            return StepKeyword.star;
        }
      }
      return StepKeyword.given;
  }
}

DataTable? _mapDataTable(cm.DataTable? table, String filePath) {
  if (table == null || table.rows.isEmpty) return null;
  final headerRow = table.rows.first;
  final headers = headerRow.cells.map((c) => c.value).toList();
  final rows = table.rows.skip(1).map((r) => r.cells.map((c) => c.value).toList()).toList();
  return DataTable(
    headers: headers,
    rows: rows,
    location: SourceLocation(filePath: filePath, line: headerRow.location.line, column: headerRow.location.column),
  );
}

DocString? _mapDocString(cm.DocString? docString, String filePath) {
  if (docString == null) return null;
  return DocString(
    content: docString.content,
    mediaType: docString.mediaType != null && docString.mediaType!.isNotEmpty ? docString.mediaType : null,
    location: SourceLocation(filePath: filePath, line: docString.location.line, column: docString.location.column),
  );
}

Background _convertBackground(cm.Background bg, String filePath) {
  return Background(steps: bg.steps.map((s) => _convertStep(s, filePath)).toList());
}

String? _cleanDescription(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final trimmedLines = raw.split('\n').map((l) => l.trim()).toList();
  while (trimmedLines.isNotEmpty && trimmedLines.first.isEmpty) {
    trimmedLines.removeAt(0);
  }
  while (trimmedLines.isNotEmpty && trimmedLines.last.isEmpty) {
    trimmedLines.removeLast();
  }
  if (trimmedLines.isEmpty) return null;

  final normalized = <String>[];
  var lastWasEmpty = false;
  for (final line in trimmedLines) {
    if (line.isEmpty) {
      if (!lastWasEmpty) {
        normalized.add('');
        lastWasEmpty = true;
      }
    } else {
      normalized.add(line);
      lastWasEmpty = false;
    }
  }
  return normalized.join('\n');
}

String _cleanTag(String tag) => tag.startsWith('@') ? tag.substring(1) : tag;

/// Discovers all .feature files using the provided source.
///
/// If [rootPath] is a .feature file, returns that single file.
/// If [rootPath] is a directory, recursively finds all .feature files.
Future<List<String>> discoverFeatureFiles(String rootPath, FeatureSource source) async {
  return source.list(rootPath);
}

/// Reads and parses a feature file using the provided source.
Future<Feature> parseFeatureFile(
  String filePath,
  FeatureSource source, {
  void Function(String message)? onWarning,
}) async {
  final content = await source.read(filePath);
  return parseFeature(content, filePath, onWarning: onWarning);
}

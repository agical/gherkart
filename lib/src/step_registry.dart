import 'package:cucumber_expressions/cucumber_expressions.dart' as ce;

import 'feature_parser.dart';
import 'line_mapper.dart';

/// Context passed to step functions containing all step data.
///
/// Provides access to:
/// - [args] - extracted parameters from the step text
/// - [table] - optional data table attached to the step
/// - [docString] - optional doc string attached to the step
/// - [location] - source location for error reporting
///
/// Example usage:
/// ```dart
/// 'I have the following users:'.mapper(): ($, ctx) async {
///   for (final row in ctx.tableRows) {
///     await createUser(row['name']!, row['email']!);
///   }
/// },
/// ```
class StepContext {
  /// Extracted parameters from the step text pattern.
  final List<dynamic> args;

  /// Optional data table attached to the step.
  final DataTable? table;

  /// Optional doc string attached to the step.
  final DocString? docString;

  /// Source location of the step for error reporting.
  final SourceLocation? location;

  const StepContext({required this.args, this.table, this.docString, this.location});

  /// Creates a StepContext with only args (for direct step calls).
  factory StepContext.withArgs(List<dynamic> args) => StepContext(args: args);

  /// Creates an empty StepContext (for steps with no parameters).
  static const empty = StepContext(args: []);

  /// Gets a typed argument at the given index.
  T arg<T>(int index) => args[index] as T;

  /// Gets the first argument as a String.
  String get firstArg => args[0] as String;

  /// Returns true if this step has a data table.
  bool get hasTable => table != null;

  /// Returns true if this step has a doc string.
  bool get hasDocString => docString != null;

  /// Convenience: gets table rows as maps (throws if no table).
  List<Map<String, String>> get tableRows {
    if (table == null) {
      throw StateError('Step has no data table');
    }
    return table!.toMaps();
  }

  /// Convenience: gets doc string content (throws if no doc string).
  String get docContent {
    if (docString == null) {
      throw StateError('Step has no doc string');
    }
    return docString!.content;
  }
}

/// A function that executes a step with context.
///
/// The context type T allows passing test infrastructure (e.g., PatrolTester).
typedef StepFunction<T> = Future<void> Function(T context, StepContext ctx);

/// Result of matching a step, containing the matched function and parameters.
class StepMatch<T> {
  final StepFunction<T> function;
  final List<dynamic> params;

  StepMatch({required this.function, required this.params});

  /// Executes the step with the given context.
  ///
  /// If [resolvedArgs] is provided, it overrides the [params] from the match.
  /// This allows scheme resolution to replace placeholder values.
  Future<void> execute(
    T context, {
    DataTable? table,
    DocString? docString,
    SourceLocation? location,
    List<dynamic>? resolvedArgs,
  }) {
    return function(
      context,
      StepContext(args: resolvedArgs ?? params, table: table, docString: docString, location: location),
    );
  }
}

/// Metadata about a custom [ce.ParameterType] registered on a [StepRegistry].
class CustomParameterTypeInfo {
  final String name;
  final List<String> regularExpressions;
  final bool preferForRegularExpressionMatch;
  final bool useForSnippets;

  const CustomParameterTypeInfo({
    required this.name,
    required this.regularExpressions,
    required this.preferForRegularExpressionMatch,
    required this.useForSnippets,
  });
}

/// Type-erased interface allowing reporters (such as `NdjsonReporter`) to
/// inspect registered step definitions and matched argument offsets regardless
/// of the registry's context type parameter `T`.
abstract interface class StepDefinitionProvider {
  /// Number of registered step definitions.
  int get stepCount;

  /// Pattern source string for the step definition at [index], if available.
  String? patternAt(int index);

  /// Whether the step definition at [index] is a regular expression.
  bool isRegularExpressionAt(int index);

  /// Custom parameter types registered on this provider.
  List<CustomParameterTypeInfo> get customParameterTypes;

  /// Generates candidate Dart step snippet strings for an undefined [stepText].
  List<String> generateSnippets(String stepText);

  /// Matches [line] against registered step definitions and returns the matched
  /// definition index and argument offsets, or `null` if unmatched.
  StepDefinitionMatchInfo? matchStepDefinition(String line);
}

/// Information about a step definition match for Cucumber Messages reporting.
class StepDefinitionMatchInfo {
  final int definitionIndex;
  final List<MatchedArgumentInfo> arguments;

  const StepDefinitionMatchInfo({required this.definitionIndex, this.arguments = const []});
}

/// Registry for mapping step patterns to their implementations.
///
/// Supports both official Cucumber Expressions (via [step], [given], [when],
/// [then], [regex], or `String.cucumber()`) and `String.mapper()` patterns:
///
/// ```dart
/// final registry = StepRegistry<PatrolTester>()
///   ..given('the app is running', ($, ctx) async {
///     await $.pumpWidget(const App());
///   })
///   ..when('I add {int} item(s) to {string}', ($, ctx) async {
///     final count = ctx.arg<int>(0);
///     final cart = ctx.arg<String>(1);
///   });
/// ```
class StepRegistry<T> implements StepDefinitionProvider {
  final List<_StepEntry<T>> _entries = [];
  final ce.ParameterTypeRegistry _parameterTypes;
  final List<ce.ParameterType<Object?>> _customParameterTypeRefs = [];

  /// Creates an empty registry, optionally seeded with [parameterTypes].
  StepRegistry({ce.ParameterTypeRegistry? parameterTypes})
    : _parameterTypes = parameterTypes ?? ce.ParameterTypeRegistry();

  /// Creates a registry from a map of mappers to step functions.
  factory StepRegistry.fromMap(Map<LineMapper, StepFunction<T>> steps, {ce.ParameterTypeRegistry? parameterTypes}) {
    final registry = StepRegistry<T>(parameterTypes: parameterTypes);
    for (final entry in steps.entries) {
      registry.register(entry.key, entry.value);
    }
    return registry;
  }

  ///Creates a registry from a map of Cucumber Expression strings to step functions.
  factory StepRegistry.fromExpressions(
    Map<String, StepFunction<T>> expressions, {
    ce.ParameterTypeRegistry? parameterTypes,
  }) {
    final registry = StepRegistry<T>(parameterTypes: parameterTypes);
    for (final entry in expressions.entries) {
      registry.step(entry.key, entry.value);
    }
    return registry;
  }

  /// The underlying [ce.ParameterTypeRegistry] used when compiling Cucumber Expressions.
  ce.ParameterTypeRegistry get parameterTypes => _parameterTypes;

  /// Registers a custom [ce.ParameterType] for use in Cucumber Expressions and snippet generation.
  void defineParameterType<P>(ce.ParameterType<P> parameterType) {
    _parameterTypes.defineParameterType(parameterType);
    _customParameterTypeRefs.add(parameterType);
  }

  /// Registers a step using a [LineMapper] (from `.cucumber()`, `.mapper()`, or `RegExp.mapper()`).
  void register(LineMapper mapper, StepFunction<T> function) {
    _entries.add(_StepEntry(mapper: mapper, function: function));
  }

  /// Registers a step using an official Cucumber Expression [expression].
  ///
  /// Supports `{int}`, `{float}`, `{string}`, `{word}`, `{}`, custom parameter
  /// types registered via [defineParameterType], optional text `(s)`, and
  /// alternatives `is/are`.
  void step(String expression, StepFunction<T> function) {
    final compiled = ce.ExpressionFactory(_parameterTypes).createExpression(expression);
    register(createExpressionLineMapper(compiled), function);
  }

  /// Alias for [step] for `Given` steps.
  void given(String expression, StepFunction<T> function) => step(expression, function);

  /// Alias for [step] for `When` steps.
  void when(String expression, StepFunction<T> function) => step(expression, function);

  /// Alias for [step] for `Then` steps.
  void then(String expression, StepFunction<T> function) => step(expression, function);

  /// Alias for [step] for `And` steps.
  void and(String expression, StepFunction<T> function) => step(expression, function);

  /// Alias for [step] for `But` steps.
  void but(String expression, StepFunction<T> function) => step(expression, function);

  /// Registers a step using a [RegExp] regular expression backed by `cucumber_expressions`.
  void regex(RegExp pattern, StepFunction<T> function) {
    final compiled = ce.ExpressionFactory(_parameterTypes).createExpression(pattern);
    register(createExpressionLineMapper(compiled, isRegularExpression: true), function);
  }

  /// Attempts to match a step line against registered patterns.
  ///
  /// Returns a [StepMatch] if found, or null if no pattern matches.
  StepMatch<T>? match(String line) {
    for (final entry in _entries) {
      final params = entry.mapper(line);
      if (params != null) {
        return StepMatch(function: entry.function, params: params);
      }
    }
    return null;
  }

  /// Returns the number of registered steps.
  @override
  int get stepCount => _entries.length;

  @override
  String? patternAt(int index) {
    if (index < 0 || index >= _entries.length) return null;
    final meta = lineMapperMetadata[_entries[index].mapper];
    return meta?.expressionSource;
  }

  @override
  bool isRegularExpressionAt(int index) {
    if (index < 0 || index >= _entries.length) return false;
    final meta = lineMapperMetadata[_entries[index].mapper];
    return meta?.isRegularExpression ?? false;
  }

  @override
  List<CustomParameterTypeInfo> get customParameterTypes => _customParameterTypeRefs
      .where((p) => p.name != null && p.name!.isNotEmpty)
      .map(
        (p) => CustomParameterTypeInfo(
          name: p.name!,
          regularExpressions: p.regexpStrings,
          preferForRegularExpressionMatch: p.preferForRegexpMatch,
          useForSnippets: p.useForSnippets,
        ),
      )
      .toList();

  @override
  List<String> generateSnippets(String stepText) {
    return suggestPlaceholders(stepText, parameterTypes: _parameterTypes);
  }

  @override
  StepDefinitionMatchInfo? matchStepDefinition(String line) {
    for (var i = 0; i < _entries.length; i++) {
      final mapper = _entries[i].mapper;
      final params = mapper(line);
      if (params != null) {
        final meta = lineMapperMetadata[mapper];
        final args = meta?.matchArguments(line) ?? const <MatchedArgumentInfo>[];
        return StepDefinitionMatchInfo(definitionIndex: i, arguments: args);
      }
    }
    return null;
  }

  /// Creates a new registry combining this one with another.
  ///
  /// Steps and custom parameter types from both registries are preserved, with
  /// steps from this registry taking precedence over steps from [other].
  StepRegistry<T> merge(StepRegistry<T> other) {
    final mergedTypes = ce.ParameterTypeRegistry();
    final mergedCustomRefs = <ce.ParameterType<Object?>>[];
    final seenNames = <String>{};

    for (final pt in [..._customParameterTypeRefs, ...other._customParameterTypeRefs]) {
      final name = pt.name;
      if (name == null || seenNames.add(name)) {
        mergedTypes.defineParameterType(pt);
        mergedCustomRefs.add(pt);
      }
    }

    final merged = StepRegistry<T>(parameterTypes: mergedTypes);
    merged._customParameterTypeRefs.addAll(mergedCustomRefs);
    for (final entry in _entries) {
      merged._entries.add(entry);
    }
    for (final entry in other._entries) {
      merged._entries.add(entry);
    }
    return merged;
  }

  /// Generates all candidate Cucumber Expression step definition snippets for
  /// [stepText] using official [ce.CucumberExpressionGenerator].
  static List<String> suggestPlaceholders(String stepText, {ce.ParameterTypeRegistry? parameterTypes}) {
    final generator = ce.CucumberExpressionGenerator(parameterTypes ?? ce.ParameterTypeRegistry());
    final generated = generator.generateExpressions(stepText);
    if (generated.isEmpty) {
      return [_formatGeneratedSnippet(stepText, null)];
    }
    return generated.map((expr) => _formatGeneratedSnippet(stepText, expr)).toList();
  }

  /// Generates a ready-to-paste Dart step definition snippet for a missing step,
  /// powered by official [ce.CucumberExpressionGenerator].
  static String suggestPlaceholder(String stepText, {ce.ParameterTypeRegistry? parameterTypes}) {
    return suggestPlaceholders(stepText, parameterTypes: parameterTypes).first;
  }

  static String _formatGeneratedSnippet(String stepText, ce.GeneratedExpression? expr) {
    final buffer = StringBuffer();
    buffer.writeln('// Missing step: $stepText');
    final source = (expr?.source ?? stepText).replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    buffer.writeln("'$source'.cucumber(): (\$, ctx) async {");
    if (expr != null) {
      final names = expr.parameterNames;
      for (var i = 0; i < expr.parameterTypes.length; i++) {
        final dartType = expr.parameterTypes[i].type ?? 'Object?';
        final varName = _sanitizeIdentifier(names[i], i);
        buffer.writeln('  final $varName = ctx.arg<$dartType>($i);');
      }
    }
    buffer.writeln('  // TODO: implement step');
    buffer.writeln('},');
    return buffer.toString();
  }

  static const Set<String> _dartReservedWords = {
    'int',
    'double',
    'num',
    'bool',
    'var',
    'final',
    'const',
    'void',
    'null',
    'true',
    'false',
    'class',
    'enum',
    'switch',
    'case',
    'default',
    'if',
    'else',
    'for',
    'while',
    'do',
    'in',
    'is',
    'as',
    'return',
    'new',
    'this',
    'super',
  };

  static String _sanitizeIdentifier(String raw, int index) {
    var cleaned = raw.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    if (cleaned.isEmpty) return 'arg${index + 1}';
    if (_dartReservedWords.contains(cleaned)) {
      return '${cleaned}Val';
    }
    return cleaned;
  }
}

class _StepEntry<T> {
  final LineMapper mapper;
  final StepFunction<T> function;

  _StepEntry({required this.mapper, required this.function});
}

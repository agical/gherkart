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

  const StepContext({
    required this.args,
    this.table,
    this.docString,
    this.location,
  });

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
      StepContext(
        args: resolvedArgs ?? params,
        table: table,
        docString: docString,
        location: location,
      ),
    );
  }
}

/// Registry for mapping step patterns to their implementations.
///
/// Example:
/// ```dart
/// final registry = StepRegistry<PatrolTester>.fromMap({
///   'the app is running'.mapper(): ($, ctx) async {
///     await $.pumpWidget(const App());
///   },
///   'I navigate to "{page}"'.mapper(): ($, ctx) async {
///     final page = ctx.arg<String>(0);
///     await $.tap(find.text(page));
///   },
///   'I have the following users:'.mapper(): ($, ctx) async {
///     for (final row in ctx.tableRows) {
///       await createUser(row['name']!, row['email']!);
///     }
///   },
/// });
/// ```
class StepRegistry<T> {
  final List<_StepEntry<T>> _entries = [];

  /// Creates an empty registry.
  StepRegistry();

  /// Creates a registry from a map of mappers to step functions.
  factory StepRegistry.fromMap(Map<LineMapper, StepFunction<T>> steps) {
    final registry = StepRegistry<T>();
    for (final entry in steps.entries) {
      registry.register(entry.key, entry.value);
    }
    return registry;
  }

  /// Registers a step pattern with its implementation.
  void register(LineMapper mapper, StepFunction<T> function) {
    _entries.add(_StepEntry(mapper: mapper, function: function));
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
  int get stepCount => _entries.length;

  /// Creates a new registry combining this one with another.
  ///
  /// Steps from this registry take precedence over steps from [other].
  StepRegistry<T> merge(StepRegistry<T> other) {
    final merged = StepRegistry<T>();
    for (final entry in _entries) {
      merged._entries.add(entry);
    }
    for (final entry in other._entries) {
      merged._entries.add(entry);
    }
    return merged;
  }

  /// Generates a placeholder step definition for a missing step.
  ///
  /// Analyzes the step text to detect likely parameters and generates
  /// ready-to-paste Dart code.
  static String suggestPlaceholder(String stepText) {
    var pattern = stepText;
    final argExtractors = <String>[];
    var argIndex = 0;

    // Detect quoted strings as parameters
    pattern = pattern.replaceAllMapped(RegExp(r'"([^"]*)"'), (match) {
      final paramName = argIndex == 0 ? 'page' : 'param${argIndex + 1}';
      argExtractors.add('  final $paramName = ctx.arg<String>($argIndex);');
      argIndex++;
      return '"{$paramName}"';
    });

    // Detect numbers as parameters
    final hasNumber = RegExp(r'\b\d+\b').hasMatch(pattern);
    String? typeHint;
    if (hasNumber) {
      pattern = pattern.replaceAllMapped(RegExp(r'\b(\d+)\b'), (match) {
        argExtractors.add('  final number = ctx.arg<int>($argIndex);');
        typeHint = "'number': int";
        argIndex++;
        return '{number}';
      });
    }

    final buffer = StringBuffer();
    buffer.writeln('// Missing step: $stepText');
    buffer.write("'$pattern'.mapper(");
    if (typeHint != null) {
      buffer.write('types: {$typeHint}');
    }
    buffer.writeln('): (\$, ctx) async {');
    for (final extractor in argExtractors) {
      buffer.writeln(extractor);
    }
    buffer.writeln('  // TODO: implement step');
    buffer.writeln('},');

    return buffer.toString();
  }
}

class _StepEntry<T> {
  final LineMapper mapper;
  final StepFunction<T> function;

  _StepEntry({required this.mapper, required this.function});
}

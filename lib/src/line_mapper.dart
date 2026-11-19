import 'package:cucumber_expressions/cucumber_expressions.dart' as ce;

/// A function that attempts to match a line and extract parameters.
///
/// Returns null if the line doesn't match, or a list of extracted parameters
/// (possibly empty) if it does match.
typedef LineMapper = List<dynamic>? Function(String line);

/// Metadata about a single matched parameter argument (offset, raw text, nested groups, and type name).
class MatchedArgumentInfo {
  final int? start;
  final String? value;
  final String? parameterTypeName;
  final List<MatchedArgumentInfo>? children;

  const MatchedArgumentInfo({this.start, this.value, this.parameterTypeName, this.children});
}

/// Metadata attached to a [LineMapper] created via [StringLineMapper.mapper],
/// [StringLineMapper.cucumber], or [RegExpLineMapper.mapper].
class LineMapperMetadata {
  final String pattern;
  final String expressionSource;
  final bool isRegularExpression;
  final List<MatchedArgumentInfo>? Function(String line) matchArguments;

  const LineMapperMetadata({
    required this.pattern,
    required this.expressionSource,
    this.isRegularExpression = false,
    required this.matchArguments,
  });
}

/// Internal [Expando] storing pattern metadata for [LineMapper] closures.
final Expando<LineMapperMetadata> lineMapperMetadata = Expando<LineMapperMetadata>('lineMapperMetadata');

class _GroupCursor {
  int pos;
  _GroupCursor(this.pos);
}

MatchedArgumentInfo _groupToMatchedArg(
  ce.Group group, {
  String? parameterTypeName,
  required String parentText,
  required _GroupCursor cursor,
}) {
  final value = group.value;
  int? start = group.start;
  if (value != null) {
    if (start == null) {
      final found = parentText.indexOf(value, cursor.pos);
      if (found != -1) {
        start = found;
        cursor.pos = found + value.length;
      }
    } else {
      cursor.pos = start + value.length;
    }
  }

  List<MatchedArgumentInfo>? children;
  if (group.children != null) {
    if (value != null && start != null) {
      final childCursor = _GroupCursor(start);
      children = group.children!
          .map((child) => _groupToMatchedArg(child, parentText: parentText, cursor: childCursor))
          .toList();
    } else {
      children = group.children!
          .map((child) => _groupToMatchedArg(child, parentText: parentText, cursor: _GroupCursor(cursor.pos)))
          .toList();
    }
  }

  return MatchedArgumentInfo(start: start, value: value, parameterTypeName: parameterTypeName, children: children);
}

/// Wraps a compiled [ce.Expression] into a [LineMapper] with full Cucumber Messages metadata.
LineMapper createExpressionLineMapper(ce.Expression expression, {bool isRegularExpression = false}) {
  List<dynamic>? fn(String line) {
    final args = expression.match(line);
    if (args == null) return null;
    return args.map((a) => a.getValue()).toList();
  }

  lineMapperMetadata[fn] = LineMapperMetadata(
    pattern: expression.source,
    expressionSource: expression.source,
    isRegularExpression: isRegularExpression,
    matchArguments: (String line) {
      final args = expression.match(line);
      if (args == null) return null;
      final matchStart = expression.regexp.firstMatch(line)?.start ?? 0;
      final cursor = _GroupCursor(matchStart);
      return args
          .map(
            (a) => _groupToMatchedArg(
              a.group,
              parameterTypeName: (a.parameterType.name != null && a.parameterType.name!.isNotEmpty)
                  ? a.parameterType.name
                  : null,
              parentText: line,
              cursor: cursor,
            ),
          )
          .toList();
    },
  );

  return fn;
}

/// Extension to create [LineMapper]s from [RegExp] regular expressions using
/// official `cucumber_expressions` `RegularExpression` matching.
///
/// Example:
/// ```dart
/// RegExp(r'^a (.*?)(?: and a (.*?))?$').mapper()
/// ```
extension RegExpLineMapper on RegExp {
  /// Creates a [LineMapper] backed by an official Cucumber [ce.RegularExpression].
  LineMapper mapper({ce.ParameterTypeRegistry? parameterTypes}) {
    final registry = parameterTypes ?? ce.ParameterTypeRegistry();
    final expression = ce.ExpressionFactory(registry).createExpression(this);
    return createExpressionLineMapper(expression, isRegularExpression: true);
  }
}

/// Extension to create LineMappers from String patterns.
///
/// Supports two modes:
/// 1. [cucumber] — official Cucumber Expression syntax (`{int}`, `{float}`,
///    `{string}`, `{word}`, `{}`, custom `ParameterType`s, optional `(s)`,
///    and alternatives `is/are`).
/// 2. [mapper] — gherkart named-placeholder syntax (`{paramName}` with optional
///    `types: {'paramName': int}`).
///
/// Example:
/// ```dart
/// final expr = 'I have {int} apple(s) in {string}'.cucumber();
/// expr('I have 1 apple in "basket"'); // returns [1, 'basket']
///
/// final legacy = 'I navigate to {page}'.mapper();
/// legacy('I navigate to Sessions');   // returns ['Sessions']
/// ```
extension StringLineMapper on String {
  /// Creates a [LineMapper] using official Cucumber Expression syntax.
  ///
  /// Built-in parameter types: `{int}`, `{float}`, `{word}`, `{string}`,
  /// `{double}`, `{bigdecimal}`, `{byte}`, `{short}`, `{long}`, `{biginteger}`,
  /// and anonymous `{}`. Also supports optional text `(s)` and alternatives
  /// `apple/orange`.
  ///
  /// Supply [parameterTypes] when referencing custom [ce.ParameterType]s.
  LineMapper cucumber({ce.ParameterTypeRegistry? parameterTypes}) {
    final registry = parameterTypes ?? ce.ParameterTypeRegistry();
    final expression = ce.ExpressionFactory(registry).createExpression(this);
    return createExpressionLineMapper(expression);
  }

  /// Creates a [LineMapper] from this string pattern.
  ///
  /// [types] optionally specifies type conversions for named parameters.
  /// Supported types: [int], [double], [bool], [String] (default).
  ///
  /// Example:
  /// ```dart
  /// 'I wait {seconds} seconds'.mapper(types: {'seconds': int})
  /// ```
  LineMapper mapper({Map<String, Type>? types}) {
    final pattern = this;
    final paramNames = <String>[];
    final literalLengths = <int>[];
    final tokenRegex = RegExp(r'\{(\w+)\}');

    var lastEnd = 0;
    for (final m in tokenRegex.allMatches(pattern)) {
      literalLengths.add(m.start - lastEnd);
      paramNames.add(m.group(1)!);
      lastEnd = m.end;
    }
    literalLengths.add(pattern.length - lastEnd);

    // Escape special regex characters, but not our {param} placeholders
    var regexPattern = pattern.replaceAllMapped(RegExp(r'[.*+?^${}()|[\]\\]'), (match) {
      final char = match.group(0)!;
      // Don't escape { and } - we'll handle them specially
      if (char == '{' || char == '}') return char;
      return '\\$char';
    });

    // Replace {paramName} with capturing groups
    regexPattern = regexPattern.replaceAllMapped(tokenRegex, (_) => '(.+?)');

    // Build Cucumber Expression source representation for Cucumber Messages
    final expressionSource = pattern.replaceAllMapped(tokenRegex, (m) {
      final name = m.group(1)!;
      final t = types?[name];
      if (t == int) return '{int}';
      if (t == double) return '{float}';
      return '{}';
    });

    // Anchor the pattern
    final regex = RegExp('^$regexPattern\$');

    List<dynamic>? fn(String line) {
      final match = regex.firstMatch(line);
      if (match == null) return null;

      final params = <dynamic>[];
      for (var i = 0; i < paramNames.length; i++) {
        final rawValue = match.group(i + 1)!;
        final paramName = paramNames[i];
        final targetType = types?[paramName] ?? String;

        final converted = _tryConvert(rawValue, targetType);
        if (converted == null && targetType != String) {
          return null;
        }
        params.add(converted);
      }
      return params;
    }

    lineMapperMetadata[fn] = LineMapperMetadata(
      pattern: pattern,
      expressionSource: expressionSource,
      matchArguments: (String line) {
        final match = regex.firstMatch(line);
        if (match == null) return null;

        final args = <MatchedArgumentInfo>[];
        var offset = literalLengths[0];
        for (var i = 0; i < paramNames.length; i++) {
          final rawValue = match.group(i + 1)!;
          final paramName = paramNames[i];
          final targetType = types?[paramName] ?? String;
          final converted = _tryConvert(rawValue, targetType);
          if (converted == null && targetType != String) {
            return null;
          }
          final typeName = switch (targetType) {
            const (int) => 'int',
            const (double) => 'float',
            const (String) => 'string',
            _ => null,
          };
          args.add(MatchedArgumentInfo(start: offset, value: rawValue, parameterTypeName: typeName));
          offset += rawValue.length + literalLengths[i + 1];
        }
        return args;
      },
    );

    return fn;
  }

  static dynamic _tryConvert(String value, Type type) {
    if (type == int) {
      return int.tryParse(value);
    } else if (type == double) {
      return double.tryParse(value);
    } else if (type == bool) {
      final lower = value.toLowerCase();
      if (lower == 'true') return true;
      if (lower == 'false') return false;
      return false;
    }
    return value;
  }
}

/// A function that attempts to match a line and extract parameters.
///
/// Returns null if the line doesn't match, or a list of extracted parameters
/// (possibly empty) if it does match.
typedef LineMapper = List<dynamic>? Function(String line);

/// Metadata about a single matched parameter argument (offset, raw text, and type name).
class MatchedArgumentInfo {
  final int start;
  final String value;
  final String? parameterTypeName;

  const MatchedArgumentInfo({required this.start, required this.value, this.parameterTypeName});
}

/// Metadata attached to a [LineMapper] created via [StringLineMapper.mapper].
class LineMapperMetadata {
  final String pattern;
  final String expressionSource;
  final List<MatchedArgumentInfo>? Function(String line) matchArguments;

  const LineMapperMetadata({required this.pattern, required this.expressionSource, required this.matchArguments});
}

/// Internal [Expando] storing pattern metadata for [LineMapper] closures.
final Expando<LineMapperMetadata> lineMapperMetadata = Expando<LineMapperMetadata>('lineMapperMetadata');

/// Extension to create LineMappers from String patterns.
///
/// Pattern syntax:
/// - Literal text matches exactly
/// - `{paramName}` captures a parameter (non-greedy, stops at next literal)
///
/// Example:
/// ```dart
/// final mapper = 'I navigate to {page}'.mapper();
/// mapper('I navigate to Sessions'); // returns ['Sessions']
/// mapper('something else');         // returns null
/// ```
extension StringLineMapper on String {
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

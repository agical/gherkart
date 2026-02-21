/// A function that attempts to match a line and extract parameters.
///
/// Returns null if the line doesn't match, or a list of extracted parameters
/// (possibly empty) if it does match.
typedef LineMapper = List<dynamic>? Function(String line);

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

    // Escape special regex characters, but not our {param} placeholders
    var regexPattern = pattern.replaceAllMapped(
      RegExp(r'[.*+?^${}()|[\]\\]'),
      (match) {
        final char = match.group(0)!;
        // Don't escape { and } - we'll handle them specially
        if (char == '{' || char == '}') return char;
        return '\\$char';
      },
    );

    // Replace {paramName} with capturing groups
    regexPattern = regexPattern.replaceAllMapped(
      RegExp(r'\{(\w+)\}'),
      (match) {
        paramNames.add(match.group(1)!);
        return '(.+?)'; // Non-greedy capture
      },
    );

    // Anchor the pattern
    final regex = RegExp('^$regexPattern\$');

    return (String line) {
      final match = regex.firstMatch(line);
      if (match == null) return null;

      final params = <dynamic>[];
      for (var i = 0; i < paramNames.length; i++) {
        final rawValue = match.group(i + 1)!;
        final paramName = paramNames[i];
        final targetType = types?[paramName] ?? String;

        params.add(_convert(rawValue, targetType));
      }
      return params;
    };
  }

  static dynamic _convert(String value, Type type) {
    if (type == int) {
      return int.parse(value);
    } else if (type == double) {
      return double.parse(value);
    } else if (type == bool) {
      return value.toLowerCase() == 'true';
    }
    return value;
  }
}

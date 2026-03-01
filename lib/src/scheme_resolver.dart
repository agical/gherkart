// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/// Scheme resolver for BDD parameter values.
///
/// Allows parameters to use schemes like:
/// - `{t:translation_key}` - resolve translation key to localized string
/// - `{t:key(param: value)}` - resolve key with parameters
/// - `{k:element_name}` - resolve to a ProjectKey for widget testing
/// - Plain text - used as literal value
///
/// The resolver parses the key and parameters, then delegates to the
/// registered [SchemeHandler] which receives both and decides how to
/// resolve the final value.
///
/// Example feature file:
/// ```gherkin
/// Then I see "{t:gameComplete}"           # Simple translation key
/// Then I see "{t:shotLabel(shots: 1)}"    # Parameterized translation
/// Then I see "{k:bank display}"           # ProjectKey mapping
/// Then I see "literal text"               # Literal text match
/// ```
library;

/// Handler function that resolves a scheme value.
///
/// Receives the key (e.g., "gameComplete" from "{t:gameComplete}") and a
/// map of parameters (e.g., {"shots": "1"} from "{t:shotLabel(shots: 1)}").
///
/// Each handler decides how to use the parameters — for example, an ARB
/// handler substitutes `{placeholder}` tokens, while a Phrase handler
/// might use `%{placeholder}` syntax.
typedef SchemeHandler = Future<dynamic> Function(
  String key,
  Map<String, String> params,
);

/// Resolved parameter with its scheme info.
class ResolvedParam {
  const ResolvedParam({
    required this.original,
    required this.scheme,
    required this.value,
    required this.resolved,
    this.params = const {},
  });

  /// Original parameter string (e.g., "{t:greeting}")
  final String original;

  /// Scheme name (e.g., "t", "k", or null for literals)
  final String? scheme;

  /// Value after scheme (e.g., "greeting")
  final String value;

  /// Resolved value after applying scheme handler
  final dynamic resolved;

  /// Parameters parsed from the scheme value (e.g., {"shots": "1"}).
  ///
  /// Populated when the scheme uses the parameterized syntax:
  /// `{t:key(param1: value1, param2: value2)}`
  final Map<String, String> params;

  /// True if this used a scheme (not a literal)
  bool get hasScheme => scheme != null;

  @override
  String toString() => hasScheme ? '$scheme:$value -> $resolved' : 'literal: $value';
}

/// Resolves parameter schemes to their actual values.
///
/// Register scheme handlers to process different parameter types:
/// ```dart
/// final resolver = SchemeResolver()
///   ..register('t', translationHandler)
///   ..register('k', keyMappingHandler);
///
/// final result = await resolver.resolve('{t:greeting}');
/// // Returns: ResolvedParam(scheme: 't', value: 'greeting', resolved: 'Hello!')
/// ```
class SchemeResolver {
  SchemeResolver();

  final Map<String, SchemeHandler> _handlers = {};

  /// Pattern to match scheme parameters: {scheme:value} or {scheme:key(params)}
  static final _schemePattern = RegExp(r'^\{(\w+):(.+)\}$');

  /// Pattern to extract key and parameters: key(p1: v1, p2: v2)
  static final _paramPattern = RegExp(r'^(\w+)\((.+)\)$');

  /// Register a handler for a scheme.
  ///
  /// Common schemes:
  /// - `t` - translation keys
  /// - `k` - ProjectKey element mappings
  void register(String scheme, SchemeHandler handler) {
    _handlers[scheme] = handler;
  }

  /// Check if a scheme is registered.
  bool hasScheme(String scheme) => _handlers.containsKey(scheme);

  /// Resolve a parameter value, applying any scheme handlers.
  ///
  /// Returns [ResolvedParam] with original, scheme, value, and resolved fields.
  Future<ResolvedParam> resolve(String param) async {
    final match = _schemePattern.firstMatch(param);

    if (match == null) {
      // No scheme - return as literal
      return ResolvedParam(
        original: param,
        scheme: null,
        value: param,
        resolved: param,
      );
    }

    final scheme = match.group(1)!;
    final rawValue = match.group(2)!;

    final handler = _handlers[scheme];
    if (handler == null) {
      throw ArgumentError(
        'Unknown scheme "$scheme" in parameter "$param". '
        'Registered schemes: ${_handlers.keys.join(", ")}',
      );
    }

    // Parse optional parameters from value: key(p1: v1, p2: v2)
    final paramMatch = _paramPattern.firstMatch(rawValue);
    final String key;
    final Map<String, String> params;

    if (paramMatch != null) {
      key = paramMatch.group(1)!;
      params = _parseParams(paramMatch.group(2)!);
    } else {
      key = rawValue;
      params = const {};
    }

    var resolved = await handler(key, params);

    return ResolvedParam(
      original: param,
      scheme: scheme,
      value: key,
      resolved: resolved,
      params: params,
    );
  }

  /// Resolve all parameters in a list.
  Future<List<ResolvedParam>> resolveAll(List<dynamic> params) async {
    final results = <ResolvedParam>[];
    for (final param in params) {
      if (param is String) {
        results.add(await resolve(param));
      } else {
        results.add(ResolvedParam(
          original: param.toString(),
          scheme: null,
          value: param.toString(),
          resolved: param,
        ));
      }
    }
    return results;
  }

  /// Parses a comma-separated parameter string into a map.
  ///
  /// String values should be wrapped in single quotes:
  ///   "name: 'Alice', count: 3" -> {"name": "Alice", "count": "3"}
  ///
  /// Single quotes are stripped from the parsed value; unquoted values
  /// are kept as-is (useful for numbers).
  static Map<String, String> _parseParams(String raw) {
    final params = <String, String>{};
    for (final part in raw.split(',')) {
      final colonIndex = part.indexOf(':');
      if (colonIndex == -1) continue;
      final key = part.substring(0, colonIndex).trim();
      var value = part.substring(colonIndex + 1).trim();
      // Strip surrounding single quotes
      if (value.length >= 2 && value.startsWith("'") && value.endsWith("'")) {
        value = value.substring(1, value.length - 1);
      }
      if (key.isNotEmpty) {
        params[key] = value;
      }
    }
    return params;
  }
}

/// Creates a translation scheme handler.
///
/// Usage:
/// ```dart
/// resolver.register('t', createTranslationHandler(context));
/// ```
SchemeHandler createTranslationHandler(
  String Function(String key) translator,
) {
  return (String key, Map<String, String> params) async => translator(key);
}

/// Creates a key mapping scheme handler.
///
/// Usage:
/// ```dart
/// resolver.register('k', createKeyMappingHandler(keyMapper));
/// ```
SchemeHandler createKeyMappingHandler(
  dynamic Function(String name) mapper,
) {
  return (String name, Map<String, String> params) async => mapper(name);
}

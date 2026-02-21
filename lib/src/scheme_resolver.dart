// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/// Scheme resolver for BDD parameter values.
///
/// Allows parameters to use schemes like:
/// - `{t:translation_key}` - resolve translation key to localized string
/// - `{k:element_name}` - resolve to a ProjectKey for widget testing
/// - Plain text - used as literal value
///
/// Example feature file:
/// ```gherkin
/// Then I see "{t:gameComplete}"     # Uses translation key
/// Then I see "{k:bank display}"     # Uses ProjectKey mapping
/// Then I see "literal text"         # Literal text match
/// ```
library;

/// Handler function that resolves a scheme value.
///
/// Takes the value after the colon (e.g., "gameComplete" from "{t:gameComplete}")
/// and returns the resolved value.
typedef SchemeHandler = Future<dynamic> Function(String value);

/// Resolved parameter with its scheme info.
class ResolvedParam {
  const ResolvedParam({
    required this.original,
    required this.scheme,
    required this.value,
    required this.resolved,
  });

  /// Original parameter string (e.g., "{t:greeting}")
  final String original;

  /// Scheme name (e.g., "t", "k", or null for literals)
  final String? scheme;

  /// Value after scheme (e.g., "greeting")
  final String value;

  /// Resolved value after applying scheme handler
  final dynamic resolved;

  /// True if this used a scheme (not a literal)
  bool get hasScheme => scheme != null;

  @override
  String toString() =>
      hasScheme ? '$scheme:$value -> $resolved' : 'literal: $value';
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

  /// Pattern to match scheme parameters: {scheme:value}
  static final _schemePattern = RegExp(r'^\{(\w+):(.+)\}$');

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
    final value = match.group(2)!;

    final handler = _handlers[scheme];
    if (handler == null) {
      throw ArgumentError(
        'Unknown scheme "$scheme" in parameter "$param". '
        'Registered schemes: ${_handlers.keys.join(", ")}',
      );
    }

    final resolved = await handler(value);
    return ResolvedParam(
      original: param,
      scheme: scheme,
      value: value,
      resolved: resolved,
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
  return (String key) async => translator(key);
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
  return (String name) async => mapper(name);
}

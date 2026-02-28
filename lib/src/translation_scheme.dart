// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/// Translation scheme handler for BDD tests.
///
/// Provides a way to look up translation keys in feature files,
/// enabling the same tests to run across all locales.
///
/// Usage in feature files:
/// ```gherkin
/// Then I see "{t:sessionTitle}"       # Simple key lookup
/// Then I see "{t:shotLabel(shots: 1)}" # Parameterized lookup
/// ```
///
/// When parameters are provided, the handler substitutes `{paramName}`
/// placeholders in the resolved string with the supplied values.
/// Custom handlers may use different placeholder syntax as needed.
///
/// ICU MessageFormat plural syntax is also supported:
/// ```gherkin
/// Then "{t:shotLabel(count: 1)}" is "1 shot"
/// ```
/// with a translation value like:
/// ```
/// {count, plural, =0{no shots} =1{1 shot} other{{count} shots}}
/// ```
///
/// Usage in test setup:
/// ```dart
/// final resolver = SchemeResolver()
///   ..register('t', createArbTranslationHandler('lib/l10n/en.arb'));
/// ```
library;

import 'dart:convert';

import 'feature_source.dart';
import 'scheme_resolver.dart';

/// Creates a translation handler that reads from an ARB file.
///
/// This is useful for BDD tests that want to verify translated text
/// without hardcoding specific language strings.
///
/// Example ARB content:
/// ```json
/// {
///   "@@locale": "en",
///   "sessionTitle": "Sessions",
///   "homeWelcome": "Welcome to Beer Pong"
/// }
/// ```
///
/// Then in feature file:
/// ```gherkin
/// Then I see "{t:sessionTitle}"
/// Then I see "{t:greeting(name: Alice)}"  # with parameter substitution
/// ```
///
/// Uses [FeatureSource] to read the ARB file, allowing it to work
/// with both file system and asset-based sources.
SchemeHandler createArbTranslationHandler(
  String arbFilePath, {
  FeatureSource? source,
}) {
  // Lazily load and cache the ARB file content
  Map<String, dynamic>? cachedArb;

  return (String key, Map<String, String> params) async {
    if (cachedArb == null) {
      // Use provided source or default to file system
      final effectiveSource = source;
      if (effectiveSource == null) {
        // Defer to sync file loading for backward compatibility
        throw ArgumentError(
          'ARB translation handler requires a FeatureSource when used with async loading. '
          'Use createArbTranslationHandlerSync for synchronous file access, '
          'or provide a source parameter.',
        );
      }

      final content = await effectiveSource.read(arbFilePath);
      cachedArb = json.decode(content) as Map<String, dynamic>;
    }

    final value = cachedArb![key];
    if (value == null) {
      throw ArgumentError(
        'Translation key "$key" not found in $arbFilePath. '
        'Available keys: ${cachedArb!.keys.where((k) => !k.startsWith("@")).take(10).join(", ")}...',
      );
    }
    if (value is! String) {
      throw ArgumentError(
        'Translation key "$key" is not a string value in $arbFilePath.',
      );
    }
    return _substitutePlaceholders(value, params);
  };
}

/// Creates a translation handler from an in-memory map.
///
/// Useful for tests that don't want to read from disk.
SchemeHandler createMapTranslationHandler(Map<String, String> translations) {
  return (String key, Map<String, String> params) async {
    final value = translations[key];
    if (value == null) {
      throw ArgumentError(
        'Translation key "$key" not found. '
        'Available keys: ${translations.keys.take(10).join(", ")}...',
      );
    }
    return _substitutePlaceholders(value, params);
  };
}

/// Creates a translation handler from a simple lookup function.
///
/// Wraps a sync lookup function into an async [SchemeHandler].
///
/// Example:
/// ```dart
/// final handler = createTranslationHandler((key) => myTranslations[key]!);
/// resolver.register('t', handler);
/// ```
SchemeHandler createTranslationHandler(String Function(String key) lookup) {
  return (String key, Map<String, String> params) async => lookup(key);
}

/// Creates a key mapping handler for widget keys or identifiers.
///
/// Wraps a lookup function that maps element names to their keys.
///
/// Example:
/// ```dart
/// final handler = createKeyMappingHandler((name) => MyKeys.map[name]);
/// resolver.register('k', handler);
/// ```
SchemeHandler createKeyMappingHandler(dynamic Function(String name) lookup) {
  return (String name, Map<String, String> params) async => lookup(name);
}

/// Substitutes `{paramName}` placeholders in [template] with values from [params].
///
/// Supports ICU MessageFormat plural syntax used in ARB files:
/// ```
/// {count, plural, =0{no items} =1{1 item} other{{count} items}}
/// ```
///
/// Within plural branches, `#` is replaced with the numeric value.
///
/// This is the default substitution strategy used by the built-in ARB and map
/// translation handlers. Custom handlers may use a different strategy
/// (e.g., `%{name}` for Phrase, `{{name}}` for i18next).
String _substitutePlaceholders(String template, Map<String, String> params) {
  if (params.isEmpty) return template;
  var result = _resolveIcuPlurals(template, params);
  for (final entry in params.entries) {
    result = result.replaceAll('{${entry.key}}', entry.value);
  }
  return result;
}

/// Pattern matching `{paramName, plural, ...}` ICU MessageFormat blocks.
final _icuPluralPattern = RegExp(r'\{(\w+),\s*plural\s*,');

/// Resolves all ICU plural blocks in [template] using values from [params].
///
/// For each `{paramName, plural, =0{...} =1{...} other{...}}` block, selects
/// the matching form based on the numeric value of the parameter.
String _resolveIcuPlurals(String template, Map<String, String> params) {
  var result = template;

  // Process plural blocks from right to left to preserve offsets
  final matches = _icuPluralPattern.allMatches(result).toList().reversed;
  for (final match in matches) {
    final paramName = match.group(1)!;
    final paramValue = params[paramName];
    if (paramValue == null) continue;

    // Find the matching closing brace for the entire plural block
    final blockStart = match.start;
    final blockEnd = _findMatchingBrace(result, blockStart);
    if (blockEnd == -1) continue;

    final block = result.substring(blockStart, blockEnd + 1);
    final rulesStr = block.substring(match.group(0)!.length, block.length - 1);

    final rules = _parsePluralRules(rulesStr.trim());
    final numValue = int.tryParse(paramValue);

    // Select: exact match (=N) first, then 'other' fallback
    String? selected;
    if (numValue != null) {
      selected = rules['=$numValue'];
    }
    selected ??= rules['other'] ?? '';

    // Replace # with the numeric value within the selected form
    selected = selected.replaceAll('#', paramValue);

    result = result.substring(0, blockStart) + selected + result.substring(blockEnd + 1);
  }
  return result;
}

/// Finds the index of the closing `}` that matches the opening `{` at [openIndex].
int _findMatchingBrace(String text, int openIndex) {
  var depth = 0;
  for (var i = openIndex; i < text.length; i++) {
    if (text[i] == '{') {
      depth++;
    } else if (text[i] == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

/// Parses plural rules from the content inside `{param, plural, ...}`.
///
/// Handles rule keywords like `=0`, `=1`, `one`, `few`, `many`, `other`
/// followed by `{text}` blocks (which may contain nested braces).
Map<String, String> _parsePluralRules(String rulesStr) {
  final rules = <String, String>{};
  var i = 0;

  while (i < rulesStr.length) {
    // Skip whitespace
    while (i < rulesStr.length && rulesStr[i] == ' ') {
      i++;
    }
    if (i >= rulesStr.length) break;

    // Read the keyword (e.g., '=0', '=1', 'one', 'other')
    final keyStart = i;
    while (i < rulesStr.length && rulesStr[i] != '{') {
      i++;
    }
    if (i >= rulesStr.length) break;
    final keyword = rulesStr.substring(keyStart, i).trim();

    // Read the brace-delimited value
    final valueStart = i + 1;
    var depth = 1;
    i++;
    while (i < rulesStr.length && depth > 0) {
      if (rulesStr[i] == '{') depth++;
      if (rulesStr[i] == '}') depth--;
      i++;
    }
    final value = rulesStr.substring(valueStart, i - 1);
    rules[keyword] = value;
  }

  return rules;
}

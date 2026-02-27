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
/// When parameters are provided, `{paramName}` placeholders in the
/// resolved string are substituted with the supplied values.
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

  return (String key) async {
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
    return value;
  };
}

/// Creates a translation handler from an in-memory map.
///
/// Useful for tests that don't want to read from disk.
SchemeHandler createMapTranslationHandler(Map<String, String> translations) {
  return (String key) async {
    final value = translations[key];
    if (value == null) {
      throw ArgumentError(
        'Translation key "$key" not found. '
        'Available keys: ${translations.keys.take(10).join(", ")}...',
      );
    }
    return value;
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
  return (String key) async => lookup(key);
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
  return (String name) async => lookup(name);
}

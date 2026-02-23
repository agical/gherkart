// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import 'dart:async';

/// Abstraction for reading feature files from different sources.
///
/// Implementations:
/// - [FileSystemSource] - reads from file system (requires dart:io)
/// - [AssetSource] - reads from in-memory map or loader function
///
/// Example using file system:
/// ```dart
/// final source = FileSystemSource();
/// final content = await source.read('test/features/login.feature');
/// ```
///
/// Example using assets (for web or bundled tests):
/// ```dart
/// final source = AssetSource.fromMap({
///   'features/login.feature': 'Feature: Login...',
/// });
/// ```
abstract class FeatureSource {
  /// Read the content of a single feature file.
  ///
  /// Throws if the path doesn't exist or can't be read.
  Future<String> read(String path);

  /// List all .feature files under a path.
  ///
  /// If [path] is a single .feature file, returns just that file.
  /// If [path] is a directory, recursively finds all .feature files.
  Future<List<String>> list(String path);

  /// Check if a path exists and is readable.
  Future<bool> exists(String path);
}

/// Reads features from the file system using dart:io.
///
/// This is the default source for Flutter tests running on desktop/mobile.
///
/// Note: This class is in a separate file (feature_source_io.dart) because
/// it requires dart:io which isn't available on web.
// Implemented in feature_source_io.dart

/// Reads features from an in-memory map or loader function.
///
/// Useful for:
/// - Web platform tests (no dart:io access)
/// - Bundled test assets
/// - Unit tests without file system
///
/// Example with map:
/// ```dart
/// final source = AssetSource.fromMap({
///   'login.feature': '''
///     Feature: Login
///       Scenario: Valid credentials
///         Given I am on the login page
///         When I enter valid credentials
///         Then I should see the dashboard
///   ''',
/// });
/// ```
///
/// Example with loader:
/// ```dart
/// final source = AssetSource.fromLoader((path) async {
///   return await rootBundle.loadString('assets/$path');
/// });
/// ```
class AssetSource implements FeatureSource {
  final Map<String, String>? _features;
  final Future<String> Function(String path)? _loader;
  final Future<List<String>> Function(String path)? _lister;

  /// Creates an asset source from a map of path -> content.
  ///
  /// Paths should be relative and consistent with how you reference them.
  AssetSource.fromMap(Map<String, String> features)
      : _features = features,
        _loader = null,
        _lister = null;

  /// Creates an asset source with a custom loader function.
  ///
  /// The loader should throw if the path doesn't exist.
  /// Optionally provide a lister for directory enumeration.
  AssetSource.fromLoader(
    Future<String> Function(String path) loader, {
    Future<List<String>> Function(String path)? lister,
  })  : _features = null,
        _loader = loader,
        _lister = lister;

  @override
  Future<String> read(String path) async {
    if (_features != null) {
      final content = _features[path];
      if (content == null) {
        throw FeatureSourceException(
          'Feature not found: $path\n'
          'Available: ${_features.keys.join(", ")}',
        );
      }
      return content;
    }

    if (_loader != null) {
      return _loader(path);
    }

    throw StateError('AssetSource not properly initialized');
  }

  @override
  Future<List<String>> list(String path) async {
    if (_features != null) {
      // For map source, filter keys that match the path prefix
      if (path.endsWith('.feature')) {
        // Single file - check if it exists
        if (_features.containsKey(path)) {
          return [path];
        }
        return [];
      }

      // Directory - find all matching features
      final prefix = path.endsWith('/') ? path : '$path/';
      return _features.keys
          .where((key) => key.startsWith(prefix) || key == path || (path.isEmpty && key.endsWith('.feature')))
          .where((key) => key.endsWith('.feature'))
          .toList()
        ..sort();
    }

    if (_lister != null) {
      return _lister(path);
    }

    // No lister provided - can only handle single files
    if (path.endsWith('.feature')) {
      return [path];
    }

    throw FeatureSourceException(
      'Cannot list directory "$path" - no lister function provided. '
      'Use AssetSource.fromLoader with a lister parameter, or provide explicit paths.',
    );
  }

  @override
  Future<bool> exists(String path) async {
    if (_features != null) {
      return _features.containsKey(path);
    }

    if (_loader != null) {
      try {
        await _loader(path);
        return true;
      } catch (_) {
        return false;
      }
    }

    return false;
  }
}

/// Exception thrown when a feature source operation fails.
class FeatureSourceException implements Exception {
  final String message;

  FeatureSourceException(this.message);

  @override
  String toString() => 'FeatureSourceException: $message';
}

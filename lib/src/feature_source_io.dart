// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'feature_source.dart';

/// Reads features from the file system using dart:io.
///
/// This is the default source for Flutter tests running on desktop/mobile.
///
/// Example:
/// ```dart
/// final source = FileSystemSource();
/// final features = await source.list('test/features/');
/// for (final path in features) {
///   final content = await source.read(path);
///   print('Loaded: $path');
/// }
/// ```
class FileSystemSource implements FeatureSource {
  /// Creates a file system source.
  const FileSystemSource();

  @override
  Future<String> read(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FeatureSourceException('Feature file not found: $path');
    }
    return file.readAsString();
  }

  @override
  Future<List<String>> list(String path) async {
    // Handle single file path
    final file = File(path);
    if (path.endsWith('.feature') && await file.exists()) {
      return [path];
    }

    // Handle directory
    final dir = Directory(path);
    if (!await dir.exists()) {
      return [];
    }

    final features = <String>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.feature')) {
        features.add(entity.path);
      }
    }

    features.sort();
    return features;
  }

  @override
  Future<bool> exists(String path) async {
    final file = File(path);
    if (await file.exists()) return true;

    final dir = Directory(path);
    return dir.exists();
  }
}

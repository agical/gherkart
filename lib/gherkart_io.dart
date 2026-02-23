/// Gherkart I/O support - File system operations for desktop/mobile.
///
/// This library provides [FileSystemSource] for reading feature files
/// from the file system. It requires dart:io and is not available on web.
///
/// ```dart
/// import 'package:gherkart/gherkart.dart';
/// import 'package:gherkart/gherkart_io.dart';
///
/// void main() {
///   runBddTests<PatrolTester>(
///     rootPaths: ['test/features'],
///     registry: registry,
///     adapter: adapter,
///     source: FileSystemSource(),  // From gherkart_io
///   );
/// }
/// ```
library;

export 'src/feature_source_io.dart' show FileSystemSource;

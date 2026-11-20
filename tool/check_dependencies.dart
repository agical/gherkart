import 'dart:convert';
import 'dart:io';

/// Verifies that all direct `dependencies` in `pubspec.yaml` support the latest
/// stable versions on pub.dev (matching pub.dev Pana's "Support up-to-date
/// dependencies" score check) and that `dev_dependencies` are not constrained
/// below newer resolvable major versions.
Future<void> main() async {
  final issues = <String>[];
  final packagesToUpgrade = <String>[];

  // 1. Reproduce pub.dev's exact Pana check for direct runtime dependencies:
  //    `dart pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`
  final directPackages = await _runPubOutdated(includeDevDependencies: false);
  for (final pkg in directPackages) {
    if (pkg['kind'] != 'direct') continue;

    final name = pkg['package'] as String;
    final upgradable = _versionOf(pkg['upgradable']);
    final latest = _versionOf(pkg['latest']);

    _checkHealthFlags(pkg, name, issues);

    if (upgradable != null && latest != null && upgradable != latest) {
      issues.add(
        '  - $name (dependencies): constraint allows up to $upgradable, '
        'but latest stable on pub.dev is $latest.',
      );
      packagesToUpgrade.add(name);
    }
  }

  // 2. Check dev_dependencies against the highest version resolvable with the
  //    current SDK (avoids false positives when flutter_test pins transitive packages).
  final allPackages = await _runPubOutdated(includeDevDependencies: true);
  for (final pkg in allPackages) {
    if (pkg['kind'] != 'dev') continue;

    final name = pkg['package'] as String;
    final upgradable = _versionOf(pkg['upgradable']);
    final resolvable = _versionOf(pkg['resolvable']);

    _checkHealthFlags(pkg, name, issues);

    if (upgradable != null && resolvable != null && upgradable != resolvable) {
      issues.add(
        '  - $name (dev_dependencies): constraint allows up to $upgradable, '
        'but $resolvable is resolvable.',
      );
      packagesToUpgrade.add(name);
    }
  }

  if (issues.isNotEmpty) {
    stderr.writeln('Outdated or unhealthy dependency constraints detected:');
    for (final issue in issues) {
      stderr.writeln(issue);
    }
    if (packagesToUpgrade.isNotEmpty) {
      stderr.writeln('');
      stderr.writeln('Update pubspec.yaml constraints with:');
      stderr.writeln('  dart pub upgrade --major-versions ${packagesToUpgrade.join(' ')}');
    }
    exit(1);
  }

  stdout.writeln('All dependency constraints support the latest versions.');
}

Future<List<Map<String, dynamic>>> _runPubOutdated({required bool includeDevDependencies}) async {
  final args = <String>[
    'pub',
    'outdated',
    '--json',
    '--no-dependency-overrides',
    if (!includeDevDependencies) '--no-dev-dependencies',
  ];

  final result = await Process.run(Platform.resolvedExecutable, args);
  if (result.exitCode != 0) {
    stderr.writeln('Failed to run `dart ${args.join(' ')}`:');
    stderr.write(result.stderr);
    exit(result.exitCode);
  }

  final decoded = jsonDecode(result.stdout as String) as Map<String, dynamic>;
  final packages = decoded['packages'] as List<dynamic>? ?? const [];
  return packages.cast<Map<String, dynamic>>();
}

String? _versionOf(Object? entry) {
  if (entry is Map<String, dynamic>) {
    return entry['version'] as String?;
  }
  return null;
}

void _checkHealthFlags(Map<String, dynamic> pkg, String name, List<String> issues) {
  if (pkg['isDiscontinued'] == true) {
    issues.add('  - $name: package is marked as discontinued on pub.dev.');
  }
  if (pkg['isCurrentRetracted'] == true) {
    issues.add('  - $name: current version is retracted on pub.dev.');
  }
  if (pkg['isCurrentAffectedByAdvisory'] == true) {
    issues.add('  - $name: current version is affected by a security advisory.');
  }
}

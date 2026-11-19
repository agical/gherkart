import 'dart:io';

void main() {
  final lcovFile = File('coverage/lcov.info');
  if (!lcovFile.existsSync()) {
    stderr.writeln('Error: coverage/lcov.info does not exist.');
    exit(1);
  }

  final lines = lcovFile.readAsLinesSync();
  final files = <_FileCoverage>[];
  String? currentFile;
  var linesFound = 0;
  var linesHit = 0;

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      currentFile = line.substring(3).trim();
      linesFound = 0;
      linesHit = 0;
    } else if (line.startsWith('LF:')) {
      linesFound = int.tryParse(line.substring(3).trim()) ?? 0;
    } else if (line.startsWith('LH:')) {
      linesHit = int.tryParse(line.substring(3).trim()) ?? 0;
    } else if (line == 'end_of_record') {
      if (currentFile != null) {
        files.add(_FileCoverage(filePath: currentFile, linesFound: linesFound, linesHit: linesHit));
      }
      currentFile = null;
    }
  }

  if (files.isEmpty) {
    stdout.writeln('No coverage records found in coverage/lcov.info');
    return;
  }

  files.sort((a, b) => a.relativePath.compareTo(b.relativePath));

  final totalFound = files.fold(0, (sum, f) => sum + f.linesFound);
  final totalHit = files.fold(0, (sum, f) => sum + f.linesHit);
  final totalPct = totalFound > 0 ? (totalHit / totalFound) * 100 : 0.0;

  const colWidth = 52;
  stdout.writeln('');
  stdout.writeln('=' * 75);
  stdout.writeln('${'File'.padRight(colWidth)} ${'Lines Hit / Total'.padLeft(14)}   ${'Rate'.padLeft(5)}');
  stdout.writeln('-' * 75);

  for (final file in files) {
    final pct = file.percent.toStringAsFixed(1);
    final count = '${file.linesHit} / ${file.linesFound}'.padLeft(14);
    stdout.writeln('${file.relativePath.padRight(colWidth)} $count  ${pct.padLeft(5)}%');
  }

  stdout.writeln('=' * 75);
  final summaryCount = '$totalHit / $totalFound'.padLeft(14);
  final summaryPct = totalPct.toStringAsFixed(1).padLeft(5);
  stdout.writeln('${'Total Coverage'.padRight(colWidth)} $summaryCount  $summaryPct%');
  stdout.writeln('=' * 75);
  stdout.writeln('Coverage report written to coverage/lcov.info\n');
}

class _FileCoverage {
  final String filePath;
  final int linesFound;
  final int linesHit;

  _FileCoverage({required this.filePath, required this.linesFound, required this.linesHit});

  String get relativePath {
    final cwd = Directory.current.path;
    if (filePath.startsWith(cwd)) {
      var rel = filePath.substring(cwd.length);
      if (rel.startsWith('/')) rel = rel.substring(1);
      return rel;
    }
    return filePath;
  }

  double get percent => linesFound > 0 ? (linesHit / linesFound) * 100 : 0.0;
}

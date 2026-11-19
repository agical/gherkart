// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:cucumber_messages/cucumber_messages.dart' as cm;
import 'package:gherkart/gherkart.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Future<List<cm.Envelope>> _readNdjsonFile(File file) async {
  if (!file.existsSync()) return const [];
  final raw = file.readAsStringSync();
  final lines = Stream<String>.fromIterable(const LineSplitter().convert(raw));
  return cm.decodeNdjsonEnvelopes(lines).toList();
}

void main() {
  final goodDir = Directory('test/compliance/gherkin_testdata/good');
  final badDir = Directory('test/compliance/gherkin_testdata/bad');

  final goodFeatures = goodDir.listSync().whereType<File>().where((f) => f.path.endsWith('.feature')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final badFeatures = badDir.listSync().whereType<File>().where((f) => f.path.endsWith('.feature')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  group('Official Cucumber Gherkin Compliance — testdata/good (${goodFeatures.length} files)', () {
    for (final featureFile in goodFeatures) {
      final fileName = p.basename(featureFile.path);

      test('complies with AST & Pickles for $fileName', () async {
        // Read raw bytes decoded as UTF-8 to preserve CRLF in *.crlf.feature files.
        final content = utf8.decode(featureFile.readAsBytesSync());

        // 1. Pre-sanitizer must emit zero warnings and preserve standard Gherkin verbatim.
        final warnings = <String>[];
        final sanitized = sanitizeGherkin(content, featureFile.path, onWarning: warnings.add);
        expect(warnings, isEmpty, reason: 'Standard Gherkin file $fileName triggered deprecation warnings');
        expect(sanitized, equals(content), reason: 'Standard Gherkin file $fileName was modified by sanitizeGherkin');

        // 2. Parse feature and compare against official golden .ast.ndjson & .pickles.ndjson
        final astEnvelopes = await _readNdjsonFile(File('${featureFile.path}.ast.ndjson'));
        final pickleEnvelopes = await _readNdjsonFile(File('${featureFile.path}.pickles.ndjson'));

        final expectedDoc = astEnvelopes.firstWhere((e) => e.gherkinDocument != null).gherkinDocument!;
        final expectedPickles = pickleEnvelopes.where((e) => e.pickle != null).map((e) => e.pickle!).toList();

        var nextId = 0;
        final feature = parseFeature(
          content,
          featureFile.path,
          onWarning: warnings.add,
          idGenerator: () => '${nextId++}',
        );
        expect(warnings, isEmpty);

        if (expectedDoc.feature == null) {
          expect(feature.name, 'Unnamed Feature');
          expect(feature.allScenarios, isEmpty);
        } else {
          final expectedFeature = expectedDoc.feature!;
          expect(feature.name, expectedFeature.name.isEmpty ? 'Unnamed Feature' : expectedFeature.name);
          expect(feature.tags, expectedFeature.tags.map((t) => t.name.substring(1)).toList());
        }

        final actualScenarios = feature.allScenarios;
        expect(
          actualScenarios,
          hasLength(expectedPickles.length),
          reason: 'Scenario/Pickle count mismatch in $fileName',
        );

        for (var i = 0; i < expectedPickles.length; i++) {
          final actual = actualScenarios[i];
          final expected = expectedPickles[i];

          expect(actual.pickle, isNotNull, reason: 'Scenario #$i in $fileName missing linked Pickle');
          expect(actual.pickle!.name, expected.name);

          // Outline scenarios append ' (<ExampleName> #N)' to disambiguate Dart test names
          final isOutlinePickle = expected.astNodeIds.length > 1;
          if (isOutlinePickle) {
            expect(actual.name, startsWith('${expected.name} ('));
          } else {
            expect(actual.name, expected.name);
          }

          // Effective tags (Feature + Rule + Scenario + Examples)
          final actualTagSet = <String>{...feature.tags, ...actual.tags};
          final expectedTagSet = expected.tags.map((t) => t.name.substring(1)).toSet();
          expect(actualTagSet, expectedTagSet, reason: 'Tag mismatch on pickle #$i in $fileName');

          // Effective executable steps (Background + Rule Background + Scenario)
          final effectiveSteps = actual.steps.isEmpty
              ? const <Step>[]
              : <Step>[...?feature.background?.steps, ...actual.steps];

          expect(
            effectiveSteps,
            hasLength(expected.steps.length),
            reason: 'Step count mismatch on pickle "${expected.name}" (#$i) in $fileName',
          );

          for (var j = 0; j < expected.steps.length; j++) {
            final actualStep = effectiveSteps[j];
            final expectedStep = expected.steps[j];

            expect(actualStep.text, expectedStep.text, reason: 'Step #$j text mismatch in $fileName');

            final expectedTable = expectedStep.argument?.dataTable;
            if (expectedTable != null) {
              expect(actualStep.dataTable, isNotNull, reason: 'Missing DataTable on step #$j in $fileName');
              final expectedRows = expectedTable.rows.map((r) => r.cells.map((c) => c.value).toList()).toList();
              expect(actualStep.dataTable!.allRows, expectedRows);
            } else {
              expect(actualStep.dataTable, isNull);
            }

            final expectedDocString = expectedStep.argument?.docString;
            if (expectedDocString != null) {
              expect(actualStep.docString, isNotNull, reason: 'Missing DocString on step #$j in $fileName');
              expect(actualStep.docString!.content, expectedDocString.content);
              final expectedMediaType = (expectedDocString.mediaType != null && expectedDocString.mediaType!.isNotEmpty)
                  ? expectedDocString.mediaType
                  : null;
              expect(actualStep.docString!.mediaType, expectedMediaType);
            } else {
              expect(actualStep.docString, isNull);
            }
          }
        }
      });
    }
  });

  group('Official Cucumber Gherkin Compliance — testdata/bad (${badFeatures.length} files)', () {
    for (final badFile in badFeatures) {
      final fileName = p.basename(badFile.path);

      test('rejects invalid Gherkin in $fileName with matching error locations', () async {
        final content = utf8.decode(badFile.readAsBytesSync());
        final errorEnvelopes = await _readNdjsonFile(File('${badFile.path}.errors.ndjson'));
        final expectedErrors = errorEnvelopes.where((e) => e.parseError != null).map((e) => e.parseError!).toList();

        expect(expectedErrors, isNotEmpty);

        GherkinParseException? caught;
        try {
          parseFeature(content, badFile.path, onWarning: (_) {});
        } on GherkinParseException catch (e) {
          caught = e;
        }

        expect(caught, isNotNull, reason: 'Expected GherkinParseException for $fileName');
        expect(caught!.filePath, badFile.path);
        expect(caught.parseErrors, hasLength(expectedErrors.length));
        expect(caught.line, expectedErrors.first.source.location?.line);
        expect(caught.column, expectedErrors.first.source.location?.column);
      });
    }
  });
}

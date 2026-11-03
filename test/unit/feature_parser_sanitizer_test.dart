// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import 'package:gherkart/gherkart.dart';
import 'package:test/test.dart';

void main() {
  group('Parse errors and locations', () {
    test('throws GherkinParseException with line and column on invalid Gherkin', () {
      const content = '''
Scenario: Missing feature header
  Given step
''';
      expect(
        () => parseFeature(content, 'broken.feature', onWarning: (_) {}),
        throwsA(
          isA<GherkinParseException>()
              .having((e) => e.filePath, 'filePath', 'broken.feature')
              .having((e) => e.line, 'line', 1)
              .having((e) => e.column, 'column', 1),
        ),
      );
    });
  });

  group('Pre-sanitizer deprecations and migration suggestions', () {
    test('warns on import statements with sed command', () {
      const content = '''
import 'package:patrol_finders/patrol_finders.dart';

Feature: Test
  Scenario: S
    Given step
''';
      final warnings = <String>[];
      final sanitized = sanitizeGherkin(content, 'features/login.feature', onWarning: warnings.add);

      expect(warnings, hasLength(1));
      expect(warnings[0], contains('[gherkart] Deprecation: Found unused Dart import'));
      expect(warnings[0], contains('features/login.feature:1'));
      expect(warnings[0], contains("sed -i '' '/^import /d' features/login.feature"));
      expect(sanitized, contains("# import 'package:patrol_finders/patrol_finders.dart';"));
    });

    test('warns on triple single-quote docstrings with sed command', () {
      const content = """
Feature: Test
  Scenario: S
    Given payload:
      '''json
      {}
      '''
""";
      final warnings = <String>[];
      final sanitized = sanitizeGherkin(content, 'features/api.feature', onWarning: warnings.add);

      expect(warnings, hasLength(2));
      expect(warnings[0], contains('[gherkart] Deprecation: Found triple single-quote docstring'));
      expect(warnings[0], contains('features/api.feature:4'));
      expect(warnings[0], contains('sed -i \'\' "s/\'\'\'/\\"\\"\\"/g" features/api.feature'));
      expect(sanitized, contains('"""json'));
      expect(sanitized, contains('"""'));
    });

    test('warns on Scenario Outline {param} with grep search and targeted sed command', () {
      const content = '''
Feature: Test
  Scenario Outline: Add numbers
    Given I have {a} and {b}
    And I also have "{t:key}"
    When I sum them
    Then the result is {sum}

    Examples:
      | a | b | sum |
      | 1 | 2 | 3   |
''';
      final warnings = <String>[];
      final sanitized = sanitizeGherkin(content, 'features/calc.feature', onWarning: warnings.add);

      expect(warnings, hasLength(1));
      expect(
        warnings[0],
        contains(
          '[gherkart] Deprecation: Scenario Outline in features/calc.feature:3 uses \'{param}\' instead of \'<param>\'',
        ),
      );
      expect(warnings[0], contains(r"grep -nE '\{(a|b|sum)\}' features/calc.feature"));
      expect(warnings[0], contains(r"sed -i '' -E 's/\{(a|b|sum)\}/<\1>/g' features/calc.feature"));

      // Verify outline placeholders are converted to <...>
      expect(sanitized, contains('Given I have <a> and <b>'));
      expect(sanitized, contains('Then the result is <sum>'));
      // Verify non-header {t:key} is preserved untouched!
      expect(sanitized, contains('And I also have "{t:key}"'));
    });
  });
}

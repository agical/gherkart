// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import 'package:gherkart/gherkart.dart';
import 'package:test/test.dart';

void main() {
  group('Scenario Outline parsing', () {
    test('parses scenario outline with examples', () {
      const content = '''
Feature: Login
  Scenario Outline: Login with credentials
    Given I am on the login page
    When I enter "<email>" and "<password>"
    Then I should see "<result>"

    Examples:
      | email          | password | result    |
      | valid@test.com | secret   | dashboard |
      | bad@test.com   | wrong    | error     |
''';
      final feature = parseFeature(content, 'test.feature');

      expect(feature.scenarioOutlines, hasLength(1));
      final outline = feature.scenarioOutlines[0];
      expect(outline.name, 'Login with credentials');
      expect(outline.steps, hasLength(3));
      expect(outline.examples, hasLength(1));
      expect(outline.examples[0].headers, ['email', 'password', 'result']);
      expect(outline.examples[0].rows, hasLength(2));
    });

    test('expands scenario outline to concrete scenarios', () {
      const content = '''
Feature: Math
  Scenario Outline: Addition
    Given I have <a>
    When I add <b>
    Then I get <result>

    Examples:
      | a | b | result |
      | 1 | 2 | 3      |
      | 5 | 5 | 10     |
''';
      final feature = parseFeature(content, 'test.feature');

      final expanded = feature.scenarioOutlines[0].expandToScenarios();
      expect(expanded, hasLength(2));
      expect(expanded[0].name, contains('Addition'));
      expect(expanded[0].name, contains('Example 1'));
      expect(expanded[0].steps[0].text, 'I have 1');
      expect(expanded[0].steps[1].text, 'I add 2');
      expect(expanded[0].steps[2].text, 'I get 3');
      expect(expanded[1].steps[0].text, 'I have 5');
    });

    test('supports {placeholder} syntax in addition to <placeholder>', () {
      const content = '''
Feature: Test
  Scenario Outline: Test placeholders
    Given value is {value}

    Examples:
      | value |
      | 42    |
''';
      final feature = parseFeature(content, 'test.feature');

      final expanded = feature.scenarioOutlines[0].expandToScenarios();
      expect(expanded[0].steps[0].text, 'value is 42');
    });

    test('parses named examples table', () {
      const content = '''
Feature: Test
  Scenario Outline: Test
    Given value <v>

    Examples: Valid inputs
      | v |
      | 1 |

    Examples: Invalid inputs
      | v  |
      | -1 |
''';
      final feature = parseFeature(content, 'test.feature');

      final outline = feature.scenarioOutlines[0];
      expect(outline.examples, hasLength(2));
      expect(outline.examples[0].name, 'Valid inputs');
      expect(outline.examples[1].name, 'Invalid inputs');
    });

    test('expanded scenario names include example table name', () {
      const content = '''
Feature: Test
  Scenario Outline: Test
    Given value <v>

    Examples: Happy path
      | v |
      | 1 |
''';
      final feature = parseFeature(content, 'test.feature');

      final expanded = feature.scenarioOutlines[0].expandToScenarios();
      expect(expanded[0].name, 'Test (Happy path #1)');
    });

    test('feature.allScenarios includes expanded outlines', () {
      const content = '''
Feature: Test
  Scenario: Regular scenario
    Given something

  Scenario Outline: Outline
    Given <v>

    Examples:
      | v |
      | 1 |
      | 2 |
''';
      final feature = parseFeature(content, 'test.feature');

      expect(feature.scenarios, hasLength(1));
      expect(feature.scenarioOutlines, hasLength(1));
      expect(feature.allScenarios, hasLength(3)); // 1 regular + 2 expanded
    });

    test('parses Scenario Template as alias for Scenario Outline', () {
      const content = '''
Feature: Test
  Scenario Template: Template test
    Given <v>

    Examples:
      | v |
      | x |
''';
      final feature = parseFeature(content, 'test.feature');

      expect(feature.scenarioOutlines, hasLength(1));
      expect(feature.scenarioOutlines[0].name, 'Template test');
    });

    test('parses tags on scenario outline', () {
      const content = '''
Feature: Test
  @smoke
  Scenario Outline: Tagged outline
    Given <v>

    Examples:
      | v |
      | 1 |
''';
      final feature = parseFeature(content, 'test.feature');

      expect(feature.scenarioOutlines[0].tags, contains('smoke'));
    });

    test('parses tags on examples table', () {
      const content = '''
Feature: Test
  Scenario Outline: Test
    Given <v>

    @slow
    Examples: Slow tests
      | v |
      | 1 |
''';
      final feature = parseFeature(content, 'test.feature');

      expect(feature.scenarioOutlines[0].examples[0].tags, contains('slow'));
    });

    test('expanded scenarios inherit outline and example tags', () {
      const content = '''
Feature: Test
  @outline-tag
  Scenario Outline: Test
    Given <v>

    @example-tag
    Examples:
      | v |
      | 1 |
''';
      final feature = parseFeature(content, 'test.feature');

      final expanded = feature.scenarioOutlines[0].expandToScenarios();
      expect(expanded[0].tags, contains('outline-tag'));
      expect(expanded[0].tags, contains('example-tag'));
    });
  });
}

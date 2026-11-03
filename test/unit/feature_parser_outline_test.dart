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

  group('Transition from old {param} to standard <param> syntax', () {
    test('expands outline with mixed <new> and {old} placeholders in same step', () {
      const content = '''
Feature: Mixed Placeholders
  Scenario Outline: Mixed addition
    Given I have <a> and {b}
    When I add <c> and {d}
    Then the result is <sum>

    Examples:
      | a  | b  | c  | d  | sum |
      | 10 | 20 | 30 | 40 | 100 |
''';
      final feature = parseFeature(content, 'mixed.feature');
      final expanded = feature.scenarioOutlines[0].expandToScenarios();

      expect(expanded, hasLength(1));
      expect(expanded[0].steps[0].text, 'I have 10 and 20');
      expect(expanded[0].steps[1].text, 'I add 30 and 40');
      expect(expanded[0].steps[2].text, 'the result is 100');
    });

    test('produces identical expansion whether using <param> or legacy {param}', () {
      const standardContent = '''
Feature: Comparison
  Scenario Outline: Math test
    Given a is <a>
    When b is <b>
    Then sum is <result>

    Examples:
      | a | b | result |
      | 1 | 2 | 3      |
      | 4 | 5 | 9      |
''';
      const legacyContent = '''
Feature: Comparison
  Scenario Outline: Math test
    Given a is {a}
    When b is {b}
    Then sum is {result}

    Examples:
      | a | b | result |
      | 1 | 2 | 3      |
      | 4 | 5 | 9      |
''';
      final standardFeature = parseFeature(standardContent, 'standard.feature');
      final legacyFeature = parseFeature(legacyContent, 'legacy.feature');

      final standardScenarios = standardFeature.scenarioOutlines[0].expandToScenarios();
      final legacyScenarios = legacyFeature.scenarioOutlines[0].expandToScenarios();

      expect(legacyScenarios.length, standardScenarios.length);
      for (var i = 0; i < standardScenarios.length; i++) {
        expect(legacyScenarios[i].name, standardScenarios[i].name);
        expect(legacyScenarios[i].tags, standardScenarios[i].tags);
        expect(legacyScenarios[i].steps.length, standardScenarios[i].steps.length);
        for (var s = 0; s < standardScenarios[i].steps.length; s++) {
          expect(legacyScenarios[i].steps[s].keyword, standardScenarios[i].steps[s].keyword);
          expect(legacyScenarios[i].steps[s].text, standardScenarios[i].steps[s].text);
        }
      }
    });

    test('handles overlapping header names without corrupting placeholders', () {
      const content = '''
Feature: Overlapping Headers
  Scenario Outline: User and Username test
    Given user is {user} and account is {username}
    And full id is <user>_<username>

    Examples:
      | user  | username |
      | alice | alice_dev |
''';
      final feature = parseFeature(content, 'overlap.feature');
      final expanded = feature.scenarioOutlines[0].expandToScenarios();

      expect(expanded[0].steps[0].text, 'user is alice and account is alice_dev');
      expect(expanded[0].steps[1].text, 'full id is alice_alice_dev');
    });

    test('substitutes placeholders inside attached DataTables', () {
      const content = '''
Feature: Table in Outline
  Scenario Outline: Adding users from table
    Given the following users:
      | name   | role   |
      | <user> | {role} |
    When processed

    Examples:
      | user  | role  |
      | Alice | admin |
      | Bob   | guest |
''';
      final feature = parseFeature(content, 'table_outline.feature');
      final expanded = feature.scenarioOutlines[0].expandToScenarios();

      expect(expanded, hasLength(2));

      // First example
      final table1 = expanded[0].steps[0].dataTable!;
      expect(table1.headers, ['name', 'role']);
      expect(table1.rows[0], ['Alice', 'admin']);
      expect(table1.toMaps()[0], {'name': 'Alice', 'role': 'admin'});

      // Second example
      final table2 = expanded[1].steps[0].dataTable!;
      expect(table2.rows[0], ['Bob', 'guest']);
      expect(table2.toMaps()[0], {'name': 'Bob', 'role': 'guest'});
    });

    test('substitutes placeholders inside attached DocStrings', () {
      const content = '''
Feature: DocString in Outline
  Scenario Outline: JSON payload with placeholders
    Given the payload:
      """json
      {
        "user": "<name>",
        "count": {count}
      }
      """
    When submitted

    Examples:
      | name    | count |
      | Charlie | 42    |
''';
      final feature = parseFeature(content, 'docstring_outline.feature');
      final expanded = feature.scenarioOutlines[0].expandToScenarios();

      expect(expanded, hasLength(1));
      final docString = expanded[0].steps[0].docString!;
      expect(docString.mediaType, 'json');
      expect(docString.content, contains('"user": "Charlie"'));
      expect(docString.content, contains('"count": 42'));
    });

    test('preserves non-header scheme braces like {t:key} untouched while converting outline headers', () {
      const content = '''
Feature: Scheme Braces Preservation
  Scenario Outline: Translation with outline value
    Given "{t:welcome}" for user <user>
    When checking "{t:greeting(time: 'morning')}"
    Then status is {status}

    Examples:
      | user  | status  |
      | Alice | success |
''';
      final feature = parseFeature(content, 'scheme_outline.feature');
      final expanded = feature.scenarioOutlines[0].expandToScenarios();

      expect(expanded[0].steps[0].text, '"{t:welcome}" for user Alice');
      expect(expanded[0].steps[1].text, 'checking "{t:greeting(time: \'morning\')}"');
      expect(expanded[0].steps[2].text, 'status is success');
    });

    test('supports outline inside Rule with legacy {param} syntax', () {
      const content = '''
Feature: Outline In Rule
  Rule: Calculation
    Background:
      Given base is 100

    Scenario Outline: Add offset
      When I add {offset}
      Then total is <sum>

      Examples:
        | offset | sum |
        | 5      | 105 |
''';
      final feature = parseFeature(content, 'rule_outline.feature');
      expect(feature.scenarioOutlines, hasLength(1));

      final expanded = feature.scenarioOutlines[0].expandToScenarios();
      expect(expanded, hasLength(1));
      expect(expanded[0].steps[0].text, 'base is 100'); // rule background
      expect(expanded[0].steps[1].text, 'I add 5');
      expect(expanded[0].steps[2].text, 'total is 105');
    });

    test('supports multiple Examples tables each expanding placeholders correctly', () {
      const content = '''
Feature: Multiple Examples
  Scenario Outline: Range validation
    Given value is <val>
    Then within range is {inRange}

    Examples: In range
      | val | inRange |
      | 5   | true    |
      | 10  | true    |

    Examples: Out of range
      | val | inRange |
      | -1  | false   |
      | 100 | false   |
''';
      final feature = parseFeature(content, 'multi_examples.feature');
      final outline = feature.scenarioOutlines[0];
      final expanded = outline.expandToScenarios();

      expect(expanded, hasLength(4));
      expect(expanded[0].name, 'Range validation (In range #1)');
      expect(expanded[0].steps[0].text, 'value is 5');
      expect(expanded[0].steps[1].text, 'within range is true');

      expect(expanded[2].name, 'Range validation (Out of range #1)');
      expect(expanded[2].steps[0].text, 'value is -1');
      expect(expanded[2].steps[1].text, 'within range is false');
    });
  });
}

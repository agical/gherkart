// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import 'package:gherkart/gherkart.dart';
import 'package:test/test.dart';

void main() {
  group('Supported keywords', () {
    group('Rule:', () {
      test('parses Rule: and includes rule scenarios', () {
        const content = '''
Feature: Rule Testing
  Rule: Users must be authorized
    Scenario: Authorized user can access
      Given an authorized user
''';
        final feature = parseFeature(content, 'test.feature');

        expect(feature.scenarios, hasLength(1));
        expect(feature.scenarios[0].name, 'Authorized user can access');
      });

      test('parses Rule: with description', () {
        const content = '''
Feature: Rule Testing
  Rule: Only admins can perform mutations
    This rule enforces admin privileges
    for all destructive operations.

    Scenario: Admin deletes user
      Given admin user
''';
        final feature = parseFeature(content, 'test.feature');

        expect(feature.scenarios, hasLength(1));
        expect(feature.scenarios[0].name, 'Admin deletes user');
      });

      test('parses multiple rules in a single feature and preserves scenario order', () {
        const content = '''
Feature: Multi-Rule Feature
  Rule: First rule
    Scenario: Rule 1 Scenario 1
      Given step 1
    Scenario: Rule 1 Scenario 2
      Given step 2

  Rule: Second rule
    Scenario: Rule 2 Scenario 1
      Given step 3
''';
        final feature = parseFeature(content, 'test.feature');

        expect(feature.scenarios, hasLength(3));
        expect(feature.scenarios[0].name, 'Rule 1 Scenario 1');
        expect(feature.scenarios[1].name, 'Rule 1 Scenario 2');
        expect(feature.scenarios[2].name, 'Rule 2 Scenario 1');
      });

      test('combines feature background and rule background for rule scenarios', () {
        const content = '''
Feature: Nested Backgrounds
  Background:
    Given feature setup

  Rule: Admin rule
    Background:
      Given rule setup

    Scenario: Admin action
      When admin does action
''';
        final feature = parseFeature(content, 'test.feature');

        expect(feature.background, isNotNull);
        expect(feature.background!.steps, hasLength(1));
        expect(feature.background!.steps[0].text, 'feature setup');

        expect(feature.scenarios, hasLength(1));
        final sc = feature.scenarios[0];
        // Rule background steps are prepended to scenario steps
        expect(sc.steps, hasLength(2));
        expect(sc.steps[0].text, 'rule setup');
        expect(sc.steps[1].text, 'admin does action');
      });

      test('inherits tags from Rule: on scenarios and scenario outlines', () {
        const content = '''
Feature: Tagged Rules
  @critical @audit
  Rule: Compliance rule
    @smoke
    Scenario: Check compliance
      Given compliance check

    @regression
    Scenario Outline: Validate rule with <val>
      Given value <val>

      Examples:
        | val |
        | 1   |
''';
        final feature = parseFeature(content, 'test.feature');

        expect(feature.scenarios, hasLength(1));
        expect(feature.scenarios[0].tags, containsAll(['critical', 'audit', 'smoke']));

        expect(feature.scenarioOutlines, hasLength(1));
        expect(feature.scenarioOutlines[0].tags, containsAll(['critical', 'audit', 'regression']));
      });

      test('parses Scenario Outline inside Rule: and expands correctly', () {
        const content = '''
Feature: Outline in Rule
  Rule: Calculation rules
    Background:
      Given calc initialized

    Scenario Outline: Add <a supply> to <b supply>
      When I add <a supply> and <b supply>
      Then total is <sum>

      Examples:
        | a supply | b supply | sum |
        | 10       | 20       | 30  |
        | 5        | 15       | 20  |
''';
        final feature = parseFeature(content, 'test.feature');

        expect(feature.scenarioOutlines, hasLength(1));
        final outline = feature.scenarioOutlines[0];
        expect(outline.name, 'Add <a supply> to <b supply>');
        final expanded = outline.expandToScenarios();
        expect(expanded, hasLength(2));

        expect(expanded[0].steps, hasLength(3));
        expect(expanded[0].steps[0].text, 'calc initialized'); // from rule background
        expect(expanded[0].steps[1].text, 'I add 10 and 20');
        expect(expanded[0].steps[2].text, 'total is 30');

        expect(expanded[1].steps, hasLength(3));
        expect(expanded[1].steps[0].text, 'calc initialized');
        expect(expanded[1].steps[1].text, 'I add 5 and 15');
        expect(expanded[1].steps[2].text, 'total is 20');
      });
    });

    group('Example: keyword (Scenario synonym)', () {
      test('parses Example: as synonym for Scenario: at top level', () {
        const content = '''
Feature: Example Keyword
  Example: This is an example
    Given something
''';
        final feature = parseFeature(content, 'test.feature');

        expect(feature.scenarios, hasLength(1));
        expect(feature.scenarios[0].name, 'This is an example');
      });

      test('parses Example: inside a Rule: with tags', () {
        const content = '''
Feature: Example in Rule
  Rule: Authentication
    @important
    Example: Valid login
      Given valid user
      When credentials provided
      Then access granted
''';
        final feature = parseFeature(content, 'test.feature');

        expect(feature.scenarios, hasLength(1));
        expect(feature.scenarios[0].name, 'Valid login');
        expect(feature.scenarios[0].tags, contains('important'));
        expect(feature.scenarios[0].steps, hasLength(3));
      });
    });

    group('Scenario Template: & Scenarios: keywords', () {
      test('parses Scenario Template: as synonym for Scenario Outline:', () {
        const content = '''
Feature: Template Keyword
  Scenario Template: Multiply numbers
    Given <x>
    When multiplied by <y>
    Then result is <product>

    Examples:
      | x | y | product |
      | 2 | 3 | 6       |
''';
        final feature = parseFeature(content, 'test.feature');

        expect(feature.scenarioOutlines, hasLength(1));
        expect(feature.scenarioOutlines[0].name, 'Multiply numbers');
        final expanded = feature.scenarioOutlines[0].expandToScenarios();
        expect(expanded, hasLength(1));
        expect(expanded[0].steps[0].text, '2');
        expect(expanded[0].steps[1].text, 'multiplied by 3');
        expect(expanded[0].steps[2].text, 'result is 6');
      });

      test('parses Scenarios: as synonym for Examples: table with multiple tables', () {
        const content = '''
Feature: Scenarios Keyword
  Scenario Outline: Divide numbers
    Given numerator <num>
    When divided by <den>
    Then quotient is <q>

    Scenarios: Integers
      | num | den | q |
      | 10  | 2   | 5 |

    @decimals
    Scenarios: Decimals
      | num | den | q   |
      | 5   | 2   | 2.5 |
''';
        final feature = parseFeature(content, 'test.feature');

        expect(feature.scenarioOutlines, hasLength(1));
        final outline = feature.scenarioOutlines[0];
        expect(outline.examples, hasLength(2));
        expect(outline.examples[0].name, 'Integers');
        expect(outline.examples[1].name, 'Decimals');
        expect(outline.examples[1].tags, contains('decimals'));

        final expanded = outline.expandToScenarios();
        expect(expanded, hasLength(2));
        expect(expanded[0].name, 'Divide numbers (Integers #1)');
        expect(expanded[1].name, 'Divide numbers (Decimals #1)');
        expect(expanded[1].tags, contains('decimals'));
      });
    });

    group('Asterisk (*) steps', () {
      test('parses * steps in feature background, scenarios, and outlines', () {
        const content = '''
Feature: Asterisk in various sections
  Background:
    * background bullet

  Scenario: Mixed steps
    * bullet before given
    Given normal given
    * bullet between
    When normal when
    * bullet after when
    Then normal then
    * bullet outcome

  Scenario Outline: Outline with bullets
    * outline bullet with <val>

    Examples:
      | val |
      | 42  |
''';
        final feature = parseFeature(content, 'test.feature');

        // Background
        expect(feature.background!.steps[0].keyword, StepKeyword.star);
        expect(feature.background!.steps[0].text, 'background bullet');
        expect(feature.background!.steps[0].fullText, '* background bullet');

        // Scenario
        final sc = feature.scenarios[0];
        expect(sc.steps, hasLength(7));
        expect(sc.steps[0].keyword, StepKeyword.star);
        expect(sc.steps[0].text, 'bullet before given');
        expect(sc.steps[0].fullText, '* bullet before given');
        expect(sc.steps[1].keyword, StepKeyword.given);
        expect(sc.steps[2].keyword, StepKeyword.star);
        expect(sc.steps[3].keyword, StepKeyword.when);
        expect(sc.steps[4].keyword, StepKeyword.star);
        expect(sc.steps[5].keyword, StepKeyword.then);
        expect(sc.steps[6].keyword, StepKeyword.star);

        // Outline
        final outline = feature.scenarioOutlines[0];
        final expanded = outline.expandToScenarios();
        expect(expanded[0].steps[0].keyword, StepKeyword.star);
        expect(expanded[0].steps[0].text, 'outline bullet with 42');
        expect(expanded[0].steps[0].fullText, '* outline bullet with 42');
      });

      test('parses * step in Rule background', () {
        const content = '''
Feature: Bullet in Rule
  Rule: Bullet rule
    Background:
      * rule bullet step
    Scenario: Target scenario
      Given step
''';
        final feature = parseFeature(content, 'test.feature');
        final sc = feature.scenarios[0];

        expect(sc.steps[0].keyword, StepKeyword.star);
        expect(sc.steps[0].text, 'rule bullet step');
        expect(sc.steps[0].fullText, '* rule bullet step');
      });
    });
  });
}

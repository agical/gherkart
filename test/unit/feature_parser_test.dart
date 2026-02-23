// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import 'package:gherkart/gherkart.dart';
import 'package:test/test.dart';

void main() {
  group('FeatureParser', () {
    group('parseFeature', () {
      test('parses feature name', () {
        const content = '''
Feature: Home Page
  Scenario: Test
    Given something
''';
        final feature = parseFeature(content, 'test.feature');

        expect(feature.name, 'Home Page');
      });

      test('parses feature name with @feature annotation', () {
        const content = '''
@feature
Feature: Home Page
  Scenario: Test
    Given something
''';
        final feature = parseFeature(content, 'test.feature');

        expect(feature.name, 'Home Page');
      });

      test('ignores import statements', () {
        const content = '''
import 'package:patrol_finders/patrol_finders.dart';

@feature
Feature: Home Page
  Scenario: Test
    Given something
''';
        final feature = parseFeature(content, 'test.feature');

        expect(feature.name, 'Home Page');
      });

      test('stores source file path', () {
        const content = '''
Feature: Test
  Scenario: Test
    Given something
''';
        final feature = parseFeature(content, 'test/features/home.feature');

        expect(feature.filePath, 'test/features/home.feature');
      });

      test('parses feature description', () {
        const content = '''
Feature: Home Page
  As a player discovering Beer Pong
  I want to see a welcoming home page
  So that I understand the app

  Scenario: Test
    Given something
''';
        final feature = parseFeature(content, 'test.feature');

        expect(feature.description, contains('As a player'));
        expect(feature.description, contains('I want to see'));
        expect(feature.description, contains('So that'));
      });
    });

    group('Background parsing', () {
      test('parses background steps', () {
        const content = '''
Feature: Test
  Background:
    Given the app is running
    And I am logged in

  Scenario: Test
    When I do something
''';
        final feature = parseFeature(content, 'test.feature');

        expect(feature.background, isNotNull);
        expect(feature.background!.steps, hasLength(2));
        expect(feature.background!.steps[0].keyword, StepKeyword.given);
        expect(feature.background!.steps[0].text, 'the app is running');
        expect(feature.background!.steps[1].keyword, StepKeyword.and);
        expect(feature.background!.steps[1].text, 'I am logged in');
      });

      test('handles feature without background', () {
        const content = '''
Feature: Test
  Scenario: Test
    Given something
''';
        final feature = parseFeature(content, 'test.feature');

        expect(feature.background, isNull);
      });
    });

    group('Scenario parsing', () {
      test('parses single scenario', () {
        const content = '''
Feature: Test
  Scenario: Navigate to home
    Given the app is running
    When I tap home
    Then I see the home page
''';
        final feature = parseFeature(content, 'test.feature');

        expect(feature.scenarios, hasLength(1));
        expect(feature.scenarios[0].name, 'Navigate to home');
        expect(feature.scenarios[0].steps, hasLength(3));
      });

      test('parses multiple scenarios', () {
        const content = '''
Feature: Test
  Scenario: First scenario
    Given something

  Scenario: Second scenario
    Given something else
''';
        final feature = parseFeature(content, 'test.feature');

        expect(feature.scenarios, hasLength(2));
        expect(feature.scenarios[0].name, 'First scenario');
        expect(feature.scenarios[1].name, 'Second scenario');
      });

      test('parses step keywords correctly', () {
        const content = '''
Feature: Test
  Scenario: Test keywords
    Given a precondition
    When an action
    Then a result
    And another thing
    But not this
''';
        final feature = parseFeature(content, 'test.feature');

        final steps = feature.scenarios[0].steps;
        expect(steps[0].keyword, StepKeyword.given);
        expect(steps[1].keyword, StepKeyword.when);
        expect(steps[2].keyword, StepKeyword.then);
        expect(steps[3].keyword, StepKeyword.and);
        expect(steps[4].keyword, StepKeyword.but);
      });

      test('preserves step text with parameters', () {
        const content = '''
Feature: Test
  Scenario: Test params
    When I navigate to "Sessions"
    And I set team to "Champions"
''';
        final feature = parseFeature(content, 'test.feature');

        final steps = feature.scenarios[0].steps;
        expect(steps[0].text, 'I navigate to "Sessions"');
        expect(steps[1].text, 'I set team to "Champions"');
      });
    });

    group('Edge cases', () {
      test('handles empty lines between scenarios', () {
        const content = '''
Feature: Test

  Scenario: First
    Given something


  Scenario: Second
    Given something else

''';
        final feature = parseFeature(content, 'test.feature');

        expect(feature.scenarios, hasLength(2));
      });

      test('handles comments', () {
        const content = '''
Feature: Test
  # This is a comment
  Scenario: Test
    Given something
    # Another comment
    When I do something
''';
        final feature = parseFeature(content, 'test.feature');

        expect(feature.scenarios[0].steps, hasLength(2));
      });

      test('trims whitespace from step text', () {
        const content = '''
Feature: Test
  Scenario: Test
    Given   extra whitespace   
''';
        final feature = parseFeature(content, 'test.feature');

        expect(feature.scenarios[0].steps[0].text, 'extra whitespace');
      });

      test('handles tags on scenarios', () {
        const content = '''
Feature: Test
  @smoke @regression
  Scenario: Tagged test
    Given something
''';
        final feature = parseFeature(content, 'test.feature');

        expect(feature.scenarios[0].tags, contains('smoke'));
        expect(feature.scenarios[0].tags, contains('regression'));
      });

      test('handles tags on feature', () {
        const content = '''
@feature @critical
Feature: Important Feature
  Scenario: Test
    Given something
''';
        final feature = parseFeature(content, 'test.feature');

        expect(feature.tags, contains('feature'));
        expect(feature.tags, contains('critical'));
      });
    });

    group('Step fullText', () {
      test('includes keyword in full text', () {
        const content = '''
Feature: Test
  Scenario: Test
    Given the app is running
''';
        final feature = parseFeature(content, 'test.feature');
        final step = feature.scenarios[0].steps[0];

        expect(step.fullText, 'Given the app is running');
      });
    });
  });

  group('AssetSource feature discovery', () {
    test('discovers .feature files from map source', () async {
      final source = AssetSource.fromMap({
        'features/login.feature': 'Feature: Login',
        'features/home.feature': 'Feature: Home',
        'features/nested/deep.feature': 'Feature: Deep',
      });

      final files = await source.list('features');

      expect(files, hasLength(3));
      expect(files.every((f) => f.endsWith('.feature')), isTrue);
    });

    test('discovers files recursively from map', () async {
      final source = AssetSource.fromMap({
        'features/login.feature': 'Feature: Login',
        'features/nested/deep.feature': 'Feature: Deep',
      });

      final files = await source.list('features');

      expect(files.any((f) => f.contains('nested/')), isTrue);
    });
  });

  group('DataTable parsing', () {
    test('parses data table attached to step', () {
      const content = '''
Feature: User Management
  Scenario: Create users
    Given the following users:
      | name  | email           |
      | Alice | alice@test.com  |
      | Bob   | bob@test.com    |
    When I save the users
''';
      final feature = parseFeature(content, 'test.feature');

      final step = feature.scenarios[0].steps[0];
      expect(step.dataTable, isNotNull);
      expect(step.dataTable!.headers, ['name', 'email']);
      expect(step.dataTable!.rows, hasLength(2));
      expect(step.dataTable!.rows[0], ['Alice', 'alice@test.com']);
      expect(step.dataTable!.rows[1], ['Bob', 'bob@test.com']);
    });

    test('data table toMaps returns list of maps', () {
      const content = '''
Feature: Test
  Scenario: Test
    Given users:
      | name  | role  |
      | Alice | admin |
      | Bob   | user  |
''';
      final feature = parseFeature(content, 'test.feature');

      final maps = feature.scenarios[0].steps[0].dataTable!.toMaps();
      expect(maps, hasLength(2));
      expect(maps[0], {'name': 'Alice', 'role': 'admin'});
      expect(maps[1], {'name': 'Bob', 'role': 'user'});
    });

    test('step without data table has null dataTable', () {
      const content = '''
Feature: Test
  Scenario: Test
    Given something simple
''';
      final feature = parseFeature(content, 'test.feature');

      expect(feature.scenarios[0].steps[0].dataTable, isNull);
    });

    test('parses multiple steps with data tables', () {
      const content = '''
Feature: Test
  Scenario: Test
    Given users:
      | name  |
      | Alice |
    And roles:
      | role  |
      | admin |
''';
      final feature = parseFeature(content, 'test.feature');

      final steps = feature.scenarios[0].steps;
      expect(steps[0].dataTable, isNotNull);
      expect(steps[0].dataTable!.headers, ['name']);
      expect(steps[1].dataTable, isNotNull);
      expect(steps[1].dataTable!.headers, ['role']);
    });

    test('data table includes source location', () {
      const content = '''
Feature: Test
  Scenario: Test
    Given data:
      | col |
      | val |
''';
      final feature = parseFeature(content, 'test.feature');

      final table = feature.scenarios[0].steps[0].dataTable!;
      expect(table.location, isNotNull);
      expect(table.location!.line, 4); // Line of first | row
    });
  });

  group('DocString parsing', () {
    test('parses doc string attached to step', () {
      const content = '''
Feature: API Testing
  Scenario: Post JSON
    Given the request body:
      """
      {
        "name": "Test",
        "value": 42
      }
      """
    When I send the request
''';
      final feature = parseFeature(content, 'test.feature');

      final step = feature.scenarios[0].steps[0];
      expect(step.docString, isNotNull);
      expect(step.docString!.content, contains('"name": "Test"'));
      expect(step.docString!.content, contains('"value": 42'));
    });

    test('parses doc string with media type', () {
      const content = '''
Feature: Test
  Scenario: Test
    Given the JSON:
      """json
      {"key": "value"}
      """
''';
      final feature = parseFeature(content, 'test.feature');

      final docString = feature.scenarios[0].steps[0].docString!;
      expect(docString.mediaType, 'json');
      expect(docString.content, contains('"key": "value"'));
    });

    test('parses doc string with alternate delimiter', () {
      const content = """
Feature: Test
  Scenario: Test
    Given the text:
      '''
      Line 1
      Line 2
      '''
""";
      final feature = parseFeature(content, 'test.feature');

      final docString = feature.scenarios[0].steps[0].docString!;
      expect(docString.content, contains('Line 1'));
      expect(docString.content, contains('Line 2'));
    });

    test('step without doc string has null docString', () {
      const content = '''
Feature: Test
  Scenario: Test
    Given something simple
''';
      final feature = parseFeature(content, 'test.feature');

      expect(feature.scenarios[0].steps[0].docString, isNull);
    });

    test('doc string includes source location', () {
      const content = '''
Feature: Test
  Scenario: Test
    Given content:
      """
      text
      """
''';
      final feature = parseFeature(content, 'test.feature');

      final docString = feature.scenarios[0].steps[0].docString!;
      expect(docString.location, isNotNull);
      expect(docString.location!.line, 4); // Line of opening """
    });
  });

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

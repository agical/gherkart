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
}

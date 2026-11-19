// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import 'package:gherkart/gherkart.dart';
import 'package:test/test.dart';

void main() {
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

    test('handles escaped pipes (\\|) and empty cells in data tables', () {
      const content = r'''
Feature: Table Escapes
  Scenario: Test
    Given a table:
      | column \| with pipe | empty cell |
      | value \| 1           |            |
''';
      final feature = parseFeature(content, 'test.feature');
      final table = feature.scenarios[0].steps[0].dataTable!;

      expect(table.headers, ['column | with pipe', 'empty cell']);
      expect(table.rows[0], ['value | 1', '']);
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

    test('supports backtick (```) doc strings', () {
      const content = '''
Feature: Doc strings
  Scenario: Test
    Given a payload:
      ```json
      {"valid": true}
      ```
''';
      final feature = parseFeature(content, 'test.feature');
      final docString = feature.scenarios[0].steps[0].docString!;

      expect(docString.mediaType, 'json');
      expect(docString.content, contains('"valid": true'));
    });
  });
}

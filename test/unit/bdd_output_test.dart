// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import 'package:gherkart/gherkart.dart';
import 'package:test/test.dart';

void main() {
  group('BddOutput', () {
    group('configuration', () {
      test('defaults to minimal output', () {
        const output = BddOutput();

        expect(output.showFeatureNames, isFalse);
        expect(output.showScenarioNames, isFalse);
        expect(output.showSteps, isFalse);
        expect(output.showStepTiming, isFalse);
      });

      test('verbose enables all output', () {
        const output = BddOutput.verbose();

        expect(output.showFeatureNames, isTrue);
        expect(output.showScenarioNames, isTrue);
        expect(output.showSteps, isTrue);
        expect(output.showStepTiming, isTrue);
      });

      test('steps enables feature, scenario and steps', () {
        const output = BddOutput.steps();

        expect(output.showFeatureNames, isTrue);
        expect(output.showScenarioNames, isTrue);
        expect(output.showSteps, isTrue);
        expect(output.showStepTiming, isFalse);
      });

      test('scenarios enables feature and scenario names', () {
        const output = BddOutput.scenarios();

        expect(output.showFeatureNames, isTrue);
        expect(output.showScenarioNames, isTrue);
        expect(output.showSteps, isFalse);
        expect(output.showStepTiming, isFalse);
      });

      test('custom configuration', () {
        const output = BddOutput(
          showFeatureNames: true,
          showScenarioNames: false,
          showSteps: true,
          showStepTiming: false,
        );

        expect(output.showFeatureNames, isTrue);
        expect(output.showScenarioNames, isFalse);
        expect(output.showSteps, isTrue);
        expect(output.showStepTiming, isFalse);
      });
    });

    group('formatting', () {
      test('formats feature name', () {
        const output = BddOutput.verbose();
        final formatted = output.formatFeature('Home Page');

        expect(formatted, contains('Home Page'));
        expect(formatted, contains('Feature'));
      });

      test('formats scenario name', () {
        const output = BddOutput.verbose();
        final formatted = output.formatScenario('Navigate to settings');

        expect(formatted, contains('Navigate to settings'));
        expect(formatted, contains('Scenario'));
      });

      test('formats step with keyword', () {
        const output = BddOutput.verbose();
        final formatted = output.formatStep('Given', 'the app is running');

        expect(formatted, contains('Given'));
        expect(formatted, contains('the app is running'));
      });

      test('formats step with timing', () {
        const output = BddOutput.verbose();
        final formatted = output.formatStepComplete(
          'Given',
          'the app is running',
          Duration(milliseconds: 150),
        );

        expect(formatted, contains('Given'));
        expect(formatted, contains('the app is running'));
        expect(formatted, contains('150'));
      });

      test('formats step without timing when disabled', () {
        const output = BddOutput.steps();
        final formatted = output.formatStepComplete(
          'When',
          'I tap the button',
          Duration(milliseconds: 100),
        );

        expect(formatted, contains('When'));
        expect(formatted, contains('I tap the button'));
        expect(formatted, isNot(contains('100')));
      });
    });

    group('conditional output', () {
      late List<String> printed;
      late void Function(String) testPrint;

      setUp(() {
        printed = [];
        testPrint = (s) => printed.add(s);
      });

      test('prints feature when enabled', () {
        const output = BddOutput(showFeatureNames: true);
        output.printFeature('Test Feature', testPrint);

        expect(printed, hasLength(1));
        expect(printed[0], contains('Test Feature'));
      });

      test('skips feature when disabled', () {
        const output = BddOutput(showFeatureNames: false);
        output.printFeature('Test Feature', testPrint);

        expect(printed, isEmpty);
      });

      test('prints scenario when enabled', () {
        const output = BddOutput(showScenarioNames: true);
        output.printScenario('Test Scenario', testPrint);

        expect(printed, hasLength(1));
        expect(printed[0], contains('Test Scenario'));
      });

      test('skips scenario when disabled', () {
        const output = BddOutput(showScenarioNames: false);
        output.printScenario('Test Scenario', testPrint);

        expect(printed, isEmpty);
      });

      test('prints step when enabled', () {
        const output = BddOutput(showSteps: true);
        output.printStep('Given', 'something', testPrint);

        expect(printed, hasLength(1));
      });

      test('skips step when disabled', () {
        const output = BddOutput(showSteps: false);
        output.printStep('Given', 'something', testPrint);

        expect(printed, isEmpty);
      });
    });
  });
}

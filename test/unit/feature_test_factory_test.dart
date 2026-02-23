// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import 'package:gherkart/gherkart.dart';
import 'package:test/test.dart';

void main() {
  group('FeatureTestFactory', () {
    group('configuration', () {
      test('creates with root path and registry', () {
        final registry = StepRegistry<void>();
        final factory = FeatureTestFactory(
          rootPath: 'test/features',
          registry: registry,
        );

        expect(factory.rootPath, 'test/features');
        expect(factory.registry, registry);
      });

      test('defaults to tree structure', () {
        final factory = FeatureTestFactory(
          rootPath: 'test/features',
          registry: StepRegistry<void>(),
        );

        expect(factory.structure, TestStructure.tree);
      });

      test('can configure flat structure', () {
        final factory = FeatureTestFactory(
          rootPath: 'test/features',
          registry: StepRegistry<void>(),
          structure: TestStructure.flat,
        );

        expect(factory.structure, TestStructure.flat);
      });
    });

    group('buildTestPlan', () {
      test('groups tests by feature', () {
        final feature = Feature(
          name: 'Home Page',
          filePath: 'test/features/home.feature',
          scenarios: [
            Scenario(name: 'Navigate home', steps: []),
            Scenario(name: 'See welcome', steps: []),
          ],
        );

        final factory = FeatureTestFactory(
          rootPath: 'test/features',
          registry: StepRegistry<void>(),
        );

        final plan = factory.buildTestPlan([feature]);

        expect(plan.groups, hasLength(1));
        expect(plan.groups[0].name, 'Home Page');
        expect(plan.groups[0].tests, hasLength(2));
      });

      test('includes background steps in test group', () {
        final feature = Feature(
          name: 'Edit Session',
          filePath: 'test/features/edit_session.feature',
          background: Background(
            steps: [
              Step(keyword: StepKeyword.given, text: 'the app is running'),
              Step(keyword: StepKeyword.and, text: 'I have an imported session'),
            ],
          ),
          scenarios: [
            Scenario(name: 'View session', steps: [
              Step(keyword: StepKeyword.when, text: 'I tap the session'),
            ]),
          ],
        );

        final factory = FeatureTestFactory(
          rootPath: 'test/features',
          registry: StepRegistry<void>(),
        );

        final plan = factory.buildTestPlan([feature]);

        expect(plan.groups, hasLength(1));
        expect(plan.groups[0].backgroundSteps, hasLength(2));
        expect(plan.groups[0].backgroundSteps[0].text, 'the app is running');
        expect(plan.groups[0].backgroundSteps[1].text, 'I have an imported session');
      });

      test('tree structure nests by folder', () {
        final features = [
          Feature(
            name: 'Sessions Import',
            filePath: 'test/features/sessions/import.feature',
            scenarios: [Scenario(name: 'Test', steps: [])],
          ),
          Feature(
            name: 'Sessions List',
            filePath: 'test/features/sessions/list.feature',
            scenarios: [Scenario(name: 'Test', steps: [])],
          ),
        ];

        final factory = FeatureTestFactory(
          rootPath: 'test/features',
          registry: StepRegistry<void>(),
          structure: TestStructure.tree,
        );

        final plan = factory.buildTestPlan(features);

        // Should have a parent group for 'sessions'
        expect(plan.groups, hasLength(1));
        expect(plan.groups[0].name, 'sessions');
        expect(plan.groups[0].children, hasLength(2));
      });

      test('flat structure has no nesting', () {
        final features = [
          Feature(
            name: 'Sessions Import',
            filePath: 'test/features/sessions/import.feature',
            scenarios: [Scenario(name: 'Test', steps: [])],
          ),
          Feature(
            name: 'Sessions List',
            filePath: 'test/features/sessions/list.feature',
            scenarios: [Scenario(name: 'Test', steps: [])],
          ),
        ];

        final factory = FeatureTestFactory(
          rootPath: 'test/features',
          registry: StepRegistry<void>(),
          structure: TestStructure.flat,
        );

        final plan = factory.buildTestPlan(features);

        expect(plan.groups, hasLength(2));
        expect(plan.groups[0].children, isEmpty);
        expect(plan.groups[1].children, isEmpty);
      });

      group('tag propagation', () {
        test('merges feature tags with scenario tags', () {
          final feature = Feature(
            name: 'User Management',
            filePath: 'test/features/user.feature',
            tags: ['wip', 'users'],
            scenarios: [
              Scenario(
                name: 'Create user',
                tags: ['create'],
                steps: [],
              ),
              Scenario(
                name: 'Delete user',
                tags: [],
                steps: [],
              ),
            ],
          );

          final factory = FeatureTestFactory(
            rootPath: 'test/features',
            registry: StepRegistry<void>(),
          );

          final plan = factory.buildTestPlan([feature]);

          // Scenario with its own tags should have merged tags
          expect(plan.groups[0].tests[0].tags, containsAll(['wip', 'users', 'create']));
          // Scenario without tags should inherit feature tags
          expect(plan.groups[0].tests[1].tags, containsAll(['wip', 'users']));
        });

        test('scenario tags do not duplicate feature tags', () {
          final feature = Feature(
            name: 'Test',
            filePath: 'test.feature',
            tags: ['wip'],
            scenarios: [
              Scenario(
                name: 'Test',
                tags: ['wip', 'other'],
                steps: [],
              ),
            ],
          );

          final factory = FeatureTestFactory(
            rootPath: 'test/features',
            registry: StepRegistry<void>(),
          );

          final plan = factory.buildTestPlan([feature]);

          // Should not have duplicate 'wip' tags
          expect(plan.groups[0].tests[0].tags.where((t) => t == 'wip').length, 1);
        });
      });
    });

    group('findMissingSteps', () {
      test('returns empty list when all steps are registered', () {
        final registry = StepRegistry<void>.fromMap({
          'the app is running'.mapper(): (_, args) async {},
          'I tap home'.mapper(): (_, args) async {},
        });

        final feature = Feature(
          name: 'Test',
          filePath: 'test.feature',
          scenarios: [
            Scenario(
              name: 'Test scenario',
              steps: [
                Step(keyword: StepKeyword.given, text: 'the app is running'),
                Step(keyword: StepKeyword.when, text: 'I tap home'),
              ],
            ),
          ],
        );

        final factory = FeatureTestFactory(
          rootPath: 'test/features',
          registry: registry,
        );

        final missing = factory.findMissingSteps([feature]);

        expect(missing, isEmpty);
      });

      test('returns missing step texts', () {
        final registry = StepRegistry<void>.fromMap({
          'the app is running'.mapper(): (_, args) async {},
        });

        final feature = Feature(
          name: 'Test',
          filePath: 'test.feature',
          scenarios: [
            Scenario(
              name: 'Test scenario',
              steps: [
                Step(keyword: StepKeyword.given, text: 'the app is running'),
                Step(keyword: StepKeyword.when, text: 'I tap unknown button'),
              ],
            ),
          ],
        );

        final factory = FeatureTestFactory(
          rootPath: 'test/features',
          registry: registry,
        );

        final missing = factory.findMissingSteps([feature]);

        expect(missing, hasLength(1));
        expect(missing[0].text, 'I tap unknown button');
      });

      test('checks background steps', () {
        final registry = StepRegistry<void>();

        final feature = Feature(
          name: 'Test',
          filePath: 'test.feature',
          background: Background(
            steps: [
              Step(keyword: StepKeyword.given, text: 'background step'),
            ],
          ),
          scenarios: [
            Scenario(
              name: 'Test scenario',
              steps: [],
            ),
          ],
        );

        final factory = FeatureTestFactory(
          rootPath: 'test/features',
          registry: registry,
        );

        final missing = factory.findMissingSteps([feature]);

        expect(missing.map((s) => s.text), contains('background step'));
      });

      test('deduplicates missing steps', () {
        final registry = StepRegistry<void>();

        final feature = Feature(
          name: 'Test',
          filePath: 'test.feature',
          scenarios: [
            Scenario(
              name: 'First',
              steps: [
                Step(keyword: StepKeyword.given, text: 'same step'),
              ],
            ),
            Scenario(
              name: 'Second',
              steps: [
                Step(keyword: StepKeyword.given, text: 'same step'),
              ],
            ),
          ],
        );

        final factory = FeatureTestFactory(
          rootPath: 'test/features',
          registry: registry,
        );

        final missing = factory.findMissingSteps([feature]);

        expect(missing, hasLength(1));
      });
    });

    group('generatePlaceholders', () {
      test('generates code for missing steps', () {
        final registry = StepRegistry<void>();

        final factory = FeatureTestFactory(
          rootPath: 'test/features',
          registry: registry,
        );

        final placeholders = factory.generatePlaceholders([
          Step(keyword: StepKeyword.given, text: 'the app is running'),
          Step(keyword: StepKeyword.when, text: 'I navigate to "Home"'),
        ]);

        expect(placeholders, contains("'the app is running'.mapper()"));
        expect(placeholders, contains('I navigate to "Home"'));
      });
    });
  });

  group('TestPlan', () {
    test('counts total tests', () {
      final plan = TestPlan(groups: [
        TestGroup(
          name: 'Feature 1',
          tests: [
            TestCase(name: 'Test 1', steps: []),
            TestCase(name: 'Test 2', steps: []),
          ],
        ),
        TestGroup(
          name: 'Feature 2',
          tests: [
            TestCase(name: 'Test 3', steps: []),
          ],
        ),
      ]);

      expect(plan.totalTests, 3);
    });

    test('counts nested tests', () {
      final plan = TestPlan(groups: [
        TestGroup(
          name: 'Parent',
          children: [
            TestGroup(
              name: 'Child',
              tests: [
                TestCase(name: 'Test 1', steps: []),
              ],
            ),
          ],
        ),
      ]);

      expect(plan.totalTests, 1);
    });
  });
}

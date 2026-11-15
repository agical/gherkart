// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:cucumber_messages/cucumber_messages.dart' as cm;

import 'bdd_reporter.dart';
import 'step_registry.dart';

/// Pure-Dart Cucumber Messages NDJSON reporter.
///
/// Emits standard [Cucumber Messages](https://github.com/cucumber/messages)
/// envelopes serialized as Newline-Delimited JSON (NDJSON), compatible with
/// official Cucumber HTML, JSON, and JUnit formatters as well as the
/// Cucumber Compatibility Kit (CCK).
///
/// Safe to use in Flutter widget tests (`FakeAsync`) and web environments
/// because it performs no `dart:io` file operations directly. For writing
/// directly to a file on desktop/mobile/CI, see `NdjsonFileReporter`.
///
/// Example:
/// ```dart
/// final buffer = StringBuffer();
/// final reporter = NdjsonReporter(sink: buffer);
///
/// await runBddTests<void>(
///   rootPaths: ['test/features'],
///   registry: registry,
///   adapter: adapter,
///   source: source,
///   reporter: reporter,
/// );
/// ```
class NdjsonReporter implements BddReporter {
  /// Cucumber Messages schema protocol version emitted in [cm.Meta].
  static const String protocolVersion = '34.2.1';

  /// Optional [StringSink] where serialized NDJSON lines are written on [flush].
  final StringSink? sink;

  /// Optional callback invoked for each serialized JSON line (without trailing newline) on [flush].
  final void Function(String jsonLine)? onLine;

  /// Optional callback invoked for each emitted [cm.Envelope] on [flush].
  final void Function(cm.Envelope envelope)? onEnvelope;

  /// URI used in [cm.SourceReference] for emitted [cm.StepDefinition] messages.
  final String stepDefinitionsUri;

  /// Optional custom ID generator for deterministic testing.
  final String Function()? idGenerator;

  /// Optional clock function supplying timestamps for emitted messages.
  final DateTime Function()? clock;

  /// Optional custom [cm.Meta] envelope payload.
  final cm.Meta? meta;

  StepDefinitionProvider? _registry;

  final List<_NdjsonFeatureRun> _features = [];
  _NdjsonFeatureRun? _currentFeature;
  _NdjsonScenarioRun? _currentScenario;
  final List<cm.Envelope> _emittedEnvelopes = [];

  /// Creates an [NdjsonReporter].
  NdjsonReporter({
    this.sink,
    this.onLine,
    this.onEnvelope,
    StepDefinitionProvider? registry,
    this.stepDefinitionsUri = 'steps.dart',
    this.idGenerator,
    this.clock,
    this.meta,
  }) : _registry = registry;

  /// Attaches a [StepDefinitionProvider] if none was explicitly configured.
  ///
  /// Called automatically by `BddTestRunner` so `StepDefinition` envelopes,
  /// argument match offsets, and `Suggestion` snippets are emitted seamlessly.
  void attachRegistry(StepDefinitionProvider registry) {
    _registry ??= registry;
  }

  /// All Cucumber Message [cm.Envelope]s emitted during the most recent [flush].
  List<cm.Envelope> get envelopes => List.unmodifiable(_emittedEnvelopes);

  /// Returns all emitted envelopes formatted as an NDJSON string.
  String toNdjson() => _emittedEnvelopes.map((e) => '${cm.envelopeToJsonString(e)}\n').join();

  @override
  void onFeatureStart(ReportFeature feature) {
    // Deduplicate if the same feature path was already registered
    final existing = _features.where((f) => f.feature.path == feature.path).firstOrNull;
    if (existing != null) {
      _currentFeature = existing;
      return;
    }
    final run = _NdjsonFeatureRun(feature);
    _features.add(run);
    _currentFeature = run;
  }

  @override
  void onFeatureComplete(ReportFeature feature, FeatureResult result) {
    final target = _features.where((f) => f.feature.path == feature.path).firstOrNull ?? _currentFeature;
    target?.result = result;
    if (target == _currentFeature) {
      _currentFeature = null;
    }
  }

  @override
  void onScenarioStart(ReportScenario scenario) {
    final scenRun = _NdjsonScenarioRun(scenario);
    final targetFeature = scenario.featurePath != null
        ? (_features.where((f) => f.feature.path == scenario.featurePath).firstOrNull ?? _currentFeature)
        : _currentFeature;
    if (targetFeature != null) {
      targetFeature.scenarios.add(scenRun);
    } else {
      // Fallback synthetic feature if onScenarioStart was called without onFeatureStart
      final synthetic = _NdjsonFeatureRun(
        ReportFeature(name: 'Feature', path: scenario.featurePath ?? 'feature.feature'),
      );
      synthetic.scenarios.add(scenRun);
      _features.add(synthetic);
      _currentFeature = synthetic;
    }
    _currentScenario = scenRun;
  }

  @override
  void onScenarioComplete(ReportScenario scenario, ScenarioResult result) {
    _NdjsonScenarioRun? target;
    if (scenario.featurePath != null) {
      final feat = _features.where((f) => f.feature.path == scenario.featurePath).firstOrNull;
      if (feat != null) {
        if (scenario.pickle != null) {
          target = feat.scenarios.where((s) => s.scenario.pickle?.id == scenario.pickle!.id).lastOrNull;
        }
        target ??= feat.scenarios.where((s) => s.scenario.name == scenario.name && s.result == null).firstOrNull;
        target ??= feat.scenarios.where((s) => s.scenario.name == scenario.name).lastOrNull;
      }
    }
    target ??= _currentScenario;
    target?.result = result;
    if (target == _currentScenario) {
      _currentScenario = null;
    }
  }

  @override
  void onStepStart(ReportStep step) {
    _currentScenario?.steps.add(_NdjsonStepRun(step));
  }

  @override
  void onStepComplete(ReportStep step, StepResult result) {
    final current = _currentScenario;
    if (current == null) return;
    final pending =
        current.steps.where((s) => s.result == null && s.step.text == step.text).firstOrNull ??
        current.steps.where((s) => s.result == null).lastOrNull;
    if (pending != null) {
      pending.result = result;
    } else {
      current.steps.add(_NdjsonStepRun(step)..result = result);
    }
  }

  @override
  void flush() {
    _emittedEnvelopes.clear();

    final usedIds = <String>{};
    for (final featRun in _features) {
      final gherkinEnvs = featRun.feature.sourceFeature?.gherkinEnvelopes ?? const <cm.Envelope>[];
      for (final env in gherkinEnvs) {
        _collectEnvelopeIds(env, usedIds);
      }
    }

    final rawGen = idGenerator ?? _defaultUuidGenerator();
    String nextId() {
      var candidate = rawGen();
      while (!usedIds.add(candidate)) {
        candidate = rawGen();
      }
      return candidate;
    }

    cm.Timestamp nowTimestamp() {
      final dt = clock != null ? clock!() : DateTime.now().toUtc();
      return cm.dateTimeToTimestamp(dt);
    }

    void emit(cm.Envelope envelope) {
      _emittedEnvelopes.add(envelope);
      onEnvelope?.call(envelope);
      if (sink != null || onLine != null) {
        final line = cm.envelopeToJsonString(envelope);
        onLine?.call(line);
        sink?.writeln(line);
      }
    }

    // 1. Meta envelope
    emit(
      cm.Envelope(
        meta:
            meta ??
            const cm.Meta(
              protocolVersion: protocolVersion,
              implementation: cm.Product(name: 'gherkart', version: '0.2.1'),
              runtime: cm.Product(name: 'Dart'),
              os: cm.Product(name: 'unknown'),
              cpu: cm.Product(name: 'unknown'),
            ),
      ),
    );

    // 2. Source, GherkinDocument, and Pickle envelopes per feature
    final resolvedPickles = <_NdjsonScenarioRun, cm.Pickle>{};

    for (final featRun in _features) {
      final parsedFeature = featRun.feature.sourceFeature;
      if (parsedFeature != null && parsedFeature.gherkinEnvelopes.isNotEmpty) {
        final featurePickles = <cm.Pickle>[];
        for (final env in parsedFeature.gherkinEnvelopes) {
          emit(env);
          if (env.pickle != null) {
            featurePickles.add(env.pickle!);
          }
        }

        final claimedPickleIds = <String>{};
        for (final scenRun in featRun.scenarios) {
          cm.Pickle? matched = scenRun.scenario.pickle;
          matched ??= featurePickles
              .where((p) => !claimedPickleIds.contains(p.id) && _scenarioMatchesPickle(scenRun.scenario.name, p.name))
              .firstOrNull;
          if (matched != null) {
            claimedPickleIds.add(matched.id);
            resolvedPickles[scenRun] = matched;
          } else {
            final synth = _synthesizePickle(scenRun, featRun.feature.path, featRun.feature.tags, nextId);
            emit(cm.Envelope(pickle: synth));
            resolvedPickles[scenRun] = synth;
          }
        }
      } else {
        // Standalone reporter usage without parsed Feature
        final synthEnvelopes = _synthesizeFeatureEnvelopes(featRun, nextId, resolvedPickles);
        for (final env in synthEnvelopes) {
          emit(env);
        }
      }
    }

    // 3. StepDefinition envelopes
    final stepDefIdsByIndex = <int, String>{};
    final syntheticStepDefIdsByText = <String, String>{};

    if (_registry != null) {
      for (var i = 0; i < _registry!.stepCount; i++) {
        final defId = nextId();
        stepDefIdsByIndex[i] = defId;
        emit(
          cm.Envelope(
            stepDefinition: cm.StepDefinition(
              id: defId,
              pattern: cm.StepDefinitionPattern(
                type: cm.StepDefinitionPatternType.cucumberExpression,
                source: _registry!.patternAt(i) ?? 'step_$i',
              ),
              sourceReference: cm.SourceReference(
                uri: stepDefinitionsUri,
                location: cm.Location(line: i + 1),
              ),
            ),
          ),
        );
      }
    } else {
      var lineNum = 1;
      for (final featRun in _features) {
        for (final scenRun in featRun.scenarios) {
          for (final stepRun in scenRun.steps) {
            if (stepRun.result?.isUndefined == true) continue;
            final text = stepRun.step.text;
            if (!syntheticStepDefIdsByText.containsKey(text)) {
              final defId = nextId();
              syntheticStepDefIdsByText[text] = defId;
              emit(
                cm.Envelope(
                  stepDefinition: cm.StepDefinition(
                    id: defId,
                    pattern: cm.StepDefinitionPattern(
                      type: cm.StepDefinitionPatternType.cucumberExpression,
                      source: text,
                    ),
                    sourceReference: cm.SourceReference(
                      uri: stepDefinitionsUri,
                      location: cm.Location(line: lineNum++),
                    ),
                  ),
                ),
              );
            }
          }
        }
      }
    }

    // 4. TestRunStarted
    final testRunStartedId = nextId();
    emit(
      cm.Envelope(
        testRunStarted: cm.TestRunStarted(id: testRunStartedId, timestamp: nowTimestamp()),
      ),
    );

    // 5. Build and emit TestCase envelopes
    final preparedCases = <_PreparedTestCase>[];

    for (final featRun in _features) {
      for (final scenRun in featRun.scenarios) {
        final pickle = resolvedPickles[scenRun]!;
        final testSteps = <cm.TestStep>[];

        for (var i = 0; i < pickle.steps.length; i++) {
          final pickleStep = pickle.steps[i];
          List<String> stepDefIds;
          List<cm.StepMatchArgumentsList> argLists;

          if (_registry != null) {
            final matchInfo = _registry!.matchStepDefinition(pickleStep.text);
            if (matchInfo != null) {
              stepDefIds = [stepDefIdsByIndex[matchInfo.definitionIndex]!];
              argLists = [
                cm.StepMatchArgumentsList(
                  stepMatchArguments: matchInfo.arguments
                      .map(
                        (a) => cm.StepMatchArgument(
                          group: cm.Group(start: a.start, value: a.value),
                          parameterTypeName: a.parameterTypeName,
                        ),
                      )
                      .toList(),
                ),
              ];
            } else {
              stepDefIds = const [];
              argLists = const [];
            }
          } else {
            final synthId = syntheticStepDefIdsByText[pickleStep.text];
            if (synthId != null) {
              stepDefIds = [synthId];
              argLists = const [cm.StepMatchArgumentsList(stepMatchArguments: [])];
            } else {
              stepDefIds = const [];
              argLists = const [];
            }
          }

          testSteps.add(
            cm.TestStep(
              id: nextId(),
              pickleStepId: pickleStep.id,
              stepDefinitionIds: stepDefIds,
              stepMatchArgumentsLists: argLists,
            ),
          );
        }

        final testCase = cm.TestCase(
          id: nextId(),
          pickleId: pickle.id,
          testSteps: testSteps,
          testRunStartedId: testRunStartedId,
        );
        emit(cm.Envelope(testCase: testCase));
        preparedCases.add(_PreparedTestCase(scenRun: scenRun, pickle: pickle, testCase: testCase));
      }
    }

    // 6. Emit TestCaseStarted, TestStepStarted, Suggestion, TestStepFinished, TestCaseFinished
    var allRunSuccess = true;

    for (final item in preparedCases) {
      final scenRun = item.scenRun;
      final pickle = item.pickle;
      final testCase = item.testCase;

      final testCaseStartedId = nextId();
      emit(
        cm.Envelope(
          testCaseStarted: cm.TestCaseStarted(
            id: testCaseStartedId,
            testCaseId: testCase.id,
            attempt: 0,
            timestamp: nowTimestamp(),
          ),
        ),
      );

      var priorStepHalted = false;

      for (var k = 0; k < testCase.testSteps.length; k++) {
        final testStep = testCase.testSteps[k];
        final pickleStep = pickle.steps[k];

        emit(
          cm.Envelope(
            testStepStarted: cm.TestStepStarted(
              testCaseStartedId: testCaseStartedId,
              testStepId: testStep.id,
              timestamp: nowTimestamp(),
            ),
          ),
        );

        final isStepUnmatched = testStep.stepDefinitionIds != null && testStep.stepDefinitionIds!.isEmpty;
        cm.TestStepResult stepResultMsg;

        if (priorStepHalted) {
          stepResultMsg = const cm.TestStepResult(
            status: cm.TestStepResultStatus.skipped,
            duration: cm.Duration(seconds: 0, nanos: 0),
          );
        } else if (k < scenRun.steps.length && scenRun.steps[k].result != null) {
          final rec = scenRun.steps[k].result!;
          final dur = cm.durationToDurationMessage(rec.duration ?? Duration.zero);

          if (rec.isUndefined || isStepUnmatched) {
            emit(
              cm.Envelope(
                suggestion: cm.Suggestion(
                  id: nextId(),
                  pickleStepId: pickleStep.id,
                  snippets: [cm.Snippet(language: 'dart', code: StepRegistry.suggestPlaceholder(pickleStep.text))],
                ),
              ),
            );
            stepResultMsg = cm.TestStepResult(status: cm.TestStepResultStatus.undefined, duration: dur);
            priorStepHalted = true;
            allRunSuccess = false;
          } else {
            switch (rec.status) {
              case StepStatus.passed:
                stepResultMsg = cm.TestStepResult(status: cm.TestStepResultStatus.passed, duration: dur);
              case StepStatus.skipped:
                stepResultMsg = cm.TestStepResult(status: cm.TestStepResultStatus.skipped, duration: dur);
                priorStepHalted = true;
              case StepStatus.failed:
                final excType = rec.exception != null ? rec.exception.runtimeType.toString() : 'Error';
                stepResultMsg = cm.TestStepResult(
                  status: cm.TestStepResultStatus.failed,
                  duration: dur,
                  message: rec.error,
                  exception: cm.Exception(type: excType, message: rec.error, stackTrace: rec.stackTrace?.toString()),
                );
                priorStepHalted = true;
                allRunSuccess = false;
            }
          }
        } else if (isStepUnmatched) {
          emit(
            cm.Envelope(
              suggestion: cm.Suggestion(
                id: nextId(),
                pickleStepId: pickleStep.id,
                snippets: [cm.Snippet(language: 'dart', code: StepRegistry.suggestPlaceholder(pickleStep.text))],
              ),
            ),
          );
          stepResultMsg = const cm.TestStepResult(
            status: cm.TestStepResultStatus.undefined,
            duration: cm.Duration(seconds: 0, nanos: 0),
          );
          priorStepHalted = true;
          allRunSuccess = false;
        } else if (scenRun.result?.status == ScenarioStatus.skipped) {
          stepResultMsg = const cm.TestStepResult(
            status: cm.TestStepResultStatus.skipped,
            duration: cm.Duration(seconds: 0, nanos: 0),
          );
          priorStepHalted = true;
        } else if (scenRun.result?.status == ScenarioStatus.failed) {
          // Defined step that was never executed because upfront missing-step check aborted the scenario
          stepResultMsg = const cm.TestStepResult(
            status: cm.TestStepResultStatus.skipped,
            duration: cm.Duration(seconds: 0, nanos: 0),
          );
        } else {
          stepResultMsg = const cm.TestStepResult(
            status: cm.TestStepResultStatus.passed,
            duration: cm.Duration(seconds: 0, nanos: 0),
          );
        }

        emit(
          cm.Envelope(
            testStepFinished: cm.TestStepFinished(
              testCaseStartedId: testCaseStartedId,
              testStepId: testStep.id,
              testStepResult: stepResultMsg,
              timestamp: nowTimestamp(),
            ),
          ),
        );
      }

      if (scenRun.result?.status == ScenarioStatus.failed) {
        allRunSuccess = false;
      }

      emit(
        cm.Envelope(
          testCaseFinished: cm.TestCaseFinished(
            testCaseStartedId: testCaseStartedId,
            timestamp: nowTimestamp(),
            willBeRetried: false,
          ),
        ),
      );
    }

    // 7. TestRunFinished
    emit(
      cm.Envelope(
        testRunFinished: cm.TestRunFinished(
          testRunStartedId: testRunStartedId,
          timestamp: nowTimestamp(),
          success: allRunSuccess,
        ),
      ),
    );
  }

  static bool _scenarioMatchesPickle(String scenarioName, String pickleName) {
    if (scenarioName == pickleName) return true;
    return scenarioName.startsWith('$pickleName (') && scenarioName.endsWith(')');
  }

  static List<cm.Envelope> _synthesizeFeatureEnvelopes(
    _NdjsonFeatureRun featRun,
    String Function() nextId,
    Map<_NdjsonScenarioRun, cm.Pickle> resolvedPickles,
  ) {
    final uri = featRun.feature.path;
    final children = <cm.FeatureChild>[];
    final pickleEnvelopes = <cm.Envelope>[];
    final sourceBuffer = StringBuffer('Feature: ${featRun.feature.name}\n');

    var line = 2;
    for (final scenRun in featRun.scenarios) {
      final scenId = nextId();
      final scenLoc = cm.Location(line: line++, column: 3);
      sourceBuffer.writeln('  Scenario: ${scenRun.scenario.name}');

      final astSteps = <cm.Step>[];
      final pickleSteps = <cm.PickleStep>[];

      for (final stepRun in scenRun.steps) {
        final stepAstId = nextId();
        final kw = stepRun.step.keyword.endsWith(' ') ? stepRun.step.keyword : '${stepRun.step.keyword} ';
        sourceBuffer.writeln('    $kw${stepRun.step.text}');
        astSteps.add(
          cm.Step(
            id: stepAstId,
            location: cm.Location(line: line++, column: 5),
            keyword: kw,
            text: stepRun.step.text,
          ),
        );
        pickleSteps.add(
          cm.PickleStep(
            id: nextId(),
            text: stepRun.step.text,
            type: _inferPickleStepType(stepRun.step.keyword),
            astNodeIds: [stepAstId],
          ),
        );
      }

      children.add(
        cm.FeatureChild(
          scenario: cm.Scenario(
            id: scenId,
            location: scenLoc,
            keyword: 'Scenario',
            name: scenRun.scenario.name,
            description: '',
            steps: astSteps,
            tags: const [],
            examples: const [],
          ),
        ),
      );

      final allTags = <String>{...featRun.feature.tags, ...scenRun.scenario.tags};
      final pickle = cm.Pickle(
        id: nextId(),
        uri: uri,
        location: scenLoc,
        name: scenRun.scenario.name,
        language: 'en',
        steps: pickleSteps,
        tags: allTags.map((t) => cm.PickleTag(name: t.startsWith('@') ? t : '@$t', astNodeId: nextId())).toList(),
        astNodeIds: [scenId],
      );
      resolvedPickles[scenRun] = pickle;
      pickleEnvelopes.add(cm.Envelope(pickle: pickle));
    }

    final doc = cm.GherkinDocument(
      uri: uri,
      comments: const [],
      feature: cm.Feature(
        location: const cm.Location(line: 1, column: 1),
        tags: featRun.feature.tags
            .map(
              (t) => cm.Tag(
                location: const cm.Location(line: 1, column: 1),
                name: t.startsWith('@') ? t : '@$t',
                id: nextId(),
              ),
            )
            .toList(),
        language: 'en',
        keyword: 'Feature',
        name: featRun.feature.name,
        description: '',
        children: children,
      ),
    );

    return [
      cm.Envelope(
        source: cm.Source(
          uri: uri,
          data: sourceBuffer.toString(),
          mediaType: cm.SourceMediaType.textXCucumberGherkinPlain,
        ),
      ),
      cm.Envelope(gherkinDocument: doc),
      ...pickleEnvelopes,
    ];
  }

  static cm.Pickle _synthesizePickle(
    _NdjsonScenarioRun scenRun,
    String uri,
    List<String> featureTags,
    String Function() nextId,
  ) {
    final scenAstId = nextId();
    final pickleSteps = scenRun.steps
        .map(
          (s) => cm.PickleStep(
            id: nextId(),
            text: s.step.text,
            type: _inferPickleStepType(s.step.keyword),
            astNodeIds: [nextId()],
          ),
        )
        .toList();
    final allTags = <String>{...featureTags, ...scenRun.scenario.tags};
    return cm.Pickle(
      id: nextId(),
      uri: uri,
      name: scenRun.scenario.name,
      language: 'en',
      steps: pickleSteps,
      tags: allTags.map((t) => cm.PickleTag(name: t.startsWith('@') ? t : '@$t', astNodeId: nextId())).toList(),
      astNodeIds: [scenAstId],
    );
  }

  static cm.PickleStepType _inferPickleStepType(String keyword) {
    switch (keyword.trim().toLowerCase()) {
      case 'given':
        return cm.PickleStepType.context;
      case 'when':
        return cm.PickleStepType.action;
      case 'then':
        return cm.PickleStepType.outcome;
      default:
        return cm.PickleStepType.unknown;
    }
  }

  static void _collectEnvelopeIds(cm.Envelope env, Set<String> ids) {
    if (env.pickle != null) {
      ids.add(env.pickle!.id);
      ids.addAll(env.pickle!.astNodeIds);
      for (final s in env.pickle!.steps) {
        ids.add(s.id);
        ids.addAll(s.astNodeIds);
      }
      for (final t in env.pickle!.tags) {
        ids.add(t.astNodeId);
      }
    }
    if (env.gherkinDocument?.feature != null) {
      final f = env.gherkinDocument!.feature!;
      for (final t in f.tags) {
        ids.add(t.id);
      }
      for (final c in f.children) {
        if (c.background != null) {
          ids.add(c.background!.id);
          for (final s in c.background!.steps) {
            ids.add(s.id);
          }
        }
        if (c.scenario != null) {
          _collectScenarioIds(c.scenario!, ids);
        }
        if (c.rule != null) {
          ids.add(c.rule!.id);
          for (final t in c.rule!.tags) {
            ids.add(t.id);
          }
          for (final rc in c.rule!.children) {
            if (rc.background != null) {
              ids.add(rc.background!.id);
              for (final s in rc.background!.steps) {
                ids.add(s.id);
              }
            }
            if (rc.scenario != null) {
              _collectScenarioIds(rc.scenario!, ids);
            }
          }
        }
      }
    }
  }

  static void _collectScenarioIds(cm.Scenario sc, Set<String> ids) {
    ids.add(sc.id);
    for (final t in sc.tags) {
      ids.add(t.id);
    }
    for (final s in sc.steps) {
      ids.add(s.id);
    }
    for (final ex in sc.examples) {
      ids.add(ex.id);
      for (final t in ex.tags) {
        ids.add(t.id);
      }
      if (ex.tableHeader != null) {
        ids.add(ex.tableHeader!.id);
      }
      for (final r in ex.tableBody) {
        ids.add(r.id);
      }
    }
  }

  static String Function() _defaultUuidGenerator() {
    final random = Random.secure();
    return () {
      final bytes = List<int>.generate(16, (_) => random.nextInt(256));
      bytes[6] = (bytes[6] & 0x0f) | 0x40;
      bytes[8] = (bytes[8] & 0x3f) | 0x80;
      final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
      return '${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-'
          '${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-'
          '${hex.sublist(10, 16).join()}';
    };
  }
}

class _NdjsonFeatureRun {
  final ReportFeature feature;
  FeatureResult? result;
  final List<_NdjsonScenarioRun> scenarios = [];

  _NdjsonFeatureRun(this.feature);
}

class _NdjsonScenarioRun {
  final ReportScenario scenario;
  ScenarioResult? result;
  final List<_NdjsonStepRun> steps = [];

  _NdjsonScenarioRun(this.scenario);
}

class _NdjsonStepRun {
  final ReportStep step;
  StepResult? result;

  _NdjsonStepRun(this.step);
}

class _PreparedTestCase {
  final _NdjsonScenarioRun scenRun;
  final cm.Pickle pickle;
  final cm.TestCase testCase;

  const _PreparedTestCase({required this.scenRun, required this.pickle, required this.testCase});
}

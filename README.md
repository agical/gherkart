# Gherkart

A lightweight, runtime BDD framework for Dart and Flutter widget testing.
Parse Gherkin `.feature` files at runtime — no code generation required.

## Features at a Glance

### Gherkin / Cucumber Standard

| Feature | Description |
|---------|-------------|
| Scenarios & Background | `Scenario:`, `Background:` with Given / When / Then steps |
| Scenario Outlines | `Scenario Outline:` with `Examples:` tables (`<param>` and `{param}` syntax) |
| Data Tables | Step-attached structured tables |
| Doc Strings | Multi-line `"""` text blocks on steps |
| Tags | `@smoke`, `@wip`, `@slow` etc. with feature → scenario inheritance |
| Missing step detection | Reports unregistered steps with source locations |

### Gherkart Improvements

| Feature | Description |
|---------|-------------|
| Runtime parsing | Reads `.feature` files at test time, no code generation or build step |
| Framework-agnostic | Pluggable `TestAdapter` for `test`, `flutter_test`, Patrol, or any runner |
| Typed parameters | `{name}` placeholders with auto-conversion to `int`, `double`, `bool` |
| Multiple sources | `FileSystemSource` (disk) or `AssetSource` (in-memory / web) |
| Registry merging | Compose step registries from separate modules |
| Scheme resolution | `{t:translationKey}` parameter schemes for i18n and key lookup |
| Translation handlers | ARB file, map, or function-based lookup with parameterized values |
| Configurable output | Silent → scenario names → steps → verbose with timing |
| Reporting system | `SummaryReporter`, `BufferedReporter`, `MarkdownFileReporter`, composable |
| Test structure | Tree (nested by directory) or flat grouping |
| Lifecycle hooks | `beforeAll`, `afterAll`, `beforeEach`, `afterEach` with tag access |

---

## Quick Start

> Full example: [example/demo_test.dart](example/demo_test.dart) +
> [example/features/demo.feature](example/features/demo.feature)

### 1. Add dependency

```yaml
# pubspec.yaml
dev_dependencies:
  gherkart:
    path: packages/gherkart  # or from pub.dev
```

### 2. Write a feature file

```gherkin
# example/features/demo.feature
Feature: BDD Framework Demo
  A simple demo to verify the BDD framework works.

  Scenario: Simple math
    Given I have the number 5
    When I add 3
    Then the result is 8
```

### 3. Define steps

```dart
final mathSteps = StepRegistry<void>.fromMap({
  'I have the number {n}'.mapper(types: {'n': int}): ($, ctx) async {
    _state.number = ctx.arg<int>(0);
  },
  'I add {n}'.mapper(types: {'n': int}): ($, ctx) async {
    _state.number += ctx.arg<int>(0);
  },
  'the result is {expected}'.mapper(types: {'expected': int}): ($, ctx) async {
    expect(_state.number, ctx.arg<int>(0));
  },
});
```

### 4. Run tests

```dart
import 'package:gherkart/gherkart.dart';
import 'package:gherkart/gherkart_io.dart';
import 'package:test/test.dart';

void main() async {
  await runBddTests<void>(
    rootPaths: ['example/features/demo.feature'],
    registry: mathSteps,
    source: FileSystemSource(),
    adapter: _createTestAdapter(),
    output: const BddOutput.steps(),
  );
}
```

## Usage with Flutter & Patrol

```dart
import 'package:gherkart/gherkart.dart';
import 'package:gherkart/gherkart_io.dart';
import 'package:patrol_finders/patrol_finders.dart';

void main() async {
  await runBddTests<PatrolTester>(
    rootPaths: ['test/features'],
    registry: myStepRegistry,
    source: FileSystemSource(),
    adapter: TestAdapter<PatrolTester>(
      testFunction: (name, {tags, skip = false, required callback}) {
        patrolWidgetTest(name, tags: tags, skip: skip, ($) => callback($));
      },
      group: group,
      setUpAll: setUpAll,
      tearDownAll: tearDownAll,
      fail: (message) => fail(message),
    ),
    output: const BddOutput.steps(),
  );
}
```

---

# Core

## Gherkin Parser

The parser supports the full Gherkin syntax relevant to testing.

### Scenarios & Background

> Example: [example/features/background.feature](example/features/background.feature)

```gherkin
Feature: Background Demo
  Demonstrates that Background steps run before each scenario.

  Background:
    Given I have the number 10

  Scenario: Add with background
    When I add 5
    Then the result is 15
```

Background steps are prepended to every scenario in the feature.

### Scenario Outlines

> Example: [example/features/outline.feature](example/features/outline.feature)

```gherkin
Scenario Outline: Addition with examples
  Given I have the number <a>
  When I add <b>
  Then the result is <sum>

  Examples: Small numbers
    | a  | b  | sum |
    | 1  | 2  | 3   |
    | 5  | 3  | 8   |

  Examples: Larger numbers
    | a   | b   | sum  |
    | 100 | 200 | 300  |
    | 999 | 1   | 1000 |
```

Each example row becomes a separate test case. Both `<placeholder>` and `{placeholder}` syntax are supported in step text.

### Data Tables

> Example: [example/features/data_tables.feature](example/features/data_tables.feature) +
> [example/data_tables_test.dart](example/data_tables_test.dart)

```gherkin
Scenario: Add items from a table
  Given I have an empty inventory
  When I add items:
    | name    | quantity |
    | Apples  | 5        |
    | Oranges | 3        |
    | Bananas | 2        |
  Then the total quantity is 10
```

Access in step code via `ctx.tableRows`:

```dart
'I add items:'.mapper(): ($, ctx) async {
  for (final row in ctx.tableRows) {
    final name = row['name']!;
    final qty = int.parse(row['quantity']!);
    inventory[name] = (inventory[name] ?? 0) + qty;
  }
},
```

### Doc Strings

> Example: [example/features/doc_strings.feature](example/features/doc_strings.feature) +
> [example/data_tables_test.dart](example/data_tables_test.dart)

```gherkin
Scenario: Parse JSON configuration
  Given the configuration:
    """json
    {
      "theme": "dark",
      "fontSize": 14
    }
    """
  Then the theme is "dark"
  And the font size is 14
```

Access via `ctx.docContent`:

```dart
'the configuration:'.mapper(): ($, ctx) async {
  final config = json.decode(ctx.docContent) as Map<String, dynamic>;
  // ...
},
```

### Tags

> Example: [example/features/tagged.feature](example/features/tagged.feature)

```gherkin
@smoke
Feature: Tagged Feature Demo

  Scenario: Regular scenario inherits feature tags
    Given I have the number 10
    When I add 5
    Then the result is 15

  @wip
  Scenario: WIP scenario should be skippable
    Given I have the number 100
    When I add 50
    Then the result is 150
```

- Feature tags are inherited by all scenarios
- `@wip` scenarios are automatically skipped
- Tags are passed to the test framework for filtering (`--tags smoke`)

## Step Registry

> Example: [example/demo_test.dart](example/demo_test.dart)

### Pattern Matching

Steps are matched by pattern with `{param}` placeholders:

```dart
final mathSteps = StepRegistry<void>.fromMap({
  'I have the number {n}'.mapper(types: {'n': int}): ($, ctx) async {
    _state.number = ctx.arg<int>(0);
  },
  'I add {n}'.mapper(types: {'n': int}): ($, ctx) async {
    _state.number += ctx.arg<int>(0);
  },
  'the result is {expected}'.mapper(types: {'expected': int}): ($, ctx) async {
    expect(_state.number, ctx.arg<int>(0));
  },
});
```

### Typed Parameters

The `.mapper()` extension accepts a `types` map for automatic conversion:

| Type     | Example input | Parsed as       |
|----------|---------------|-----------------|
| `String` | `"hello"`     | `'hello'`       |
| `int`    | `42`          | `42`            |
| `double` | `3.14`        | `3.14`          |
| `bool`   | `true`        | `true`          |

### Merging Registries

> Example: [example/data_tables_test.dart](example/data_tables_test.dart) — merges `inventorySteps` + `configSteps`

Compose step definitions from separate modules:

```dart
final inventorySteps = StepRegistry<void>.fromMap({ ... });
final configSteps = StepRegistry<void>.fromMap({ ... });

final allSteps = inventorySteps.merge(configSteps);
```

### Missing Step Detection

When a feature file references an unregistered step, the runner reports all missing steps with source file locations and generates ready-to-paste placeholder code:

```
MissingStepsException: 2 step(s) not found:
  - test/features/login.feature:12: I enter valid credentials
  - test/features/login.feature:13: I should see the dashboard
```

## Feature Sources

### FileSystemSource

Reads `.feature` files from disk. Requires `dart:io` — import from `gherkart_io.dart`:

```dart
import 'package:gherkart/gherkart_io.dart';

final source = FileSystemSource();
```

### AssetSource

In-memory source for web or bundled assets:

```dart
// From a map
final source = AssetSource.fromMap({
  'login.feature': 'Feature: Login\n  Scenario: ...',
});

// From a loader function (e.g. rootBundle)
final source = AssetSource.fromLoader((path) async {
  return await rootBundle.loadString('assets/$path');
});
```

---

# Add-ons

## Scheme Resolution

> Example: [example/scheme_test.dart](example/scheme_test.dart) +
> [example/features/scheme.feature](example/features/scheme.feature)
>
> Parameterized example: [example/parameterized_translation_test.dart](example/parameterized_translation_test.dart) +
> [example/features/parameterized_translation.feature](example/features/parameterized_translation.feature)
>
> Plural example (map): [example/plural_translation_test.dart](example/plural_translation_test.dart) +
> [example/features/plural_translation.feature](example/features/plural_translation.feature)
>
> Plural example (ARB): [example/plural_translation_arb_test.dart](example/plural_translation_arb_test.dart) +
> [example/features/plural_translation_arb.feature](example/features/plural_translation_arb.feature)

Transform parameter values before they reach step functions using scheme prefixes:

```gherkin
Then I see the text "{t:hello}"                                # Simple key lookup
Then I see the text "{t:welcome(name: 'Alice')}"               # Parameterized: "Welcome, Alice!"
Then I see the text "{t:greeting(name: 'Alice', time: 'morning')}"  # Multiple params
Then I see the text "plain text"                               # Literal (no scheme)
```

When parameters are provided with `{t:key(param: value)}` syntax, the key
and a `Map<String, String>` of parameters are passed to the scheme handler,
which resolves the final value. String values should be single-quoted;
unquoted values (like numbers) are kept as-is.

### ICU Plural Support

The built-in translation handlers (`createMapTranslationHandler` and
`createArbTranslationHandler`) support ICU MessageFormat plural syntax:

```gherkin
# Feature file
Then "{t:shotLabel(count: 0)}" is "no shots"
Then "{t:shotLabel(count: 1)}" is "1 shot"
Then "{t:shotLabel(count: 5)}" is "5 shots"
```

```dart
final resolver = SchemeResolver()
  ..register(
    't',
    createMapTranslationHandler({
      'shotLabel': '{count, plural, =0{no shots} =1{1 shot} other{{count} shots}}',
    }),
  );
```

Supported plural features:

| Syntax | Description |
|--------|---------------------------------------------|
| `=0`, `=1`, `=N` | Exact numeric match |
| `other` | Fallback when no exact match is found |
| `{param}` | Substituted with the parameter value inside a plural branch |
| `#` | Shorthand for the plural parameter's value |

Plurals can be mixed with regular `{param}` placeholders:

```dart
// "{t:userShots(name: 'Alice', count: 2)}" → "Alice scored 2 shots"
'userShots': '{name} scored {count, plural, =0{nothing} =1{1 shot} other{{count} shots}}',
```

### Registering Scheme Handlers

```dart
final resolver = SchemeResolver()
  ..register(
    't',
    createMapTranslationHandler({
      'hello': 'Hello, World!',
      'goodbye': 'See you later!',
      'welcome': 'Welcome, {name}!',          // parameterized
      'greeting': 'Good {time}, {name}!',     // multiple placeholders
    }),
  );

await runBddTests<void>(
  // ...
  schemeResolver: resolver,
);
```

### Built-in Translation Handlers

| Handler                          | Source                    |
|----------------------------------|---------------------------|
| `createArbTranslationHandler`    | ARB file (via FeatureSource) |
| `createMapTranslationHandler`    | In-memory `Map<String, String>` |
| `createTranslationHandler`       | Sync lookup function      |
| `createKeyMappingHandler`        | Widget key name → value   |

### Using Scheme Handlers in Widget Tests

#### The Problem

`testWidgets` (and `patrolWidgetTest`) runs test callbacks inside Flutter's `FakeAsync` zone. Real `dart:io` operations like `File.readAsString()` **never complete** inside `FakeAsync` because it doesn't process the real I/O event loop.

Scheme handlers are called during step execution — inside the test callback, inside `FakeAsync`. Any handler that performs file I/O (such as `createArbTranslationHandler`, which lazily reads the ARB file on first `{t:key}` resolution) will cause an infinite hang.

Note: Feature file reading happens in `main()` via `runBddTests` / `BddTestRunner.run()`, so `FileSystemSource` is **not** affected.

#### Recommended Pattern

Pre-read any files in `main()` (which runs outside `FakeAsync`) and pass the data to your scheme handler:

```dart
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  // Read ARB here in main() — outside the FakeAsync zone.
  // testWidgets callbacks run inside FakeAsync where dart:io never completes.
  final arbContent = await File('lib/l10n/en.arb').readAsString();
  final arbMap = (json.decode(arbContent) as Map<String, dynamic>)
      .cast<String, String>();

  final schemeResolver = SchemeResolver()
    ..register('t', createMapTranslationHandler(arbMap));

  await runBddTests(
    schemeResolver: schemeResolver,
    // ...
  );
}
```

#### Why not `createArbTranslationHandler`?

| Handler | Reads file | Safe in FakeAsync |
|---------|-----------|-------------------|
| `createArbTranslationHandler` | Lazily, on first `{t:key}` use | **No** — hangs forever |
| `createMapTranslationHandler` | Never (you provide the map) | **Yes** |

`createArbTranslationHandler` is fine for CLI tools or integration tests that run in a real async zone. For widget tests, always use `createMapTranslationHandler` with a pre-loaded map.

The same applies to any custom scheme handler: if it does file I/O, do the reading in `main()` and pass the result into the handler.

#### Rule of thumb

**Any dart:io in `main()` → safe. Any dart:io inside a scheme handler or test callback → hangs in FakeAsync.**

## Output Verbosity

> Example: [example/data_tables_test.dart](example/data_tables_test.dart) uses `BddOutput.verbose()`,
> [example/demo_test.dart](example/demo_test.dart) uses `BddOutput.steps()`

Control what prints during test execution:

| Preset                    | Feature names | Scenario names | Steps | Timing |
|---------------------------|:---:|:---:|:---:|:---:|
| `BddOutput.none`         |     |     |     |     |
| `BddOutput.scenarios()`  | ✓   | ✓   |     |     |
| `BddOutput.steps()`      | ✓   | ✓   | ✓   |     |
| `BddOutput.verbose()`    | ✓   | ✓   | ✓   | ✓   |

```dart
await runBddTests<void>(
  // ...
  output: const BddOutput.verbose(),
);
```

Example verbose output:

```
📋 Feature: User Login
  🎬 Scenario: Valid login
    ✓ Given the app is running (42ms)
    ✓ When I enter valid credentials (128ms)
    ✓ Then I see the dashboard (15ms)
```

## Test Structure

> Example: [example/reporter_test.dart](example/reporter_test.dart) uses `TestStructure.tree`,
> [example/demo_test.dart](example/demo_test.dart) uses `TestStructure.flat`

Control how test groups are organized:

| Structure            | Description                                          |
|----------------------|------------------------------------------------------|
| `TestStructure.flat` | One `group()` per feature, no folder nesting         |
| `TestStructure.tree` | Groups nested by folder structure (default)          |

```dart
await runBddTests<void>(
  // ...
  structure: TestStructure.tree,
);
```

## Reporters

> Example: [example/reporter_test.dart](example/reporter_test.dart)

Reporters collect structured results from test execution for post-processing.

### Built-in Reporters

| Reporter              | Behavior                                         |
|-----------------------|--------------------------------------------------|
| `ContinuousReporter`  | Prints events as they happen                     |
| `BufferedReporter`     | Collects all events, reports on `flush()`        |
| `SummaryReporter`      | Prints pass/fail/skip counts                     |
| `CompositeReporter`    | Combines multiple reporters                      |
| `MarkdownFileReporter` | Writes per-feature Markdown files with results   |

### Markdown Report Generation

Generate human-readable feature documentation from test results:

```dart
final reporter = MarkdownFileReporter(
  outputDir: 'build/docs/features',
  cleanFirst: true,
);

await runBddTests<PatrolTester>(
  // ...
  reporter: reporter,
);
```

This produces Markdown files mirroring your feature directory structure, with pass/fail status for each scenario and step.

## Lifecycle Hooks

> Example: [example/reporter_test.dart](example/reporter_test.dart)

```dart
await runBddTests<PatrolTester>(
  // ...
  hooks: BddHooks(
    beforeAll: () async { /* one-time setup */ },
    afterAll: () async { /* one-time teardown */ },
    beforeEach: (scenarioName, tags) async { /* per-scenario setup */ },
    afterEach: (scenarioName, success, tags) async { /* per-scenario teardown */ },
  ),
);
```

---

## API Reference

### Libraries

| Library           | Description                              |
|-------------------|------------------------------------------|
| `gherkart.dart`   | Core API — parser, runner, registry, reporters |
| `gherkart_io.dart` | `FileSystemSource` (requires `dart:io`)  |

### Key Types

| Type                 | Purpose                                          |
|----------------------|--------------------------------------------------|
| `StepRegistry<T>`    | Maps step patterns to functions                  |
| `StepContext`        | Provides args, table, docString to step functions |
| `LineMapper`         | Pattern matcher created via `String.mapper()`    |
| `BddTestRunner<T>`  | Orchestrates discovery, parsing, and execution   |
| `TestAdapter<T>`    | Plugs in any test framework                      |
| `FeatureSource`     | Abstraction for reading feature files            |
| `SchemeResolver`    | Transforms parameter values via scheme handlers  |
| `BddOutput`         | Controls console output verbosity                |
| `BddReporter`       | Interface for structured test result reporting   |
| `BddHooks<T>`       | Lifecycle callbacks for setup/teardown           |
| `Feature`           | Parsed Gherkin feature with scenarios            |
| `Scenario`          | Parsed scenario with steps                       |
| `ScenarioOutline`   | Template scenario expanded via Examples tables   |
| `DataTable`         | Structured table data attached to a step         |
| `DocString`         | Multi-line string attached to a step             |
| `TestPlan`          | Organized test groups ready for execution        |
| `FeatureTestFactory` | Builds test plans from parsed features          |
| `MarkdownFileReporter` | Generates Markdown docs from test results     |

## Development

```bash
# Run all tests (unit + examples)
just test-all

# Run unit tests only
just test-unit

# Run all examples
just test-example

# Run individual examples
just test-example-demo       # scenarios, background, tags, outlines
just test-example-data       # data tables, doc strings, registry merging
just test-example-scheme     # scheme resolution, translation handlers
just test-example-reporter   # reporters, lifecycle hooks, tree structure

# Static analysis
just analyze

# Format code
just format

# All checks before committing
just check
```

### Commit messages

Use the format:

```
feat/fix/refactor: Short description

Somewhat longer description when needed.
```

### Branches and pull requests

This project follows the [git flow](https://nvie.com/posts/a-successful-git-branching-model/) branching model by Vincent Driessen, using the [git-flow AVH](https://github.com/petervanderdoes/gitflow-avh) tool.

The default branch is `develop`. Pull request branches should be based on `develop` and named:

- `feature/*` — new features

CI runs on all pushes to `main`, `develop`, `feature/*`, `hotfix/*`, and `release/*`.
On pull requests, coverage is checked and must not decrease.



## License

MIT — see [LICENSE](LICENSE).

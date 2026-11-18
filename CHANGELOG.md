# Changelog

## 0.3.0

### Features

- **Adopt official Cucumber Dart packages** — feature parsing, step expressions, and message
  serialization are now powered by official `cucumber_gherkin`, `cucumber_messages`, and
  `cucumber_expressions` packages.
- **Official Cucumber Expressions & custom `ParameterType` support**:
  - Added `String.cucumber()`, `RegExp.mapper()`, `StepRegistry.fromExpressions`, and fluent
    `step` / `given` / `when` / `then` / `and` / `but` / `regex` methods coexisting seamlessly
    with `String.mapper()`.
  - Supports built-in typed `{int}`, `{float}`, `{string}`, `{word}`, and `{}` parameters,
    optional text (`apple(s)`), alternatives (`is/are`), and custom `ParameterType<T>`
    definitions via `registry.defineParameterType(...)`.
  - Replaced custom placeholder suggestion logic in `StepRegistry.suggestPlaceholder` /
    `suggestPlaceholders` with official `CucumberExpressionGenerator`.
- **Extended Gherkin keyword support**:
  - `Rule:` sections for grouping scenarios with rule-level backgrounds and tag inheritance
  - `Example:` supported as a synonym for `Scenario:`
  - `Scenario Template:` and `Scenarios:` supported as synonyms for `Scenario Outline:` and `Examples:`
  - `*` (bullet / asterisk) steps supported in backgrounds, scenarios, outlines, and rules
- **Multi-language support (i18n)** — parse feature files in 70+ languages supported by Cucumber
  using the standard `# language: <locale>` comment header.
- **Cucumber Messages NDJSON reporting** — added `NdjsonReporter`, `NdjsonFileReporter`, and
  `ReportMode.ndjson` emitting standard Cucumber Messages protocol envelopes (`Meta`, `Source`,
  `GherkinDocument`, `Pickle`, `ParameterType`, `StepDefinition`, `TestRunStarted`, `TestCase`,
  `TestCaseStarted`, `TestStepStarted`, `Suggestion`, `TestStepFinished`, `TestCaseFinished`,
  `TestRunFinished`), unlocking official Cucumber HTML, JSON, and JUnit formatters.
- **Dynamic step skipping** — step functions can throw `SkipScenarioException` to mark a step and
  any remaining steps in the scenario as `SKIPPED` without failing the run.
- **Official Cucumber compliance suites** — verified against all 62 `cucumber/gherkin` good/bad
  acceptance feature files and 15 Cucumber Compatibility Kit (CCK) suites (`just test-compliance`).
- **Enhanced Data Table, Doc String & Description support** — supports escaped pipes (`\|`) and empty
  cells in tables, both `"""` and ```` ``` ```` delimiters for doc strings, multi-paragraph feature
  descriptions, and `<param>` placeholder substitution within Scenario Outline titles, step-attached
  tables, and doc string content & media types.
- **Precise parse diagnostics** — `GherkinParseException` provides line and column coordinates for
  malformed feature files.
- **Pre-sanitizer with migration diagnostics** — automatically translates legacy syntax
  (`import` lines, `'''` docstrings, and `{param}` in Scenario Outlines) while printing actionable
  warnings with exact `grep` and `sed` terminal commands to update files.
- **Coverage summary** — `just test-coverage` now reports per-file and overall coverage numbers.

### Changes

- Dart SDK minimum floor raised from `>=3.2.0` to `>=3.8.0` to match `cucumber_gherkin`.

## 0.2.1

### Features

- **Parameterized translations** — `{t:key(param: value)}` syntax for passing
  parameters to scheme handlers. The handler receives the key and a
  `Map<String, String>` of parameters and resolves the final value.
  Works with ARB, map, and custom translation handlers.
- **ICU plural support** — built-in handlers resolve `{count, plural, =0{...} =1{...} other{...}}`
  syntax from ARB files and map translations. Supports exact matches (`=N`),
  `other` fallback, `{param}` substitution, and `#` shorthand.
- `ResolvedParam` now exposes a `params` field with parsed parameters
- Use tags for automated publishing to pub.dev

### Breaking Changes

- `SchemeHandler` typedef changed from `(String value)` to
  `(String key, Map<String, String> params)`. Custom handlers must update
  their signature. If you use the built-in factory functions
  (`createMapTranslationHandler`, `createArbTranslationHandler`, etc.)
  for automatic placeholder substitution, no change is needed.

## 0.1.4

### Improvements

- Broaden package description to include Dart and Flutter
- Add automated pub.dev publishing via official dart-lang/setup-dart reusable workflow
- Document git flow branching model and commit conventions in README

## 0.1.0

Initial release of Gherkart — a runtime BDD framework for Dart and Flutter.

### Features

- **Runtime Gherkin parsing** — reads `.feature` files at test time, no code generation required
- **Full Gherkin support** — Scenarios, Background, Scenario Outlines with Examples tables, Data Tables, Doc Strings
- **Tag filtering** — `@smoke`, `@wip`, `@slow` etc. with feature → scenario inheritance
- **Framework-agnostic** — pluggable `TestAdapter` for `test`, `flutter_test`, Patrol, or custom runners
- **Typed parameters** — `{name}` placeholders with auto-conversion to `int`, `double`, `bool`
- **Multiple sources** — `FileSystemSource` (disk) or `AssetSource` (in-memory / web)
- **Registry composition** — merge step registries from separate modules
- **Scheme resolution** — `{t:translationKey}` parameter schemes for i18n and key lookup
- **Translation handlers** — ARB file, map, or function-based lookup
- **Configurable output** — silent, scenario names, steps, or verbose with timing
- **Reporting system** — `SummaryReporter`, `BufferedReporter`, `MarkdownFileReporter`, composable
- **Test structure options** — tree (nested by directory) or flat grouping
- **Lifecycle hooks** — `beforeAll`, `afterAll`, `beforeEach`, `afterEach` with tag access
- **Missing step detection** — reports unregistered steps with source locations

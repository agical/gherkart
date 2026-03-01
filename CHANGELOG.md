# Changelog

## 0.2.0

### Features

- **Parameterized translations** — `{t:key(param: value)}` syntax for passing
  parameters to scheme handlers. The handler receives the key and a
  `Map<String, String>` of parameters and resolves the final value.
  Works with ARB, map, and custom translation handlers.
- **ICU plural support** — built-in handlers resolve `{count, plural, =0{...} =1{...} other{...}}`
  syntax from ARB files and map translations. Supports exact matches (`=N`),
  `other` fallback, `{param}` substitution, and `#` shorthand.
- `ResolvedParam` now exposes a `params` field with parsed parameters

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

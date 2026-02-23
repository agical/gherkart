# Changelog

## 0.1.3

### Improvements

- Broaden package description to include Dart and Flutter
- Add automated pub.dev publishing from CI via OIDC token exchange
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

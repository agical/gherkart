/// Gherkart - A Gherkin-based BDD testing library for Dart and Flutter.
///
/// Gherkart provides a flexible, pluggable BDD test runner that works with
/// any test framework. It parses Gherkin feature files and executes tests
/// using a registry of step definitions.
///
/// ## Quick Start
///
/// 1. Define your step registry:
/// ```dart
/// final registry = StepRegistry<PatrolTester>()
///   ..given('I am on the login page', ($, params) async {
///     await $.pumpWidgetAndSettle(const LoginPage());
///   })
///   ..when('I enter {email} and {password}', ($, params) async {
///     await $(#emailField).enterText(params[0]);
///     await $(#passwordField).enterText(params[1]);
///   })
///   ..then('I should see the dashboard', ($, params) async {
///     expect($(#dashboard), findsOneWidget);
///   });
/// ```
///
/// 2. Create a test adapter for your framework:
/// ```dart
/// final adapter = TestAdapter<PatrolTester>(
///   testFunction: (name, {tags, skip = false, required callback}) {
///     patrolWidgetTest(name, tags: tags, skip: skip, ($) => callback($));
///   },
///   group: group,
///   setUpAll: setUpAll,
///   tearDownAll: tearDownAll,
///   fail: fail,
/// );
/// ```
///
/// 3. Run your tests:
/// ```dart
/// void main() {
///   runBddTests<PatrolTester>(
///     rootPaths: ['test/features'],
///     registry: registry,
///     adapter: adapter,
///     source: FileSystemSource(),
///   );
/// }
/// ```
///
/// ## Feature Sources
///
/// Gherkart supports multiple sources for feature files:
///
/// - [FileSystemSource] - reads from disk (requires dart:io)
/// - [AssetSource] - reads from in-memory map or loader function
///
/// Use `AssetSource` for web platform or bundled assets.
///
/// ## Scheme Resolution
///
/// The [SchemeResolver] allows transforming parameter values before
/// passing them to step functions. Common use cases:
///
/// - Translation keys: `{t:loginTitle}` -> actual translated string
/// - Test data: `{d:validEmail}` -> test data value
///
/// See [createArbTranslationHandler] for i18n support.
library;

// Core types
export 'src/bdd_output.dart' show BddOutput;
export 'src/bdd_reporter.dart'
    show
        BddReporter,
        BufferedReporter,
        BufferedResults,
        CompositeReporter,
        ContinuousReporter,
        FeatureResult,
        FeatureStatus,
        FileReporter,
        PrintingReporter,
        ReportFeature,
        ReportMode,
        ReportScenario,
        ReportStep,
        ReporterConfig,
        ReporterEvent,
        ScenarioResult,
        ScenarioStatus,
        StepResult,
        StepStatus,
        SummaryReporter,
        TestSummary;
export 'src/bdd_test_runner.dart'
    show
        BddHooks,
        BddTestRunner,
        FailFunction,
        GroupFunction,
        SetUpAllFunction,
        TearDownAllFunction,
        TestAdapter,
        TestFunction,
        runBddTests;
export 'src/feature_parser.dart'
    show
        Background,
        DataTable,
        DocString,
        ExampleTable,
        Feature,
        Scenario,
        ScenarioOutline,
        SourceLocation,
        Step,
        StepKeyword,
        discoverFeatureFiles,
        parseFeature,
        parseFeatureFile;
export 'src/feature_source.dart'
    show AssetSource, FeatureSource, FeatureSourceException;
export 'src/feature_test_factory.dart'
    show
        FeatureTestFactory,
        MissingStepsException,
        TestCase,
        TestGroup,
        TestPlan,
        TestStructure;
export 'src/line_mapper.dart' show LineMapper, StringLineMapper;
export 'src/markdown_file_reporter.dart' show MarkdownFileReporter;
export 'src/scheme_resolver.dart'
    show ResolvedParam, SchemeHandler, SchemeResolver;
export 'src/step_registry.dart'
    show StepContext, StepFunction, StepMatch, StepRegistry;
export 'src/translation_scheme.dart'
    show
        createArbTranslationHandler,
        createKeyMappingHandler,
        createMapTranslationHandler,
        createTranslationHandler;

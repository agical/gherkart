# Gherkart justfile
# Run `just --list` to see all available commands

# Default recipe - show available commands
default:
    @just --list

# === Testing ===

# Run all tests
[group('test')]
test-all:
    dart test test/ example/

# Run unit tests
[group('test')]
test-unit:
    dart test test/unit/

# Run all example tests
[group('test')]
test-example:
    dart test example/

# Run basic demo example (scenarios, background, tags, outlines)
[group('test')]
test-example-demo:
    dart test example/demo_test.dart

# Run data tables & doc strings example
[group('test')]
test-example-data:
    dart test example/data_tables_test.dart

# Run scheme resolution example
[group('test')]
test-example-scheme:
    dart test example/scheme_test.dart

# Run reporter & lifecycle hooks example
[group('test')]
test-example-reporter:
    dart test example/reporter_test.dart

# Run tests with coverage
[group('test')]
test-coverage:
    dart test --coverage=coverage test/unit/
    @echo "Coverage report in coverage/lcov.info"

# === Code Quality ===

# Run static analysis
[group('quality')]
analyze:
    dart analyze --fatal-infos

# Format code
[group('quality')]
format:
    dart format --page-width=120 lib test example

# Check formatting without modifying
[group('quality')]
format-check:
    dart format --page-width=120 --set-exit-if-changed lib test example

# Fix auto-fixable issues
[group('quality')]
fix:
    dart fix --apply

# === Publishing ===

# Dry-run publish to check for issues
[group('publish')]
publish-dry-run:
    dart pub publish --dry-run

# Publish to pub.dev (requires authentication)
[group('publish')]
publish:
    dart pub publish

# === Development ===

# Get dependencies
[group('dev')]
get:
    dart pub get

# Upgrade dependencies
[group('dev')]
upgrade:
    dart pub upgrade

# Clean build artifacts
[group('dev')]
clean:
    rm -rf .dart_tool build coverage

# Run all checks (good before committing)
[group('dev')]
check: format-check analyze test-all
    @echo "✅ All checks passed"

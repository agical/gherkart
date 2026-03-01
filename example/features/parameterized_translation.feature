Feature: Parameterized Translations
  Demonstrates translation keys with parameters that get substituted
  into the resolved string, using the "{t:key(param: value)}" syntax.

  Scenario: Single parameter substitution
    Then "{t:welcome(name: 'Alice')}" is "Welcome, Alice!"

  Scenario: Multiple parameter substitution
    Then "{t:greeting(name: 'Alice', time: 'morning')}" is "Good morning, Alice!"

  Scenario: Plain translation still works
    Then "{t:hello}" is "Hello, World!"

  Scenario: Mixed parameters and plain translations
    Then "{t:hello}" is "Hello, World!"
    And "{t:welcome(name: 'Bob')}" is "Welcome, Bob!"

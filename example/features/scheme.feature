Feature: Scheme Resolution Demo
  Demonstrates parameter scheme resolution with translation keys.

  Scenario: Verify translated text
    Then "{t:hello}" is "Hello, World!"
    And "{t:goodbye}" is "See you later!"

  Scenario: Literal values pass through
    Then "plain text" is "plain text"

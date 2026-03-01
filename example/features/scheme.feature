Feature: Scheme Resolution Demo
  Demonstrates parameter scheme resolution with translation keys.

  Scenario: Verify translated text
    Then "{t:hello}" is "Hello, World!"
    And "{t:goodbye}" is "See you later!"

  Scenario: Literal values pass through
    Then "plain text" is "plain text"

  Scenario: Custom scheme handler
    Then "{x:hello(p1: 1, p2: 'World')}" is "hello 1 World"

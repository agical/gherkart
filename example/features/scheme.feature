Feature: Scheme Resolution Demo
  Demonstrates parameter scheme resolution with translation keys.

  Scenario: Verify translated text
    Then I see the text "{t:hello}"
    And I see the text "{t:goodbye}"

  Scenario: Literal values pass through
    Then I see the text "plain text"

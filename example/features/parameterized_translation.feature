Feature: Parameterized Translations
  Demonstrates translation keys with parameters that get substituted
  into the resolved string, using the "{t:key(param: value)}" syntax.

  Scenario: Single parameter substitution
    Then I see the text "{t:shotLabel(shots: 1)}"
    And I see the text "{t:shotLabel(shots: 2)}"

  Scenario: Multiple parameter substitution
    Then I see the text "{t:greeting(name: 'Alice', time: 'morning')}"

  Scenario: Plain translation still works
    Then I see the text "{t:hello}"

  Scenario: Mixed parameters and plain translations
    Then I see the text "{t:hello}"
    And I see the text "{t:shotLabel(shots: 3)}"

Feature: Plural Translations
  Demonstrates ICU MessageFormat plural syntax in translation values.
  The handler selects the correct plural form based on a numeric parameter.

  Scenario: Zero items use the =0 form
    Then "{t:shotLabel(count: 0)}" is "no shots"

  Scenario: One item uses the =1 form
    Then "{t:shotLabel(count: 1)}" is "1 shot"

  Scenario: Multiple items use the other form
    Then "{t:shotLabel(count: 5)}" is "5 shots"

  Scenario: Hash placeholder is replaced with the count
    Then "{t:itemCount(count: 42)}" is "42 items"

  Scenario: Plural works alongside regular placeholders
    Then "{t:userShots(name: 'Alice', count: 2)}" is "Alice scored 2 shots"

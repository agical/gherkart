Feature: Rules and Keywords Demo
  Demonstrates business rules (Rule:), Example: synonyms, and bullet (*) steps.

  Rule: Addition with zero preserves value
    Example: Adding zero keeps number unchanged
      * I have the number 42
      * I add 0
      Then the result is 42

  Rule: Positive addition with background
    Background:
      * I have the number 10

    Scenario: Add positive offset
      * I add 5
      Then the result is 15

Feature: Background Demo
  Demonstrates that Background steps run before each scenario.

  Background:
    Given I have the number 10

  Scenario: Add with background
    When I add 5
    Then the result is 15

  Scenario: Different addition with same background
    When I add 20
    Then the result is 30

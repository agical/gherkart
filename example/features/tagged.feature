@smoke
Feature: Tagged Feature Demo
  Demonstrates tag propagation from feature to scenarios.

  Scenario: Regular scenario inherits feature tags
    Given I have the number 10
    When I add 5
    Then the result is 15

  @slow
  Scenario: Scenario with additional tag
    Given I have the number 20
    When I add 10
    Then the result is 30

  @wip
  Scenario: WIP scenario should be skippable
    Given I have the number 100
    When I add 50
    Then the result is 150

Feature: Data Tables Demo
  Demonstrates step-attached data tables.

  Scenario: Add items from a table
    Given I have an empty inventory
    When I add items:
      | name    | quantity |
      | Apples  | 5        |
      | Oranges | 3        |
      | Bananas | 2        |
    Then the total quantity is 10

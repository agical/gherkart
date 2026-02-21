Feature: Scenario Outline Demo
  Demonstrates Scenario Outline with Examples tables.
  Each example row becomes a separate test case.

  Scenario Outline: Addition with examples
    Given I have the number <a>
    When I add <b>
    Then the result is <sum>

    Examples: Small numbers
      | a  | b  | sum |
      | 1  | 2  | 3   |
      | 5  | 3  | 8   |

    Examples: Larger numbers
      | a   | b   | sum |
      | 100 | 200 | 300 |
      | 999 | 1   | 1000|

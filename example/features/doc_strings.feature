Feature: Doc Strings Demo
  Demonstrates multi-line doc string attachments on steps.

  Scenario: Parse JSON configuration using triple double quotes
    Given the configuration:
      """json
      {
        "theme": "dark",
        "fontSize": 14
      }
      """
    Then the theme is "dark"
    And the font size is 14

  Scenario: Parse JSON configuration using triple backticks
    Given the configuration:
      ```json
      {
        "theme": "light",
        "fontSize": 16
      }
      ```
    Then the theme is "light"
    And the font size is 16

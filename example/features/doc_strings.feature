Feature: Doc Strings Demo
  Demonstrates multi-line doc string attachments on steps.

  Scenario: Parse JSON configuration
    Given the configuration:
      """json
      {
        "theme": "dark",
        "fontSize": 14
      }
      """
    Then the theme is "dark"
    And the font size is 14

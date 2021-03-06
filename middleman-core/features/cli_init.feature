Feature: Middleman CLI

  Scenario: Create a new project
    Given I run `middleman init MY_PROJECT`
    Then the exit status should be 0
    When I cd to "MY_PROJECT"
    Then the following files should exist:
      | Gemfile                                       |
      | .gitignore                                    |
      | config.rb                                     |
      | source/index.html.erb                         |
      | source/images/background.png                  |
      | source/images/middleman.png                   |
      | source/layouts/layout.erb                     |
      | source/javascripts/all.js                     |
      | source/stylesheets/all.css                    |
      | source/stylesheets/normalize.css              |

  Scenario: Create a new project in the current directory
    Given a directory named "MY_PROJECT"
    When I cd to "MY_PROJECT"
    And I run `middleman init`
    Then the exit status should be 0
    And the following files should exist:
      | Gemfile                                       |
      | config.rb                                     |
      | source/index.html.erb                         |

  Scenario: Create a new project (alias i)
    When I run `middleman i MY_PROJECT`
    Then a directory named "MY_PROJECT" should exist

  Scenario: Create a new project (alias new)
    When I run `middleman new MY_PROJECT`
    Then a directory named "MY_PROJECT" should exist

  Scenario: Create a new project (alias n)
    When I run `middleman n MY_PROJECT`
    Then a directory named "MY_PROJECT" should exist

  # Scenario: Create a new HTML5 project
  #   When I run `middleman init MY_PROJECT --template=html5`
  #   Then a directory named "MY_PROJECT" should exist
  #   When I cd to "MY_PROJECT"
  #   Then the following files should exist:
  #     | config.rb                                     |
  #     | Gemfile                                       |
  #   Then the following files should not exist:
  #     | config.ru                                     |
  #   And the file "config.rb" should contain "set :js_dir, 'js'"
  #   Then a directory named "source" should exist
  #   When I cd to "source"
  #   Then the following files should exist:
  #     | index.html.erb                                |
  #     | layouts/layout.erb                            |
  #     | humans.txt                                    |
  #     | js/main.js                                    |

Feature: HTTP call for usage summary

Scenario:
  Given url usageTrackerUrl
  And path '/api/usage/summary'
  When method get
  Then status 200

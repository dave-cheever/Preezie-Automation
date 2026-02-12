@ignore
Feature: Record usage to tracker service

Scenario:
  * def usageTrackerUrl = karate.properties['usage.tracker.url'] || 'http://localhost:8080'

  Given url usageTrackerUrl
  And path '/api/usage/record'
  And request __arg.usageData
  When method post
  Then status 200

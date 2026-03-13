Feature: obtain CMS token

Scenario: retrieve token
  # Replace URL/fields with your auth server's values
  * url 'https://YOUR_AUTH_SERVER/oauth2/token'
  * form field grant_type = 'client_credentials'
  * form field client_id = 'YOUR_CLIENT_ID'
  * form field client_secret = 'YOUR_CLIENT_SECRET'
  When method post
  Then status 200
  * def token = response.access_token || response.token
  * match token != null
  * return { token: token }
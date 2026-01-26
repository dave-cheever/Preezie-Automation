Feature: Firebase refresh token -> ID token

Scenario: Exchange refresh token for a fresh ID token
  # Secure Token API
  Given url 'https://securetoken.googleapis.com/v1/token'
  And param key = firebaseApiKey
  And header Content-Type = 'application/x-www-form-urlencoded'
  And form field grant_type = 'refresh_token'
  And form field refresh_token = firebaseRefreshToken
  When method post
  Then status 200

  * def idToken = response.id_token
  * def refreshToken = response.refresh_token
  * def expiresIn = response.expires_in

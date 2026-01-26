Feature: Firebase email/password login

Scenario: Login and obtain tokens
  Given url 'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword'
  And param key = firebaseApiKey
  And header Content-Type = 'application/json'
  And request
    """
    {
      "email": "#(firebaseEmail)",
      "password": "#(firebasePassword)",
      "returnSecureToken": true
    }
    """
  When method post
  Then status 200

  * def idToken = response.idToken
  * def refreshToken = response.refreshToken
  * def expiresIn = response.expiresIn

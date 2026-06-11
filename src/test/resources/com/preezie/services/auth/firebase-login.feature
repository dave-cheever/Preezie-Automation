Feature: Firebase email/password login

Scenario: Login and obtain tokens
  * def apiKey = __arg && __arg.firebaseApiKey ? __arg.firebaseApiKey : karate.get('firebaseApiKey')
  * def email = __arg && __arg.firebaseEmail ? __arg.firebaseEmail : karate.get('firebaseEmail')
  * def password = __arg && __arg.firebasePassword ? __arg.firebasePassword : karate.get('firebasePassword')

  * if (!apiKey || ('' + apiKey).trim() == '') karate.fail('Missing firebaseApiKey. Set FIREBASE_API_KEY or pass firebaseApiKey argument.')
  * if (!email || ('' + email).trim() == '') karate.fail('Missing firebaseEmail. Set FIREBASE_EMAIL or pass firebaseEmail argument.')
  * if (!password || ('' + password).trim() == '') karate.fail('Missing firebasePassword. Set FIREBASE_PASSWORD or pass firebasePassword argument.')

  Given url 'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=' + apiKey
#  And param key = apiKey
  And header Content-Type = 'application/json'
  And request
    """
    {
      "email": "#(email)",
      "password": "#(password)",
      "returnSecureToken": true
    }
    """
  When method post
  Then status 200

  * def idToken = response.idToken
  * def refreshToken = response.refreshToken
  * def expiresIn = response.expiresIn

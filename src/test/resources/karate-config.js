function fn() {
  var config = {};

  /**********************************************************
   * Load .env from project root (SAFE fallback only)
   **********************************************************/
  var dotenv = {};
  try {
    var Paths = Java.type('java.nio.file.Paths');
    var Files = Java.type('java.nio.file.Files');
    var StandardCharsets = Java.type('java.nio.charset.StandardCharsets');

    var root = java.lang.System.getProperty('user.dir');
    var envPath = Paths.get(root, '.env');

    if (Files.exists(envPath)) {
      var lines = Files.readAllLines(envPath, StandardCharsets.UTF_8);
      for (var i = 0; i < lines.size(); i++) {
        var line = ('' + lines.get(i)).trim();
        if (!line || line.startsWith('#')) continue;

        var idx = line.indexOf('=');
        if (idx < 1) continue;

        var key = line.substring(0, idx).trim();
        var val = line.substring(idx + 1).trim();

        if (
          (val.startsWith('"') && val.endsWith('"')) ||
          (val.startsWith("'") && val.endsWith("'"))
        ) {
          val = val.substring(1, val.length - 1);
        }

        dotenv[key] = val;
      }
      karate.log('.env loaded from project root');
    }
  } catch (e) {
    karate.log('WARNING: .env not loaded:', e);
  }

  /**********************************************************
   * Usage Tracker Configuration
   **********************************************************/
  config.usageTrackerUrl =
    karate.properties['usage.tracker.url'] ||
    java.lang.System.getProperty('usage.tracker.url') ||
    java.lang.System.getenv('USAGE_TRACKER_URL') ||
    dotenv['USAGE_TRACKER_URL'] ||
    'http://localhost:8080';

  /**********************************************************
   * LLM (OpenAI) Configuration (UNCHANGED BEHAVIOR)
   **********************************************************/

  config.llmBaseUrl =
    karate.properties['llmBaseUrl'] ||
    java.lang.System.getProperty('llmBaseUrl') ||
    dotenv['llmBaseUrl'] ||
    'https://api.openai.com';

  var llmApiKey =
    karate.properties['llmApiKey'] ||
    karate.properties['OPENAI_API_KEY'] ||
    java.lang.System.getProperty('OPENAI_API_KEY') ||
    java.lang.System.getenv('OPENAI_API_KEY') ||
    dotenv['OPENAI_API_KEY'];

  if (!llmApiKey || ('' + llmApiKey).trim() === '') {
    karate.fail(
      'Missing LLM API key. Set env OPENAI_API_KEY or pass -DllmApiKey=... / -DOPENAI_API_KEY=...'
    );
  }

  config.llmApiKey = llmApiKey;

  /**********************************************************
   * Firebase / CMS Authentication Configuration
   **********************************************************/

  config.firebaseApiKey =
    karate.properties['firebaseApiKey'] ||
    java.lang.System.getProperty('firebaseApiKey') ||
    java.lang.System.getenv('FIREBASE_API_KEY') ||
    dotenv['FIREBASE_API_KEY'];

  config.firebaseEmail =
    karate.properties['firebaseEmail'] ||
    java.lang.System.getProperty('firebaseEmail') ||
    java.lang.System.getenv('FIREBASE_EMAIL') ||
    dotenv['FIREBASE_EMAIL'];

  config.firebasePassword =
    karate.properties['firebasePassword'] ||
    java.lang.System.getProperty('firebasePassword') ||
    java.lang.System.getenv('FIREBASE_PASSWORD') ||
    dotenv['FIREBASE_PASSWORD'];

  config.firebaseRefreshToken =
    karate.properties['firebaseRefreshToken'] ||
    java.lang.System.getProperty('firebaseRefreshToken') ||
    java.lang.System.getenv('FIREBASE_REFRESH_TOKEN') ||
    dotenv['FIREBASE_REFRESH_TOKEN'];

  config.cmsBaseUrl =
    karate.properties['cmsBaseUrl'] ||
    java.lang.System.getProperty('cmsBaseUrl') ||
    java.lang.System.getenv('CMS_BASE_URL') ||
    dotenv['CMS_BASE_URL'];

  /**
   * AUTH FLOW PRIORITY (UNCHANGED)
   * 1) Email + password login
   * 2) Refresh token exchange
   * 3) No CMS auth
   */

  if (config.firebaseApiKey && config.firebaseEmail && config.firebasePassword) {
    var loginResult = karate.callSingle(
      'classpath:com/preezie/services/auth/firebase-login.feature',
      {
        firebaseApiKey: config.firebaseApiKey,
        firebaseEmail: config.firebaseEmail,
        firebasePassword: config.firebasePassword
      }
    );

    config.cmsIdToken = loginResult.idToken;
    config.firebaseRefreshToken = loginResult.refreshToken;

    karate.log(
      'Firebase login successful (expiresIn:',
      loginResult.expiresIn,
      'seconds)'
    );

  } else if (config.firebaseApiKey && config.firebaseRefreshToken) {
    var tokenResult = karate.callSingle(
      'classpath:com/preezie/auth/firebase-refresh.feature',
      {
        firebaseApiKey: config.firebaseApiKey,
        firebaseRefreshToken: config.firebaseRefreshToken
      }
    );

    config.cmsIdToken = tokenResult.idToken;

    karate.log(
      'Firebase ID token refreshed (expiresIn:',
      tokenResult.expiresIn,
      'seconds)'
    );

    if (
      tokenResult.refreshToken &&
      tokenResult.refreshToken !== config.firebaseRefreshToken
    ) {
      karate.log(
        'NOTE: Firebase refresh token rotated. Update FIREBASE_REFRESH_TOKEN.'
      );
      config.firebaseRefreshToken = tokenResult.refreshToken;
    }

  } else {
    karate.log(
      'Firebase auth not configured. CMS-authenticated tests will be skipped or fail if executed.'
    );
  }

  var usageModule = read('classpath:com/preezie/js/usage-report.js');
  var usageReporter = usageModule.createUsageReporter
    ? usageModule.createUsageReporter()
    : usageModule();

  karate.configure('afterScenario', function () {
    try {
      var u = karate.get('llmUsage');
      if (u) {
        usageReporter.record(u);
        karate.log('LLM usage (request):', u);
      }
    } catch (e) {
      karate.log('WARNING: failed to read/log llmUsage:', e);
    }
  });

  karate.configure('afterFeature', function () {
    try {
      var summary = usageReporter.summary();
      karate.log('LLM usage totals (feature):', summary && summary.totals);
      karate.log('LLM usage averages_per_run (feature):', summary && summary.averages_per_run);
      karate.log('LLM usage runs (feature):', summary && summary.runs);

      // Call the usage summary feature
      try {
        karate.call('classpath:com/preezie/llm/helpers/get-usage-summary.feature');
      } catch (e) {
        karate.log('Warning: Could not fetch usage summary:', e.message || e);
      }
    } catch (e) {
      karate.log('WARNING: failed to summarize/log LLM usage:', e);
    }
  });


  config.cmsIdToken = config.cmsIdToken || null;

  return config;
}

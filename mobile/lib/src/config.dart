/// Build-time configuration, passed with --dart-define.
///
///   flutter build apk --dart-define=API_BASE_URL=https://your-app.vercel.app \
///                     --dart-define=APP_KEY=your-shared-app-key
///
/// Both can also be changed at runtime in Settings.
const String kDefaultApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://bobbymedia-app-builder.vercel.app',
);

/// Shared secret sent as the X-App-Key header. Empty unless provided at build time.
const String kDefaultAppKey = String.fromEnvironment('APP_KEY');

const int kMinPromptLength = 8;
const int kMaxPromptLength = 4000;
const int kMaxHistoryItems = 50;
const Duration kRequestTimeout = Duration(seconds: 75);

const String kDisclaimer =
    'App Builder writes Flutter source code for you. The code is not compiled '
    'or tested and is not an installable app by itself. Review it before use.';

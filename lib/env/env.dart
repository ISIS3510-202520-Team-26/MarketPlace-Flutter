class Env {
static const String baseUrl = String.fromEnvironment(
'BASE_URL',
defaultValue: 'http://10.0.2.2:8000/v1', // Emulador Android
);
static const bool enableLogs = bool.fromEnvironment('ENABLE_LOGS', defaultValue: true);
}
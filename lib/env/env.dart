class Env {
static const String baseUrl = String.fromEnvironment(
'BASE_URL',
defaultValue: 'http://localhost:8000/v1', 
);
static const bool enableLogs = bool.fromEnvironment('ENABLE_LOGS', defaultValue: true);
}
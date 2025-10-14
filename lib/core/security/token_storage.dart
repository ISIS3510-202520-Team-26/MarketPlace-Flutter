import 'package:flutter_secure_storage/flutter_secure_storage.dart';


class TokenStorage {
TokenStorage._();
static final TokenStorage instance = TokenStorage._();
final _storage = const FlutterSecureStorage();


Future<void> init() async {}
Future<void> saveTokens(String access, String refresh) async {
await _storage.write(key: 'access', value: access);
await _storage.write(key: 'refresh', value: refresh);
}
Future<String?> readAccessToken() => _storage.read(key: 'access');
Future<String?> readRefreshToken() => _storage.read(key: 'refresh');
Future<void> clear() async { await _storage.deleteAll(); }
}
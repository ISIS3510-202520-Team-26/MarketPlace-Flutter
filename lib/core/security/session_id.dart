import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class SessionId {
  SessionId._();
  static final SessionId instance = SessionId._();

  String? _id;

  Future<void> ensure() async {
    final sp = await SharedPreferences.getInstance();
    _id = sp.getString('session_id');
    if (_id == null) {
      _id = const Uuid().v4();
      await sp.setString('session_id', _id!);
    }
  }

  String get value => _id ?? 'unknown';
}

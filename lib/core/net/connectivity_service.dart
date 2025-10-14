import 'package:connectivity_plus/connectivity_plus.dart';


class ConnectivityService {
ConnectivityService._();
static final instance = ConnectivityService._();
Future<bool> get isOnline async {
final res = await Connectivity().checkConnectivity();
return res != ConnectivityResult.none;
}
}
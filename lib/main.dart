import 'package:flutter/material.dart';
import 'bootstrap.dart';
import 'app.dart';


void main() async {
WidgetsFlutterBinding.ensureInitialized();
await Bootstrap.init();
runApp(const MarketApp());
}
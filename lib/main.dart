import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'bootstrap.dart';
import 'app.dart';


void main() async {
WidgetsFlutterBinding.ensureInitialized();
// Desactivar el banner de overflow amarillo/negro en debug
debugPaintSizeEnabled = false;
await Bootstrap.init();
runApp(const MarketApp());
}
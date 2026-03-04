import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'bluetooth/ble_manager.dart';
import 'screen/home_screen.dart';

void main(){
  runApp(
    ChangeNotifierProvider(
      create: (_) {
        final ble = BleManager(); // wraps app, all screens can access BleManager
        ble.startScan(); // Auto scan on launch
        return ble;
      },
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Endosync Prototype',
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
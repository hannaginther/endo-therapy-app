import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'bluetooth/ble_manager.dart';
import 'screens/home_screen.dart';

void main(){
  runApp(
    ChangeNotifierProvider(
      create: (_) => BleManager(), // wraps app, all screens can access BleManager
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Endosync Prototype',
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}
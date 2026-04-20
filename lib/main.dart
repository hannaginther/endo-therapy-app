import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'bluetooth/ble_manager.dart';
import 'providers/session_history_provider.dart';
import 'debug/fake_ble_manager.dart';
import 'screens/home_screen.dart';
import 'bluetooth/ble_constants.dart';
import 'utils/event_log.dart';

void main(){
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => kDebugSkipBle ? FakeBleManager() : BleManager()), // wraps app, all screens can access BleManager
        ChangeNotifierProvider(create: (_) => SessionHistoryProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SessionHistoryProvider>().init();
      EventLog.instance.log(
        'App launched. kDebugSkipBle=$kDebugSkipBle. ShortTimers=${BleSessionLimits.kDebugShortTimers}',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Endosync Prototype',
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}
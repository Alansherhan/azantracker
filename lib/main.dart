import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/prayer_time_provider.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AzanTrackerApp());
}

class AzanTrackerApp extends StatelessWidget {
  const AzanTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PrayerTimeProvider()..initialize(),
      child: MaterialApp(
        title: 'Azan Tracker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: Brightness.light,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

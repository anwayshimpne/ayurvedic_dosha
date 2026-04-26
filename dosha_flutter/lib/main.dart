import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/dashboard.dart';
import 'services/esp8266_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Esp8266Service()),
      ],
      child: const AyurvedaApp(),
    ),
  );
}

class AyurvedaApp extends StatelessWidget {
  const AyurvedaApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sukshma Buddhi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D4AA),
          secondary: Color(0xFFFF6B35),
          tertiary: Color(0xFF7B61FF),
          surface: Color(0xFF141928),
        ),
        cardColor: const Color(0xFF141928),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0E1A),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

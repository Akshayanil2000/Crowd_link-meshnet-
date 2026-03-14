import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:crowd_link/firebase_options.dart';
import 'package:crowd_link/screens/home_screen.dart';
import 'package:crowd_link/screens/settings_screen.dart';
import 'package:crowd_link/services/auth_service.dart';
import 'package:crowd_link/providers/mesh_provider.dart';
import 'package:crowd_link/providers/activity_provider.dart';
import 'package:crowd_link/services/mesh_service.dart';
import 'package:crowd_link/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('⚠️  Firebase init failed: $e');
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MeshProvider()),
        ChangeNotifierProvider(create: (_) => ActivityProvider(MeshService())),
      ],
      child: const CrowdLinkApp(),
    ),
  );
}

class CrowdLinkApp extends StatelessWidget {
  const CrowdLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CrowdLink',
      navigatorKey: NotificationService.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF00FC82),
        scaffoldBackgroundColor: Colors.black,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FC82),
          secondary: Color(0xFF00FC82),
          surface: Color(0xFF141414),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF141414),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

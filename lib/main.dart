import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'models/user_profile.dart';
import 'services/gemini_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyB_RbxAQcdbpD_DpMVg3N1ZvYVtPxt5yzU',
        authDomain: 'food-tracker-79f10.firebaseapp.com',
        projectId: 'food-tracker-79f10',
        storageBucket: 'food-tracker-79f10.firebasestorage.app',
        messagingSenderId: '563142500451',
        appId: '1:563142500451:web:d41b5c3a8dc3eed6e0d856',
      ),
    );
    await initializeDateFormatting('uk');
    await dotenv.load(fileName: '.env');

    runApp(const FoodTrackerApp());
  } catch (error, stackTrace) {
    debugPrint('Firebase init error: $error');
    debugPrintStack(stackTrace: stackTrace);
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Помилка ініціалізації Firebase:\n$error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FoodTrackerApp extends StatelessWidget {
  const FoodTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final storageService = StorageService();
    final geminiService = GeminiService();

    return MaterialApp(
      title: 'FoodTracker',
      locale: const Locale('uk'),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F1115),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF64B5F6),
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF171A21),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
      home: _AuthGate(
        storageService: storageService,
        geminiService: geminiService,
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate({
    required this.storageService,
    required this.geminiService,
  });

  final StorageService storageService;
  final GeminiService geminiService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authSnapshot.data == null) {
          return const LoginScreen();
        }

        return FutureBuilder<UserProfile?>(
          future: storageService.getUserProfile(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final profile = profileSnapshot.data;
            if (profile == null) {
              return OnboardingScreen(storageService: storageService);
            }
            return HomeScreen(
              storageService: storageService,
              geminiService: geminiService,
              profile: profile,
            );
          },
        );
      },
    );
  }
}

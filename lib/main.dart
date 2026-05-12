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
    await dotenv.load(fileName: '.env');
    
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: dotenv.env['FIREBASE_API_KEY']!,
        authDomain: dotenv.env['FIREBASE_AUTH_DOMAIN'],
        projectId: dotenv.env['FIREBASE_PROJECT_ID']!,
        storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'],
        messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID']!,
        appId: dotenv.env['FIREBASE_APP_ID']!,
      ),
    );
    await initializeDateFormatting('uk');

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

// ─── Design Tokens ────────────────────────────────────────────────
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF141420);
  static const Color surfaceVariant = Color(0xFF1C1C2E);
  static const Color cardBorder = Color(0x0FFFFFFF); // white 6%

  // Accent gradient endpoints
  static const Color primaryStart = Color(0xFF7C4DFF);
  static const Color primaryEnd = Color(0xFF448AFF);
  static const Color accent = Color(0xFF00E5FF);

  // Macro-specific colours
  static const Color calories = Color(0xFFFF6D00);
  static const Color protein = Color(0xFF00E676);
  static const Color carbs = Color(0xFFFFD600);
  static const Color fats = Color(0xFFFF5252);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryStart, primaryEnd],
  );
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
      theme: _buildTheme(),
      home: _AuthGate(
        storageService: storageService,
        geminiService: geminiService,
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryStart,
        brightness: Brightness.dark,
        surface: AppColors.surface,
      ),

      // ── App Bar ─────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: Colors.white70),
      ),

      // ── Cards ───────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.cardBorder, width: 1),
        ),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),

      // ── Filled Buttons ──────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // ── Outlined Buttons ────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(color: Colors.white.withOpacity(0.12)),
          foregroundColor: Colors.white70,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // ── Text Buttons ────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Input Fields ────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.primaryStart, width: 1.5),
        ),
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 14),
        hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
      ),

      // ── Dropdown ────────────────────────────────────────────
      dropdownMenuTheme: const DropdownMenuThemeData(
        textStyle: TextStyle(color: Colors.white, fontSize: 15),
      ),

      // ── Expansion Tile ──────────────────────────────────────
      expansionTileTheme: const ExpansionTileThemeData(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        collapsedIconColor: Colors.white54,
        iconColor: AppColors.accent,
        shape: Border(),
        collapsedShape: Border(),
      ),

      // ── Snackbar ────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceVariant,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Checkbox ────────────────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryStart;
          }
          return Colors.white12;
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // ── Divider ─────────────────────────────────────────────
      dividerTheme: const DividerThemeData(color: Colors.white10, thickness: 1),

      // ── Text Theme ──────────────────────────────────────────
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.3,
        ),
        headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.2,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleSmall: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.white70,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: Colors.white54,
        ),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
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

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/auth_storage.dart';
import 'core/firebase_config.dart';
import 'services/supabase_service.dart';
import 'screens/restaurant_admin_login_screen.dart';

Future<void> _ensureSupabaseSession() async{
  final client = Supabase.instance.client;
  final current = client.auth.currentSession;
  if (current != null) return;

  const fallbackEmail = String.fromEnvironment('SUPABASE_AUTH_EMAIL');
  const fallbackPassword = String.fromEnvironment('SUPABASE_AUTH_PASSWORD');
  
  try {
    await client.auth.signInAnonymously();
    return;
  } on AuthException catch (e) {
    if (e.message.contains('anonymous_provider_disabled') ||
        e.message.toLowerCase().contains('anonymous sign-ins are disabled')) {
      if (fallbackEmail.isNotEmpty && fallbackPassword.isNotEmpty) {
        try {
          await client.auth.signInWithPassword(
            email: fallbackEmail,
            password: fallbackPassword,
          );
          return;
        } catch (fallbackError) {
          debugPrint('Supabase fallback sign-in failed: $fallbackError');
        }
      }
      debugPrint(
        'Anonymous auth is disabled. Enable it in Supabase Auth providers, '
        'or run with --dart-define=SUPABASE_AUTH_EMAIL=... '
        '--dart-define=SUPABASE_AUTH_PASSWORD=...',
      );
      return;
    }
    debugPrint('Supabase sign-in failed: $e');
  } catch (e) {
    debugPrint('Supabase sign-in failed: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final supabaseUrl = dotenv.env['SUPABASE_URL']?.trim();
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']?.trim();
  final supabaseAppSecret = dotenv.env['SUPABASE_APP_SECRET']?.trim();

  if (supabaseUrl == null ||
      supabaseUrl.isEmpty ||
      supabaseAnonKey == null ||
      supabaseAnonKey.isEmpty) {
    throw Exception('Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env');
  }
  if (supabaseAppSecret == null || supabaseAppSecret.isEmpty) {
    throw Exception('Missing SUPABASE_APP_SECRET in .env');
  }

  if (kIsWeb) {
    await Firebase.initializeApp(options: FirebaseConfig.options);
  }
  await AuthStorage.init();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    headers: {
      'x-app-secret': supabaseAppSecret,
    },
  );
  await _ensureSupabaseSession();
  if (!AuthStorage.isFirebaseImageUrlMigrationDone) {
    try {
      await SupabaseService().migrateLegacyFirebaseImageUrlsOnce();
      AuthStorage.markFirebaseImageUrlMigrationDone();
    } catch (_) {}
  }
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mego Dashboard',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F111A),
      ),
      home: const RestaurantAdminLoginScreen(),
    );
  }
}

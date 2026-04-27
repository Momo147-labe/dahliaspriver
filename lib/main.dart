import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/database/database_helper.dart';
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/academic_year_provider.dart';
import 'screens/onboarding_page.dart';
import 'screens/auth/login_page.dart';
import 'screens/auth/license_activation_page.dart';
import 'screens/auth/license_blocked_page.dart';
import 'screens/auth/admin_registration_page.dart';
import 'screens/main_layout.dart';
import 'core/services/trial_service.dart';
import 'core/services/license_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // SQLite Desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialisation de la base de données
  await DatabaseHelper.instance.database;
  await DatabaseHelper.instance.ensureActiveAnneeCached();

  // Chargement des variables d'environnement
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Erreur lors du chargement du fichier .env: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => AcademicYearProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Guinée École',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              quill.FlutterQuillLocalizations.delegate,
            ],
            supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
            locale: const Locale('fr', 'FR'),
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _hasEcoles = false;
  bool _isLoggedIn = false;
  bool _isLicenseValidated = false;
  bool _isLicenseBlocked = false;
  bool _isTrialActive = false;
  bool _hasUser = false;

  @override
  void initState() {
    super.initState();
    LicenseService.licenseBlockedNotifier.addListener(_onLicenseStatusChanged);
    _initCheck();
  }

  @override
  void dispose() {
    LicenseService.licenseBlockedNotifier.removeListener(
      _onLicenseStatusChanged,
    );
    super.dispose();
  }

  void _onLicenseStatusChanged() {
    if (mounted) {
      setState(() {
        _isLicenseBlocked = LicenseService.licenseBlockedNotifier.value;
      });
    }
  }

  Future<void> _initCheck() async {
    try {
      final db = DatabaseHelper.instance;
      final prefs = await SharedPreferences.getInstance();

      // 1. Check license
      final licenseService = LicenseService();
      bool licenseValidated = await licenseService.checkLicenseLocally();
      bool licenseBlocked = await licenseService.isLicenseBlocked();
      bool isTrialActive = await TrialService.isTrialActive();

      // Trigger background sync if internet is available (don't await)
      if (licenseValidated) {
        licenseService.syncLicenseWithServer();
      }

      // 2. Check school
      final hasEcoles = await db.hasEcoles();

      // Nouveau : Si aucune école n'est enregistrée, on vide tout par sécurité
      if (!hasEcoles) {
        await licenseService.clearAllData();
        await prefs.clear();
        // Rafraîchir les flags locaux pour le setState
        licenseValidated = false;
        licenseBlocked = false;
        isTrialActive = false;
      }

      // 3. Check for at least one user (admin)
      bool hasUser = false;
      if (hasEcoles) {
        final database = await db.database;
        final users = await database.query('user', limit: 1);
        hasUser = users.isNotEmpty;
      }

      // 4. Check session
      final rememberMe = prefs.getBool('rememberMe') ?? false;
      final userId = prefs.getInt('userId');

      setState(() {
        _isLicenseValidated = licenseValidated;
        LicenseService.licenseBlockedNotifier.value = licenseBlocked;
        _isLicenseBlocked = licenseBlocked;
        _isTrialActive = isTrialActive;
        _hasEcoles = hasEcoles;
        _hasUser = hasUser;
        _isLoggedIn = rememberMe && userId != null;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error init check: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.backgroundDark
            : AppTheme.backgroundLight,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Initialisation Guinée Ecole...'),
            ],
          ),
        ),
      );
    }

    // Priorité 1 : Licence BLOQUÉE (Sécurité critique)
    if (_isLicenseBlocked) {
      return const LicenseBlockedPage();
    }

    // Priorité 2 : Onboarding (Ecole)
    if (!_hasEcoles) {
      return const OnboardingPage();
    }

    // Priorité 2 : Inscription Administrateur (Si école présente mais pas d'user)
    if (!_hasUser) {
      return const AdminRegistrationPage();
    }
    // Priorité 3 : Licence (Check license AND trial)
    if (!_isLicenseValidated && !_isTrialActive) {
      return const LicenseActivationPage();
    }

    // Priorité 4 : Session
    if (_isLoggedIn) {
      return const MainLayout();
    }

    return const LoginPage();
  }
}

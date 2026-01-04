import 'dart:io' show Platform;
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'ui/screens/menu_screen.dart';
import 'services/sound_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase asynchronously after the Flutter UI is up so that
  // long network delays on desktop don't block showing the window.
  Future<void> _initFirebaseWithTimeout() async {
    try {
      debugPrint('Firebase: init start');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 12));
      debugPrint('Firebase: initialized');

      if (FirebaseAuth.instance.currentUser == null) {
        try {
          debugPrint('Firebase: attempting anonymous sign-in');
          final cred = await FirebaseAuth.instance
              .signInAnonymously()
              .timeout(const Duration(seconds: 8));
          debugPrint('Firebase: anonymous sign-in success uid=${cred.user?.uid}');
        } catch (e, st) {
          debugPrint('Anonymous sign-in failed: $e');
          debugPrint(st.toString());
        }
      } else {
        debugPrint('Firebase: already signed-in uid=${FirebaseAuth.instance.currentUser?.uid}');
      }
    } catch (e, st) {
      debugPrint('Firebase init failed/timeout: $e');
      debugPrint(st.toString());
    }
  }

  // Global Flutter error handler so framework errors are logged.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };

  // Use runZonedGuarded to capture uncaught async errors across platforms.
  await runZonedGuarded(() async {
    // Initialize Firebase only on non-macOS platforms (skip macOS to speed startup).
    if (!Platform.isMacOS) {
      try {
        debugPrint('Firebase: initializing for platform ${DefaultFirebaseOptions.currentPlatform.projectId}');
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint('Firebase: initialized');

        // Ensure an auth user exists (anonymous sign-in) so CloudSaveService can use UID
        if (FirebaseAuth.instance.currentUser == null) {
          try {
            debugPrint('Firebase: attempting anonymous sign-in');
            final cred = await FirebaseAuth.instance.signInAnonymously();
            debugPrint('Firebase: anonymous sign-in success uid=${cred.user?.uid}');
          } catch (e, st) {
            debugPrint('Anonymous sign-in failed: $e');
            debugPrint(st.toString());
          }
        } else {
          debugPrint('Firebase: already signed-in uid=${FirebaseAuth.instance.currentUser?.uid}');
        }
      } catch (e, st) {
        debugPrint('Firebase initialization failed: $e');
        debugPrint(st.toString());
        // Continue even if Firebase fails so non-Firebase features still work
      }
    } else {
      debugPrint('Skipping Firebase initialization on macOS (per user request)');
    }

    // Configure edge-to-edge display for Android 15+ (SDK 35+)
    if (!kIsWeb && Platform.isAndroid) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        ),
      );
    }
    
    // Lock orientation to portrait mode for mobile devices
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    
    // Initialize AdMob only on Android and iOS (not macOS, Windows, Linux, or Web)
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await MobileAds.instance.initialize();
      } catch (e) {
        debugPrint('AdMob initialization failed: $e');
        // Continue app startup even if AdMob fails
      }
    }
    
    debugPrint('Startup: launching Flutter app');
    runApp(
      const ProviderScope(
        child: VendingMachineTycoonApp(),
      ),
    );
    debugPrint('Startup: runApp returned (Flutter engine should be running)');

    // Start Firebase initialization (non-blocking) only on non-macOS platforms.
    if (!Platform.isMacOS) {
      _initFirebaseWithTimeout();
    } else {
      debugPrint('Not starting async Firebase initialization on macOS (per user request)');
    }
  }, (error, stack) {
    // Log uncaught async errors
    debugPrint('Uncaught async error: $error');
    debugPrint(stack.toString());
  });
 
}

class VendingMachineTycoonApp extends StatefulWidget {
  const VendingMachineTycoonApp({super.key});

  @override
  State<VendingMachineTycoonApp> createState() => _VendingMachineTycoonAppState();
}

class _VendingMachineTycoonAppState extends State<VendingMachineTycoonApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Listen to app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Stop listening to app lifecycle changes
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final soundService = SoundService.instance;
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App is going to background or becoming inactive
        // Pause music to save battery and be respectful of other apps
        soundService.pauseBackgroundMusic();
        break;
      case AppLifecycleState.resumed:
        // App is coming back to foreground
        // Resume music if it was playing
        soundService.resumeBackgroundMusic();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App is being terminated or hidden
        // Pause music
        soundService.pauseBackgroundMusic();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vending Machine Tycoon',
      theme: ThemeData(
        useMaterial3: true,
        // Use bundled Fredoka font for consistent rendering across all platforms
        // This overrides platform-specific defaults (Roboto on Android, San Francisco on macOS)
        fontFamily: 'Fredoka',
        // Apply font to all text styles
        textTheme: ThemeData.light().textTheme.apply(
          fontFamily: 'Fredoka',
        ),
        primaryTextTheme: ThemeData.light().primaryTextTheme.apply(
          fontFamily: 'Fredoka',
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
          surface: const Color(0xFFF5F5F5), // Light grey background instead of white
        ),
      ),
      home: const MenuScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

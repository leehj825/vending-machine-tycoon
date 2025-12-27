import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ui/screens/menu_screen.dart';
import 'services/sound_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
  
  runApp(
    const ProviderScope(
      child: VendingMachineTycoonApp(),
    ),
  );
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
    final soundService = SoundService();
    
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

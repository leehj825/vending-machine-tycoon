import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'ui/theme/vex_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ui/screens/menu_screen.dart';
import 'services/sound_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
    final soundService = SoundService.instance;
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // The app is actually in the background (switched away, screen off or
        // being terminated) - stop our music so it doesn't play on unseen.
        soundService.pauseBackgroundMusic(isAppBackgrounding: true);
        break;
      case AppLifecycleState.inactive:
        // Transient: a notification shade, a permission dialog, or another
        // app's floating window (e.g. YouTube picture-in-picture) overlapping
        // the game. The game is still on screen, so keep playing - pausing
        // here would cut the music every time something briefly overlaps.
        break;
      case AppLifecycleState.resumed:
        // App is coming back to foreground
        // Resume music if it was playing
        soundService.resumeBackgroundMusic();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vending Machine Tycoon',
      theme: VexTheme.light,
      home: const MenuScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

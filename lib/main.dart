import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ui/screens/menu_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: VendingMachineTycoonApp(),
    ),
  );
}

class VendingMachineTycoonApp extends StatelessWidget {
  const VendingMachineTycoonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vending Machine Tycoon',
      theme: ThemeData(
        useMaterial3: true,
        // Define the default font family for the entire app
        textTheme: GoogleFonts.fredokaTextTheme(
          ThemeData.light().textTheme,
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

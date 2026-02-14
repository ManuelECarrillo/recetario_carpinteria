import 'dart:async';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../screens/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    await Future.wait([
      StorageService.cargarMuebles(),
      Future.delayed(const Duration(milliseconds: 1200)),
    ]);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen(muebles: [])),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/branding/logo.png',
                width: 180,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 180,
                child: LinearProgressIndicator(
                  minHeight: 6,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  color: const Color(0xFFE53935),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

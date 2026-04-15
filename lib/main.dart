import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Added back
import 'state/melo_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Added back
  
  try {
    await dotenv.load(fileName: ".env"); // Added back
  } catch (e) {
    debugPrint('⚠️ [Main] Error loading .env file: $e');
  }
  
  runApp(
    const ProviderScope(
      child: MeloApp(),
    ),
  );
}

class MeloApp extends StatelessWidget {
  const MeloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Melo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(meloProvider);
    final meloNotifier = ref.read(meloProvider.notifier);

    // Global Error Listening
    ref.listen<MeloState>(meloProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.redAccent,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () => meloNotifier.clearError(),
            ),
          ),
        );
      }
    });

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E1E3F), Color(0xFF1A1A2E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'MELO',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _getStatusText(state.status),
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  color: Colors.white70,
                ),
              ),
              const Spacer(),
              
              // Central Orb UI
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer glow
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      height: 250,
                      width: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _getStatusColor(state.status).withOpacity(0.35),
                            blurRadius: 50,
                            spreadRadius: 20,
                          ),
                        ],
                      ),
                    ),
                    
                    // The Interactive Orb
                    GestureDetector(
                      onLongPressStart: (_) => meloNotifier.startListening(),
                      onLongPressEnd: (_) => meloNotifier.stopTalkingAndProcess(),
                      onTap: () {
                        if (state.status == AppStatus.idle) {
                          meloNotifier.startListening();
                        } else {
                          meloNotifier.stopTalkingAndProcess();
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 220,
                        width: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 2,
                          ),
                        ),
                        child: _buildOrbContent(state.status),
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              const Icon(Icons.mic, color: Colors.white54),
              const SizedBox(height: 10),
              Text(
                'Tap to Talk',
                style: GoogleFonts.outfit(color: Colors.white38),
              ),
              const Text(
                '(Auto-stops when you\'re quiet)',
                style: TextStyle(fontSize: 10, color: Colors.white24),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusText(AppStatus status) {
    switch (status) {
      case AppStatus.idle: return 'Hey bro, I\'m listening...';
      case AppStatus.recording: return 'Listening...';
      case AppStatus.thinking: return 'Thinking...';
      case AppStatus.responding: return 'Melo is speaking...';
    }
  }

  Color _getStatusColor(AppStatus status) {
    switch (status) {
      case AppStatus.idle: 
        return Colors.deepPurpleAccent;
      case AppStatus.recording: 
        return Colors.deepPurpleAccent;
      case AppStatus.thinking: 
        return Colors.redAccent;
      case AppStatus.responding: 
        return Colors.greenAccent;
    }
  }

  Widget _buildOrbContent(AppStatus status) {
    return AnimatedScale(
      scale: status == AppStatus.recording ? 1.1 : 1.0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        opacity: status == AppStatus.idle ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: ClipOval(
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              _getStatusColor(status).withOpacity(0.8),
              BlendMode.srcATop,
            ),
            child: Image.asset(
              'assets/images/melo_orb-bg-normal.png',
              height: 180,
              width: 180,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}

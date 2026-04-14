import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'state/melo_state.dart';

void main() {
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
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meloState = ref.watch(meloProvider);
    final meloNotifier = ref.read(meloProvider.notifier);

    // Listen for errors and show SnackBar
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
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF0F0F1A),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Top Vibe Text
              Positioned(
                top: 40,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    Text(
                      _getStatusText(meloState.status),
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        meloState.status == AppStatus.idle 
                          ? "Hey bro, I'm listening..." 
                          : (meloState.status == AppStatus.responding ? meloState.lastAiText : ""),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: Colors.white60,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Central Interactive Orb
              Center(
                child: GestureDetector(
                  onTap: () {
                    if (meloState.status == AppStatus.idle) {
                      meloNotifier.startTalking();
                    } else if (meloState.status == AppStatus.recording) {
                      meloNotifier.stopTalkingAndProcess();
                    }
                  },
                  child: AnimatedContainer(

                    duration: const Duration(milliseconds: 300),
                    height: 220,
                    width: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _getStatusColor(meloState.status).withOpacity(0.3),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Dynamic Orb Background
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                _getStatusColor(meloState.status).withOpacity(0.8),
                                _getStatusColor(meloState.status).withOpacity(0.2),
                              ],
                            ),
                          ),
                        ),
                        
                        // Lottie / Animation based on status
                        _buildStatusAnimation(meloState.status),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Hint
              Positioned(
                bottom: 60,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    const Icon(Icons.mic, color: Colors.white70, size: 30),
                    const SizedBox(height: 10),
                    Text(
                      "Tap to Talk",
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: Colors.white38,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      "(Auto-stops when you're quiet)",
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: Colors.white24,
                      ),
                    ),

                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusText(AppStatus status) {
    switch (status) {
      case AppStatus.idle: return "MELO";
      case AppStatus.recording: return "LISTENING";
      case AppStatus.thinking: return "THINKING";
      case AppStatus.responding: return "MELO";
    }
  }

  Color _getStatusColor(AppStatus status) {
    switch (status) {
      case AppStatus.idle: 
        return Colors.deepPurpleAccent; // Original / Listening
      case AppStatus.recording: 
        return Colors.deepPurpleAccent; // "Listening make it just as now"
      case AppStatus.thinking: 
        return Colors.redAccent;         // "Thinking make it red"
      case AppStatus.responding: 
        return Colors.greenAccent;       // "Talking make it green"
    }
  }

  Widget _buildStatusAnimation(AppStatus status) {
    double scale = 1.0;
    double opacity = 0.9;
    
    // Add dynamic effects based on status
    if (status == AppStatus.recording) {
      scale = 1.1; // Pulsing effect would be handled by a parent scale animation if possible, 
                   // but for now we set a base scale
    }

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
              _getStatusColor(status),
              BlendMode.modulate,
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

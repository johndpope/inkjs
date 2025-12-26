import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const PresidentAdventureApp());
}

class PresidentAdventureApp extends StatelessWidget {
  const PresidentAdventureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'President Adventure',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        textTheme: GoogleFonts.vt323TextTheme(
          ThemeData.dark().textTheme,
        ).apply(
          bodyColor: const Color(0xFF00FF41),
          displayColor: const Color(0xFF00FF41),
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF41),
          secondary: Color(0xFF00D9FF),
          surface: Color(0xFF161B22),
          error: Color(0xFFFF6B6B),
        ),
      ),
      home: const TitleScreen(),
    );
  }
}

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  bool _hasSavedGame = false;
  bool _isLoading = true;

  static const String _saveKeyChoiceHistory = 'president_choice_history';

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _blinkAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
    _checkForSavedGame();
  }

  Future<void> _checkForSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSave = prefs.containsKey(_saveKeyChoiceHistory);
    setState(() {
      _hasSavedGame = hasSave;
      _isLoading = false;
    });
  }

  Future<void> _clearSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_saveKeyChoiceHistory);
    await prefs.remove('president_paragraphs');
    setState(() {
      _hasSavedGame = false;
    });
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0D1117),
              const Color(0xFF161B22).withValues(alpha: 0.8),
              const Color(0xFF0D1117),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  // ASCII Art Title
                  Text(
                    '╔══════════════════════════════╗',
                    style: GoogleFonts.vt323(
                      fontSize: 16,
                      color: const Color(0xFF00FF41),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PRESIDENT',
                    style: GoogleFonts.vt323(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF00FF41),
                      letterSpacing: 8,
                      shadows: [
                        Shadow(
                          color: const Color(0xFF00FF41).withValues(alpha: 0.5),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'FICTIOUS',
                    style: GoogleFonts.vt323(
                      fontSize: 32,
                      color: const Color(0xFF00D9FF),
                      letterSpacing: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '╚══════════════════════════════╝',
                    style: GoogleFonts.vt323(
                      fontSize: 16,
                      color: const Color(0xFF00FF41),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'A TEXT ADVENTURE',
                    style: GoogleFonts.vt323(
                      fontSize: 20,
                      color: const Color(0xFFFFD93D),
                      letterSpacing: 4,
                    ),
                  ),
                  const Spacer(),
                  // Stats preview
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF00FF41).withValues(alpha: 0.3),
                      ),
                      color: const Color(0xFF0D1117).withValues(alpha: 0.8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '> SYSTEM INITIALIZED',
                          style: GoogleFonts.vt323(
                            fontSize: 16,
                            color: const Color(0xFF00FF41).withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _hasSavedGame
                              ? '> SAVED SESSION DETECTED'
                              : '> LOADING SITUATION ROOM...',
                          style: GoogleFonts.vt323(
                            fontSize: 16,
                            color: _hasSavedGame
                                ? const Color(0xFF00D9FF)
                                : const Color(0xFF00FF41).withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '> READY FOR COMMAND',
                          style: GoogleFonts.vt323(
                            fontSize: 16,
                            color: const Color(0xFFFFD93D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Menu buttons
                  if (!_isLoading) ...[
                    // Continue button (if saved game exists)
                    if (_hasSavedGame) ...[
                      FadeTransition(
                        opacity: _blinkAnimation,
                        child: _buildMenuButton(
                          '[ CONTINUE ]',
                          const Color(0xFF00D9FF),
                          () => _continueGame(context),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildMenuButton(
                        '[ NEW GAME ]',
                        const Color(0xFFFFD93D),
                        () => _showNewGameConfirm(context),
                      ),
                    ] else ...[
                      // Just start button for new game
                      FadeTransition(
                        opacity: _blinkAnimation,
                        child: _buildMenuButton(
                          '[ START GAME ]',
                          const Color(0xFF00FF41),
                          () => _startNewGame(context),
                        ),
                      ),
                    ],
                  ],
                  const Spacer(flex: 2),
                  Text(
                    'Powered by Ink Narrative Engine',
                    style: GoogleFonts.vt323(
                      fontSize: 14,
                      color: const Color(0xFF00FF41).withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(String text, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 32,
          vertical: 16,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: color,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Text(
          text,
          style: GoogleFonts.vt323(
            fontSize: 24,
            color: color,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  void _continueGame(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const GameScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    ).then((_) {
      // Refresh saved game status when returning
      _checkForSavedGame();
    });
  }

  void _startNewGame(BuildContext context) async {
    await _clearSavedGame();
    if (context.mounted) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const GameScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      ).then((_) {
        _checkForSavedGame();
      });
    }
  }

  void _showNewGameConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFF00FF41)),
          borderRadius: BorderRadius.circular(4),
        ),
        title: Text(
          'START NEW GAME?',
          style: GoogleFonts.vt323(
            fontSize: 24,
            color: const Color(0xFFFFD93D),
          ),
        ),
        content: Text(
          'Your saved progress will be deleted.',
          style: GoogleFonts.vt323(
            fontSize: 18,
            color: const Color(0xFF00FF41),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '[ CANCEL ]',
              style: GoogleFonts.vt323(
                fontSize: 16,
                color: const Color(0xFF00FF41),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startNewGame(context);
            },
            child: Text(
              '[ NEW GAME ]',
              style: GoogleFonts.vt323(
                fontSize: 16,
                color: const Color(0xFFFF6B6B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

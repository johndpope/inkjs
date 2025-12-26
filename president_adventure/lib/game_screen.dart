import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ink_dart/ink_dart.dart' hide Container;
import 'package:shared_preferences/shared_preferences.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  Story? _story;
  String? _storyJson;
  final List<StoryParagraph> _paragraphs = [];
  List<Choice> _choices = [];
  bool _isLoading = true;
  bool _isTyping = false;
  String _currentTypingText = '';
  int _typingIndex = 0;
  Timer? _typingTimer;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _cursorController;

  // Track choice history for save/restore
  final List<int> _choiceHistory = [];

  // Game stats for display
  int _publicApproval = 50;
  int _budget = 100;
  int _legacyPoints = 0;
  int _day = 1;

  static const String _saveKeyChoiceHistory = 'president_choice_history';
  static const String _saveKeyParagraphs = 'president_paragraphs';

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      duration: const Duration(milliseconds: 530),
      vsync: this,
    )..repeat(reverse: true);
    _loadStory();
  }

  @override
  void dispose() {
    _saveGame();
    _typingTimer?.cancel();
    _scrollController.dispose();
    _cursorController.dispose();
    super.dispose();
  }

  Future<void> _loadStory() async {
    try {
      _storyJson = await rootBundle.loadString('assets/president_game.json');
      _story = Story(_storyJson!);

      // Try to load saved game
      final loaded = await _loadSavedGame();

      setState(() {
        _isLoading = false;
      });

      if (!loaded) {
        _continueStory();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _paragraphs.add(StoryParagraph(
          text: 'Error loading story: $e',
          isError: true,
        ));
      });
    }
  }

  Future<bool> _loadSavedGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final choiceHistoryJson = prefs.getString(_saveKeyChoiceHistory);
      final paragraphsJson = prefs.getString(_saveKeyParagraphs);

      if (choiceHistoryJson != null && paragraphsJson != null && _story != null) {
        // Load choice history
        final List<dynamic> savedChoices = jsonDecode(choiceHistoryJson);
        _choiceHistory.clear();
        _choiceHistory.addAll(savedChoices.cast<int>());

        // Replay all choices to restore state
        for (final choiceIndex in _choiceHistory) {
          // Continue to get choices
          while (_story!.canContinue) {
            _story!.continueStory();
          }
          // Make the saved choice
          if (_story!.currentChoices.isNotEmpty &&
              choiceIndex < _story!.currentChoices.length) {
            _story!.chooseChoiceIndex(choiceIndex);
          }
        }

        // Continue after final choice
        while (_story!.canContinue) {
          _story!.continueStory();
        }

        // Load paragraphs for display
        final List<dynamic> paragraphsList = jsonDecode(paragraphsJson);
        _paragraphs.clear();
        for (final p in paragraphsList) {
          _paragraphs.add(StoryParagraph(
            text: p['text'] as String,
            isPlayerChoice: p['isPlayerChoice'] as bool? ?? false,
            isError: p['isError'] as bool? ?? false,
            isComplete: true,
          ));
        }

        _updateStats();
        setState(() {
          _choices = _story!.currentChoices;
        });
        _scrollToBottom();
        return true;
      }
    } catch (e) {
      debugPrint('Failed to load saved game: $e');
      // If loading fails, reset and start fresh
      _story = Story(_storyJson!);
      _choiceHistory.clear();
    }
    return false;
  }

  Future<void> _saveGame() async {
    if (_story == null || _choiceHistory.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Save choice history
      await prefs.setString(_saveKeyChoiceHistory, jsonEncode(_choiceHistory));

      // Save paragraphs for display
      final paragraphsList = _paragraphs.map((p) => {
        'text': p.text,
        'isPlayerChoice': p.isPlayerChoice,
        'isError': p.isError,
      }).toList();
      await prefs.setString(_saveKeyParagraphs, jsonEncode(paragraphsList));
    } catch (e) {
      debugPrint('Failed to save game: $e');
    }
  }

  Future<void> _clearSave() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_saveKeyChoiceHistory);
    await prefs.remove(_saveKeyParagraphs);
  }

  void _updateStats() {
    if (_story == null) return;
    try {
      _publicApproval =
          (_story!.variablesState['public_approval'] as num?)?.toInt() ?? 50;
      _budget = (_story!.variablesState['budget'] as num?)?.toInt() ?? 100;
      _legacyPoints =
          (_story!.variablesState['legacy_points'] as num?)?.toInt() ?? 0;
      _day = (_story!.variablesState['day'] as num?)?.toInt() ?? 1;
    } catch (e) {
      // Variables might not exist yet
    }
  }

  void _continueStory() {
    if (_story == null) return;

    while (_story!.canContinue) {
      final text = _story!.continueStory()?.trim() ?? '';
      if (text.isNotEmpty) {
        _addTextWithTypingEffect(text);
      }
    }

    _updateStats();

    setState(() {
      _choices = _story!.currentChoices;
    });

    _scrollToBottom();
    _saveGame();
  }

  void _addTextWithTypingEffect(String text) {
    _paragraphs.add(StoryParagraph(text: text, isComplete: false));
    _startTypingEffect(_paragraphs.length - 1, text);
  }

  void _startTypingEffect(int paragraphIndex, String text) {
    _isTyping = true;
    _currentTypingText = text;
    _typingIndex = 0;

    _typingTimer?.cancel();
    _typingTimer = Timer.periodic(const Duration(milliseconds: 15), (timer) {
      if (_typingIndex < text.length) {
        setState(() {
          _paragraphs[paragraphIndex] = StoryParagraph(
            text: text.substring(0, _typingIndex + 1),
            isComplete: false,
          );
          _typingIndex++;
        });
        _scrollToBottom();
      } else {
        timer.cancel();
        setState(() {
          _paragraphs[paragraphIndex] = StoryParagraph(
            text: text,
            isComplete: true,
          );
          _isTyping = false;
        });
      }
    });
  }

  void _skipTyping() {
    _typingTimer?.cancel();
    if (_paragraphs.isNotEmpty) {
      setState(() {
        _paragraphs[_paragraphs.length - 1] = StoryParagraph(
          text: _currentTypingText,
          isComplete: true,
        );
        _isTyping = false;
      });
    }
  }

  void _makeChoice(int index) {
    if (_isTyping) {
      _skipTyping();
      return;
    }

    final choice = _choices[index];

    // Record choice in history
    _choiceHistory.add(index);

    // Add choice as player input
    _paragraphs.add(StoryParagraph(
      text: '> ${choice.text}',
      isPlayerChoice: true,
      isComplete: true,
    ));

    _story!.chooseChoiceIndex(index);
    _continueStory();
  }

  void _restartGame() async {
    await _clearSave();
    _story = Story(_storyJson!);
    _choiceHistory.clear();
    setState(() {
      _paragraphs.clear();
      _choices.clear();
    });
    _continueStory();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'LOADING SITUATION ROOM...',
                style: GoogleFonts.vt323(
                  fontSize: 24,
                  color: const Color(0xFF00FF41),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  backgroundColor: const Color(0xFF161B22),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF00FF41),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          await _saveGame();
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0D1117),
                Color(0xFF161B22),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildStatsBar(),
                Expanded(
                  child: _buildStoryArea(),
                ),
                _buildChoicesArea(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF00FF41).withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF00FF41)),
            onPressed: () async {
              await _saveGame();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          Expanded(
            child: Text(
              'OVAL OFFICE TERMINAL',
              textAlign: TextAlign.center,
              style: GoogleFonts.vt323(
                fontSize: 20,
                color: const Color(0xFF00FF41),
                letterSpacing: 4,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFFFD93D)),
            onPressed: () => _showRestartDialog(),
          ),
        ],
      ),
    );
  }

  void _showRestartDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFF00FF41)),
          borderRadius: BorderRadius.circular(4),
        ),
        title: Text(
          'RESTART PRESIDENCY?',
          style: GoogleFonts.vt323(
            fontSize: 24,
            color: const Color(0xFFFFD93D),
          ),
        ),
        content: Text(
          'All progress will be lost.',
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
              _restartGame();
            },
            child: Text(
              '[ RESTART ]',
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

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117).withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF00FF41).withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('DAY', '$_day', const Color(0xFFFFD93D)),
          _buildStatItem(
            'APPROVAL',
            '$_publicApproval%',
            _getApprovalColor(_publicApproval),
          ),
          _buildStatItem(
            'BUDGET',
            '$_budget',
            _getBudgetColor(_budget),
          ),
          _buildStatItem('LEGACY', '$_legacyPoints', const Color(0xFF00D9FF)),
        ],
      ),
    );
  }

  Color _getApprovalColor(int approval) {
    if (approval >= 60) return const Color(0xFF00FF41);
    if (approval >= 40) return const Color(0xFFFFD93D);
    return const Color(0xFFFF6B6B);
  }

  Color _getBudgetColor(int budget) {
    if (budget >= 50) return const Color(0xFF00FF41);
    if (budget >= 25) return const Color(0xFFFFD93D);
    return const Color(0xFFFF6B6B);
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.vt323(
            fontSize: 12,
            color: const Color(0xFF00FF41).withValues(alpha: 0.6),
            letterSpacing: 2,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.vt323(
            fontSize: 20,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStoryArea() {
    return GestureDetector(
      onTap: _isTyping ? _skipTyping : null,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          border: Border.all(
            color: const Color(0xFF00FF41).withValues(alpha: 0.3),
          ),
        ),
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _paragraphs.length,
          itemBuilder: (context, index) {
            final paragraph = _paragraphs[index];
            return _buildParagraph(paragraph, index == _paragraphs.length - 1);
          },
        ),
      ),
    );
  }

  Widget _buildParagraph(StoryParagraph paragraph, bool isLast) {
    Color textColor;
    if (paragraph.isError) {
      textColor = const Color(0xFFFF6B6B);
    } else if (paragraph.isPlayerChoice) {
      textColor = const Color(0xFF00D9FF);
    } else {
      textColor = const Color(0xFF00FF41);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: paragraph.text),
                  if (isLast && !paragraph.isComplete)
                    WidgetSpan(
                      child: AnimatedBuilder(
                        animation: _cursorController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _cursorController.value,
                            child: Text(
                              '█',
                              style: GoogleFonts.vt323(
                                fontSize: 18,
                                color: textColor,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
              style: GoogleFonts.vt323(
                fontSize: 18,
                color: textColor,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoicesArea() {
    if (_choices.isEmpty) {
      // Game over state
      if (_paragraphs.isNotEmpty && !_isTyping) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                '═══ END OF PRESIDENCY ═══',
                style: GoogleFonts.vt323(
                  fontSize: 20,
                  color: const Color(0xFFFFD93D),
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 12),
              _buildChoiceButton(
                '[ RESTART ]',
                _restartGame,
                const Color(0xFF00FF41),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF00FF41).withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '─── AVAILABLE ACTIONS ───',
            textAlign: TextAlign.center,
            style: GoogleFonts.vt323(
              fontSize: 14,
              color: const Color(0xFF00FF41).withValues(alpha: 0.6),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          ..._choices.asMap().entries.map((entry) {
            final index = entry.key;
            final choice = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _buildChoiceButton(
                '[${index + 1}] ${choice.text}',
                () => _makeChoice(index),
                _getChoiceColor(index),
              ),
            );
          }),
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '(tap to skip)',
                textAlign: TextAlign.center,
                style: GoogleFonts.vt323(
                  fontSize: 12,
                  color: const Color(0xFF00FF41).withValues(alpha: 0.4),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getChoiceColor(int index) {
    final colors = [
      const Color(0xFF00FF41),
      const Color(0xFF00D9FF),
      const Color(0xFFFFD93D),
      const Color(0xFFFF6B6B),
    ];
    return colors[index % colors.length];
  }

  Widget _buildChoiceButton(String text, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: _isTyping ? _skipTyping : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: color.withValues(alpha: _isTyping ? 0.3 : 0.6),
          ),
          color: color.withValues(alpha: 0.05),
        ),
        child: Text(
          text,
          style: GoogleFonts.vt323(
            fontSize: 16,
            color: _isTyping ? color.withValues(alpha: 0.5) : color,
          ),
        ),
      ),
    );
  }
}

class StoryParagraph {
  final String text;
  final bool isPlayerChoice;
  final bool isError;
  final bool isComplete;

  StoryParagraph({
    required this.text,
    this.isPlayerChoice = false,
    this.isError = false,
    this.isComplete = true,
  });
}

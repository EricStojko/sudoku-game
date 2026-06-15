import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app_colors.dart';
import '../logic/game_notifier.dart';
import '../models/difficulty.dart';
import '../models/leaderboard_entry.dart';
import '../services/leaderboard_service.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/animated_sudoku_cell.dart';

class SudokuGameScreen extends StatefulWidget {
  const SudokuGameScreen({super.key});

  @override
  State<SudokuGameScreen> createState() => _SudokuGameScreenState();
}

class _SudokuGameScreenState extends State<SudokuGameScreen> {
  GameNotifier? _notifierRef;
  GameNotifier get _notifier => _notifierRef!;

  final FocusNode _boardFocusNode = FocusNode();
  bool _isBoardFocused = false;

  @override
  void initState() {
    super.initState();
    _boardFocusNode.addListener(() {
      if (mounted) {
        setState(() {
          _isBoardFocused = _boardFocusNode.hasFocus;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newNotifier = Provider.of<GameNotifier>(context, listen: false);
    if (newNotifier != _notifierRef) {
      _notifierRef?.removeListener(_handleStatusChange);
      _notifierRef = newNotifier;
      _notifierRef!.addListener(_handleStatusChange);
    }
  }

  @override
  void dispose() {
    _notifierRef?.removeListener(_handleStatusChange);
    _boardFocusNode.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Status event handler
  // -------------------------------------------------------------------------

  void _handleStatusChange() {
    if (_notifier.status == GameStatus.won) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _notifier.triggerConfetti();
          _showWinDialog();
        }
      });
    } else if (_notifier.status == GameStatus.gameOver) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showGameOverDialog();
      });
    }
  }

  // -------------------------------------------------------------------------
  // Keyboard handler
  // -------------------------------------------------------------------------

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    // Map both main-row digits and numpad digits to their value.
    final Map<LogicalKeyboardKey, int> digitKeys = {
      LogicalKeyboardKey.digit1: 1,
      LogicalKeyboardKey.digit2: 2,
      LogicalKeyboardKey.digit3: 3,
      LogicalKeyboardKey.digit4: 4,
      LogicalKeyboardKey.digit5: 5,
      LogicalKeyboardKey.digit6: 6,
      LogicalKeyboardKey.digit7: 7,
      LogicalKeyboardKey.digit8: 8,
      LogicalKeyboardKey.digit9: 9,
      LogicalKeyboardKey.numpad1: 1,
      LogicalKeyboardKey.numpad2: 2,
      LogicalKeyboardKey.numpad3: 3,
      LogicalKeyboardKey.numpad4: 4,
      LogicalKeyboardKey.numpad5: 5,
      LogicalKeyboardKey.numpad6: 6,
      LogicalKeyboardKey.numpad7: 7,
      LogicalKeyboardKey.numpad8: 8,
      LogicalKeyboardKey.numpad9: 9,
    };

    if (digitKeys.containsKey(key)) {
      _notifier.inputNumber(digitKeys[key]!);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      _notifier.inputNumber(0);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      _notifier.moveSelection(-1, 0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _notifier.moveSelection(1, 0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _notifier.moveSelection(0, -1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _notifier.moveSelection(0, 1);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // -------------------------------------------------------------------------
  // Dialogs
  // -------------------------------------------------------------------------

  void _showWinDialog() async {
    final elapsed = _notifier.secondsElapsed.value;
    final difficulty = _notifier.difficulty;
    final eligible = _notifier.isLeaderboardEligible;
    final isTop = eligible ? await LeaderboardService.isTop10(difficulty, elapsed) : false;

    if (!mounted) return;

    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFDFBFF),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'You did it! 🎉',
            style: TextStyle(
                color: AppColors.primaryDark, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Time: ${GameNotifier.formatTime(elapsed)}',
                style: const TextStyle(fontSize: 18),
              ),
              if (!eligible) ...[
                const SizedBox(height: 15),
                const Text(
                  'Leaderboard disabled (Hints used)',
                  style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ],
              if (isTop) ...[
                const SizedBox(height: 15),
                const Text(
                  'New Top 10 Score!',
                  style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Your Name',
                    labelStyle:
                        TextStyle(color: Colors.purple.shade300),
                    enabledBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: Colors.purple.shade200),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: AppColors.primaryDark, width: 2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (isTop) {
                  final name = nameCtrl.text.isEmpty
                      ? 'Anonymous'
                      : nameCtrl.text;
                  await LeaderboardService.saveScore(
                      difficulty, name, elapsed);
                }
                nameCtrl.dispose();
                if (context.mounted) {
                  Navigator.pop(context);
                  _showLeaderboard();
                }
              },
              child: Text(
                'Continue',
                style: TextStyle(
                    fontSize: 16,
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFDFBFF),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Game Over',
            style: TextStyle(
                color: Color(0xFFFDA4AF), fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'You made 3 mistakes! Better luck next time.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _notifier.startNewGame(_notifier.difficulty);
              },
              child: Text(
                'Try Again',
                style:
                    TextStyle(fontSize: 16, color: AppColors.primaryDark),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showLeaderboard() {
    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<List<List<LeaderboardEntry>>>(
          future: Future.wait([
            LeaderboardService.fetchEntries(Difficulty.easy),
            LeaderboardService.fetchEntries(Difficulty.medium),
            LeaderboardService.fetchEntries(Difficulty.hard),
          ]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return AlertDialog(
                backgroundColor: const Color(0xFFFDFBFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primaryDark),
                  ),
                ),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return AlertDialog(
                backgroundColor: const Color(0xFFFDFBFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text('Error'),
                content: const Text('Failed to load leaderboard data.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              );
            }

            final results = snapshot.data!;
            return DefaultTabController(
              length: 3,
              initialIndex: _notifier.difficulty.index,
              child: AlertDialog(
                backgroundColor: const Color(0xFFFDFBFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                contentPadding: const EdgeInsets.only(top: 20),
                title: Center(
                  child: Text(
                    'Leaderboards',
                    style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold),
                  ),
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 400,
                  child: Column(
                    children: [
                      TabBar(
                        labelColor: AppColors.primaryDark,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: AppColors.primaryDark,
                        tabs: const [
                          Tab(text: 'EASY'),
                          Tab(text: 'MEDIUM'),
                          Tab(text: 'HARD'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: results.map((entries) {
                            if (entries.isEmpty) {
                              return const Center(child: Text('No scores yet!', style: TextStyle(color: Colors.grey)));
                            }
                            return ListView.builder(
                              itemCount: entries.length,
                              itemBuilder: (context, index) {
                                final entry = entries[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.accentPastel,
                                    child: Text('${index + 1}', style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
                                  ),
                                  title: Text(entry.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                                  trailing: Text(GameNotifier.formatTime(entry.timeInSeconds), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                                  subtitle: Text(entry.date, style: const TextStyle(fontSize: 12)),
                                );
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _notifier.startNewGame(_notifier.difficulty);
                    },
                    child: Text('Play Again', style: TextStyle(fontSize: 16, color: AppColors.primaryDark)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // UI Builders
  // -------------------------------------------------------------------------

  Widget _buildTopControls() {
    return Consumer<GameNotifier>(
      builder: (context, n, _) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: Difficulty.values.map((d) {
                  final isSelected = n.difficulty == d;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _notifier.startNewGame(d),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryPastel
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            d.name[0].toUpperCase() + d.name.substring(1),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.purple.shade300,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    const Icon(Icons.error_outline,
                        color: Color(0xFFFDA4AF)),
                    const SizedBox(width: 8),
                    Text(
                      'Mistakes: ${n.mistakes} / 3',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark),
                    ),
                  ]),
                  Row(children: [
                    IconButton(
                      icon: Icon(n.isUserPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: AppColors.primaryDark),
                      onPressed: n.togglePause,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.timer_outlined,
                        color: Color(0xFFA7F3D0)),
                    const SizedBox(width: 8),
                    ValueListenableBuilder<int>(
                      valueListenable: n.secondsElapsed,
                      builder: (context, seconds, _) {
                        return Text(
                          GameNotifier.formatTime(seconds),
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark),
                        );
                      },
                    ),
                  ]),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGrid() {
    return Selector<GameNotifier, bool>(
      selector: (_, n) => n.isGenerating,
      builder: (context, isGenerating, child) {
        return LayoutBuilder(builder: (context, constraints) {
          double boardSize =
              min(constraints.maxWidth, constraints.maxHeight) - 32;
          if (boardSize > 500) boardSize = 500;
          final cellSize = (boardSize - 7) / 9;

          if (isGenerating) {
            return Container(
              width: boardSize,
              height: boardSize,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.purple.shade300, width: 3),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.primaryDark),
                    const SizedBox(height: 16),
                    Text(
                      'Generating Board...',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Container(
            width: boardSize,
            height: boardSize,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: _isBoardFocused ? AppColors.primaryDark : Colors.purple.shade300,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isBoardFocused
                      ? AppColors.primaryDark.withValues(alpha: 0.25)
                      : Colors.purple.withValues(alpha: 0.1),
                  blurRadius: 10,
                  spreadRadius: 5,
                )
              ],
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      9,
                      (r) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          9,
                          (c) => AnimatedSudokuCell(row: r, col: c, size: cellSize),
                        ),
                      ),
                    ),
                  ),
                ),
                Selector<GameNotifier, bool>(
                  selector: (_, n) => n.isUserPaused,
                  builder: (context, isUserPaused, child) {
                    if (!isUserPaused) return const SizedBox.shrink();
                    return Container(
                      color: Colors.white.withValues(alpha: 0.95),
                      child: Center(
                        child: Text(
                          'PAUSED',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 8,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Selector<GameNotifier, GameStatus>(
                  selector: (_, n) => n.status,
                  builder: (context, status, child) {
                    if (status != GameStatus.idle) return const SizedBox.shrink();
                    return Container(
                      color: Colors.purple.shade50.withValues(alpha: 0.95),
                      child: Center(
                        child: ElevatedButton.icon(
                          onPressed: () => context.read<GameNotifier>().startGame(),
                          icon: const Icon(Icons.play_arrow_rounded, size: 28),
                          label: const Text(
                            'Start Game',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryDark,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            elevation: 4,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _buildActionButtons() {
    return Consumer<GameNotifier>(
      builder: (context, n, _) {
        final bool isPausedOrOver = n.isUserPaused || n.status != GameStatus.playing;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: n.canUndo && !isPausedOrOver ? n.undo : null,
              icon: const Icon(Icons.undo),
              label: const Text('Undo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryDark,
                shape: const StadiumBorder(),
                elevation: 2,
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: !isPausedOrOver ? n.useCheck : null,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Check'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryDark,
                shape: const StadiumBorder(),
                elevation: 2,
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: n.canUseHint && !isPausedOrOver ? n.useHint : null,
              icon: const Icon(Icons.lightbulb_outline),
              label: Text('Hint (${5 - n.hintsUsed})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange.shade700,
                shape: const StadiumBorder(),
                elevation: 2,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNumberPad() {
    return Consumer<GameNotifier>(
      builder: (context, n, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            children: [
              Row(children: List.generate(5, (i) => _buildPadButton(n, i + 1))),
              const SizedBox(height: 10),
              Row(children: [
                ...List.generate(4, (i) => _buildPadButton(n, i + 6)),
                _buildEraseButton(n),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPadButton(GameNotifier n, int num) {
    final bool isExhausted = n.isNumberExhausted(num);
    final bool isDisabled = isExhausted || n.isUserPaused || n.status != GameStatus.playing;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: InkWell(
          onTap: isDisabled ? null : () => n.inputNumber(num),
          borderRadius: BorderRadius.circular(15),
          child: AspectRatio(
            aspectRatio: 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: isDisabled ? Colors.grey.shade200 : Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: isDisabled ? [] : [
                  BoxShadow(
                      color: Colors.purple.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Center(
                child: Text(
                  num.toString(),
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDisabled ? Colors.grey.shade400 : AppColors.primaryDark),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEraseButton(GameNotifier n) {
    bool isFixed = false;
    if (n.selectedRow != -1 && n.selectedCol != -1) {
      isFixed = n.grid[n.selectedRow][n.selectedCol].isFixed;
    }
    final bool isDisabled = isFixed || n.isUserPaused || n.status != GameStatus.playing;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: InkWell(
          onTap: isDisabled ? null : () => n.inputNumber(0),
          borderRadius: BorderRadius.circular(15),
          child: AspectRatio(
            aspectRatio: 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: isDisabled ? Colors.grey.shade200 : const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(15),
                boxShadow: isDisabled ? [] : [
                  BoxShadow(
                      color: Colors.purple.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Center(
                child: Icon(Icons.backspace_outlined,
                    color: isDisabled ? Colors.grey.shade400 : AppColors.primaryDark),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _boardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Selector<GameNotifier, bool>(
        selector: (_, n) => n.showConfetti,
        builder: (context, showConfetti, child) {
          return ConfettiOverlay(
            showConfetti: showConfetti,
            child: child!,
          );
        },
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'StojkoDoku',
              style: TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 24),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(Icons.leaderboard_rounded,
                    color: Colors.purple.shade400),
                onPressed: _showLeaderboard,
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),
                    _buildTopControls(),
                    const SizedBox(height: 20),
                    _buildGrid(),
                    const SizedBox(height: 20),
                    _buildActionButtons(),
                    const SizedBox(height: 20),
                    _buildNumberPad(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

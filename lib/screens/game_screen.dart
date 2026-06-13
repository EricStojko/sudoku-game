import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app_colors.dart';
import '../logic/game_notifier.dart';
import '../models/difficulty.dart';
import '../services/leaderboard_service.dart';
import '../widgets/confetti_overlay.dart';

class SudokuGameScreen extends StatefulWidget {
  const SudokuGameScreen({super.key});

  @override
  State<SudokuGameScreen> createState() => _SudokuGameScreenState();
}

class _SudokuGameScreenState extends State<SudokuGameScreen> {
  // Obtained once from the Provider tree in didChangeDependencies.
  // Kept as a field so non-build methods (keyboard handler, dialogs) can
  // access the notifier without needing a BuildContext.
  late final GameNotifier _notifier;
  bool _notifierBound = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_notifierBound) {
      // context.read — we only need the reference once, not a rebuild trigger.
      _notifier = context.read<GameNotifier>();
      _notifier.addListener(_handleStatusChange);
      _notifierBound = true;
    }
  }

  @override
  void dispose() {
    _notifier.removeListener(_handleStatusChange);
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
    final elapsed = _notifier.secondsElapsed;
    final difficulty = _notifier.difficulty;
    final eligible = _notifier.isLeaderboardEligible;
    final isTop = eligible ? await LeaderboardService.isTop10(difficulty, elapsed) : false;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final nameCtrl = TextEditingController();
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

  void _showLeaderboard() async {
    final results = await Future.wait([
      LeaderboardService.fetchEntries(Difficulty.easy),
      LeaderboardService.fetchEntries(Difficulty.medium),
      LeaderboardService.fetchEntries(Difficulty.hard),
    ]);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
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
  }

  // -------------------------------------------------------------------------
  // UI Builders
  // -------------------------------------------------------------------------

  Widget _buildTopControls(GameNotifier n) {
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
                const Icon(Icons.timer_outlined,
                    color: Color(0xFFA7F3D0)),
                const SizedBox(width: 8),
                Text(
                  GameNotifier.formatTime(n.secondsElapsed),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(GameNotifier n) {
    return LayoutBuilder(builder: (context, constraints) {
      double boardSize =
          min(constraints.maxWidth, constraints.maxHeight) - 32;
      if (boardSize > 500) boardSize = 500;
      final cellSize = (boardSize - 7) / 9;

      return Container(
        width: boardSize,
        height: boardSize,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.purple.shade300, width: 3),
          boxShadow: [
            BoxShadow(
                color: Colors.purple.withValues(alpha: 0.1),
                blurRadius: 10,
                spreadRadius: 5)
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              9,
              (r) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                    9, (c) => _buildCell(n, r, c, cellSize)),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildCell(GameNotifier n, int r, int c, double size) {
    final cell = n.grid[r][c];
    final isSelected = r == n.selectedRow && c == n.selectedCol;

    bool isSameValue = false;
    if (n.selectedRow != -1 && n.selectedCol != -1) {
      final selValue = n.grid[n.selectedRow][n.selectedCol].currentValue;
      if (selValue != 0 && cell.currentValue == selValue) {
        isSameValue = true;
      }
    }

    Color bgColor = Colors.white;
    if (isSelected) {
      bgColor = AppColors.accentPastel;
    } else if (cell.isErrorHighlight) {
      bgColor = AppColors.errorPastel;
    } else if (isSameValue) {
      bgColor = AppColors.primaryPastel.withValues(alpha: 0.4);
    } else if (cell.isFixed) {
      bgColor = AppColors.fixedCellBg;
    }

    return GestureDetector(
      onTap: () => _notifier.selectCell(r, c),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            top: BorderSide(
                width: r % 3 == 0 && r != 0 ? 2 : 0.5,
                color: Colors.purple.shade300),
            left: BorderSide(
                width: c % 3 == 0 && c != 0 ? 2 : 0.5,
                color: Colors.purple.shade300),
          ),
        ),
        child: Center(
          child: Text(
            cell.currentValue == 0 ? '' : cell.currentValue.toString(),
            style: TextStyle(
              fontSize: size * 0.5,
              fontWeight:
                  cell.isFixed ? FontWeight.bold : FontWeight.w600,
              color: cell.isFixed
                  ? const Color(0xFF1F2937)
                  : AppColors.primaryDark,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: _notifier.canUndo ? _notifier.undo : null,
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
          onPressed: _notifier.useCheck,
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
          onPressed: _notifier.canUseHint ? _notifier.useHint : null,
          icon: const Icon(Icons.lightbulb_outline),
          label: Text('Hint (${5 - _notifier.hintsUsed})'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.orange.shade700,
            shape: const StadiumBorder(),
            elevation: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildNumberPad() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        children: [
          Row(children: List.generate(5, (i) => _buildPadButton(i + 1))),
          const SizedBox(height: 10),
          Row(children: [
            ...List.generate(4, (i) => _buildPadButton(i + 6)),
            _buildEraseButton(),
          ]),
        ],
      ),
    );
  }

  Widget _buildPadButton(int num) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: InkWell(
          onTap: () => _notifier.inputNumber(num),
          borderRadius: BorderRadius.circular(15),
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
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
                      color: AppColors.primaryDark),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEraseButton() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: InkWell(
          onTap: () => _notifier.inputNumber(0),
          borderRadius: BorderRadius.circular(15),
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                      color: Colors.purple.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Center(
                child: Icon(Icons.backspace_outlined,
                    color: AppColors.primaryDark),
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
    // context.watch subscribes this widget to GameNotifier changes,
    // replacing the old ListenableBuilder.
    final notifier = context.watch<GameNotifier>();
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: ConfettiOverlay(
        showConfetti: notifier.showConfetti,
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
                    _buildTopControls(notifier),
                    const SizedBox(height: 20),
                    _buildGrid(notifier),
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

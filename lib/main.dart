import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Design tokens — single source of truth for all app colours.
// ---------------------------------------------------------------------------
class AppColors {
  AppColors._(); // prevent instantiation

  static const Color primaryPastel = Color(0xFFC4B5FD); // Soft purple
  static const Color secondaryPastel = Color(0xFFA7F3D0); // Soft mint green
  static const Color accentPastel = Color(0xFFFBCFE8); // Soft pink
  static const Color errorPastel = Color(0xFFFDA4AF); // Soft red
  static const Color fixedCellBg = Color(0xFFF3F4F6); // Soft gray
  static const Color primaryDark = Color(0xFF6D28D9); // Deep purple for text
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SudokuApp());
}

class SudokuApp extends StatelessWidget {
  const SudokuApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StojkoDoku',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.purple,
        scaffoldBackgroundColor: const Color(0xFFFDFBFF), // Very soft pastel background
        useMaterial3: true,
      ),
      home: const SudokuGameScreen(),
    );
  }
}

// --- MODELS ---

enum Difficulty { easy, medium, hard }

class SudokuCell {
  final int correctValue;
  int currentValue;
  final bool isFixed;
  bool isErrorHighlight;
  // Tracks whether a mistake has already been counted for the current wrong
  // value in this cell. Prevents double-counting when the user erases and
  // re-enters the same (or a different) wrong number without a correct attempt.
  bool hasMistake;

  SudokuCell({
    required this.correctValue,
    required this.currentValue,
    required this.isFixed,
    this.isErrorHighlight = false,
    this.hasMistake = false,
  });
}

class LeaderboardEntry {
  final String name;
  final int timeInSeconds;
  final String date;

  LeaderboardEntry(this.name, this.timeInSeconds, this.date);

  Map<String, dynamic> toJson() => {
        'name': name,
        'time': timeInSeconds,
        'date': date,
      };

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(json['name'], json['time'], json['date']);
  }
}

// --- SUDOKU GENERATOR ---

class SudokuGenerator {
  static List<List<int>> generateCompleted() {
    // Valid Base Matrix
    List<List<int>> grid = [
      [1, 2, 3, 4, 5, 6, 7, 8, 9],
      [4, 5, 6, 7, 8, 9, 1, 2, 3],
      [7, 8, 9, 1, 2, 3, 4, 5, 6],
      [2, 3, 1, 5, 6, 4, 8, 9, 7],
      [5, 6, 4, 8, 9, 7, 2, 3, 1],
      [8, 9, 7, 2, 3, 1, 5, 6, 4],
      [3, 1, 2, 6, 4, 5, 9, 7, 8],
      [6, 4, 5, 9, 7, 8, 3, 1, 2],
      [9, 7, 8, 3, 1, 2, 6, 4, 5],
    ];

    Random rand = Random();

    // 1. Shuffle digit mappings (1-9)
    List<int> digits = [1, 2, 3, 4, 5, 6, 7, 8, 9];
    digits.shuffle(rand);
    List<List<int>> newGrid = List.generate(9, (r) => List.filled(9, 0));
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        newGrid[r][c] = digits[grid[r][c] - 1];
      }
    }
    grid = newGrid;

    // 2. Shuffle rows within 3x3 blocks
    for (int i = 0; i < 3; i++) {
      int r1 = i * 3 + rand.nextInt(3);
      int r2 = i * 3 + rand.nextInt(3);
      List<int> temp = grid[r1];
      grid[r1] = grid[r2];
      grid[r2] = temp;
    }

    // 3. Shuffle columns within 3x3 blocks
    for (int i = 0; i < 3; i++) {
      int c1 = i * 3 + rand.nextInt(3);
      int c2 = i * 3 + rand.nextInt(3);
      for (int r = 0; r < 9; r++) {
        int temp = grid[r][c1];
        grid[r][c1] = grid[r][c2];
        grid[r][c2] = temp;
      }
    }

    // 4. Shuffle 3x3 row blocks
    int br1 = rand.nextInt(3);
    int br2 = rand.nextInt(3);
    if (br1 != br2) {
      for (int i = 0; i < 3; i++) {
        List<int> temp = grid[br1 * 3 + i];
        grid[br1 * 3 + i] = grid[br2 * 3 + i];
        grid[br2 * 3 + i] = temp;
      }
    }

    // 5. Shuffle 3x3 column blocks
    int bc1 = rand.nextInt(3);
    int bc2 = rand.nextInt(3);
    if (bc1 != bc2) {
      for (int i = 0; i < 3; i++) {
        for (int r = 0; r < 9; r++) {
          int temp = grid[r][bc1 * 3 + i];
          grid[r][bc1 * 3 + i] = grid[r][bc2 * 3 + i];
          grid[r][bc2 * 3 + i] = temp;
        }
      }
    }

    return grid;
  }

  static List<List<int>> generatePuzzle(List<List<int>> solvedGrid, Difficulty diff) {
    List<List<int>> puzzle = solvedGrid.map((row) => List<int>.from(row)).toList();
    Random rand = Random();
    int holes = 0;
    
    switch (diff) {
      case Difficulty.easy:
        holes = 35; // Easier, more numbers given
        break;
      case Difficulty.medium:
        holes = 45;
        break;
      case Difficulty.hard:
        holes = 55; // Harder, fewer numbers given
        break;
    }

    int count = 0;
    while (count < holes) {
      int r = rand.nextInt(9);
      int c = rand.nextInt(9);
      if (puzzle[r][c] != 0) {
        puzzle[r][c] = 0;
        count++;
      }
    }
    return puzzle;
  }
}

// --- MAIN GAME SCREEN ---

class SudokuGameScreen extends StatefulWidget {
  const SudokuGameScreen({Key? key}) : super(key: key);

  @override
  _SudokuGameScreenState createState() => _SudokuGameScreenState();
}

class _SudokuGameScreenState extends State<SudokuGameScreen> {
  Difficulty _difficulty = Difficulty.easy;
  late List<List<SudokuCell>> _grid;
  int _selectedRow = -1;
  int _selectedCol = -1;
  int _mistakes = 0;
  
  Timer? _timer;
  int _secondsElapsed = 0;
  bool _isPlaying = false;
  bool _showConfetti = false;

  @override
  void initState() {
    super.initState();
    _startNewGame(Difficulty.easy);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startNewGame(Difficulty diff) {
    _difficulty = diff;
    _mistakes = 0;
    _selectedRow = -1;
    _selectedCol = -1;
    _secondsElapsed = 0;
    _isPlaying = true;
    _showConfetti = false;

    var solved = SudokuGenerator.generateCompleted();
    var puzzle = SudokuGenerator.generatePuzzle(solved, diff);

    _grid = List.generate(
      9,
      (r) => List.generate(
        9,
        (c) => SudokuCell(
          correctValue: solved[r][c],
          currentValue: puzzle[r][c],
          isFixed: puzzle[r][c] != 0,
        ),
      ),
    );

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPlaying && mounted) {
        setState(() => _secondsElapsed++);
      }
    });
    setState(() {});
  }

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _checkWinCondition() {
    bool isWon = true;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (_grid[r][c].currentValue != _grid[r][c].correctValue) {
          isWon = false;
          break;
        }
      }
      if (!isWon) break;
    }

    if (isWon) {
      _isPlaying = false;
      _timer?.cancel();
      _showWinDialog();
    }
  }

  void _onNumberInput(int num) {
    if (!_isPlaying || _selectedRow == -1 || _selectedCol == -1) return;
    var cell = _grid[_selectedRow][_selectedCol];
    if (cell.isFixed) return;

    setState(() {
      if (num == 0) {
        // Erase: clear the wrong-entry flag so the next entry is a fresh attempt.
        cell.currentValue = 0;
        cell.hasMistake = false;
      } else if (num == cell.correctValue) {
        // Correct value: resolve the cell cleanly.
        cell.currentValue = num;
        cell.hasMistake = false;
      } else {
        // Wrong value: only count a mistake if this cell isn't already penalised.
        // This prevents double-counting when switching between wrong numbers
        // without erasing first.
        if (!cell.hasMistake) {
          _mistakes++;
          cell.hasMistake = true;
        }
        cell.currentValue = num;
      }

      if (_mistakes >= 3) {
        _isPlaying = false;
        _timer?.cancel();
        _showGameOverDialog();
      } else {
        _checkWinCondition();
      }
    });
  }

  void _useHint() {
    if (!_isPlaying || _selectedRow == -1 || _selectedCol == -1) return;
    var cell = _grid[_selectedRow][_selectedCol];
    if (cell.isFixed || cell.currentValue == cell.correctValue) return;

    setState(() {
      cell.currentValue = cell.correctValue;
      _checkWinCondition();
    });
  }

  void _useCheck() {
    if (!_isPlaying) return;

    setState(() {
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          var cell = _grid[r][c];
          if (!cell.isFixed && cell.currentValue != 0 && cell.currentValue != cell.correctValue) {
            cell.isErrorHighlight = true;
          }
        }
      }
    });

    // Temporarily highlight for 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          for (int r = 0; r < 9; r++) {
            for (int c = 0; c < 9; c++) {
              _grid[r][c].isErrorHighlight = false;
            }
          }
        });
      }
    });
  }

  Future<void> _saveScore(String name, int time) async {
    final prefs = await SharedPreferences.getInstance();
    String key = 'leaderboard_${_difficulty.name}';
    List<String> records = prefs.getStringList(key) ?? [];

    List<LeaderboardEntry> entries = records.map((e) => LeaderboardEntry.fromJson(jsonDecode(e))).toList();
    entries.add(LeaderboardEntry(name, time, DateTime.now().toIso8601String().split('T').first));
    entries.sort((a, b) => a.timeInSeconds.compareTo(b.timeInSeconds));
    if (entries.length > 10) {
      entries = entries.sublist(0, 10);
    }

    await prefs.setStringList(key, entries.map((e) => jsonEncode(e.toJson())).toList());
  }

  Future<bool> _isTop10(int time) async {
    final prefs = await SharedPreferences.getInstance();
    String key = 'leaderboard_${_difficulty.name}';
    List<String> records = prefs.getStringList(key) ?? [];
    if (records.length < 10) return true;

    List<LeaderboardEntry> entries = records.map((e) => LeaderboardEntry.fromJson(jsonDecode(e))).toList();
    entries.sort((a, b) => a.timeInSeconds.compareTo(b.timeInSeconds));

    return time < entries.last.timeInSeconds;
  }

  void _showWinDialog() async {
    bool isTop = await _isTop10(_secondsElapsed);

    setState(() => _showConfetti = true);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showConfetti = false);
    });

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        TextEditingController nameCtrl = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFFFDFBFF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("You did it! 🎉", style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Time: ${_formatTime(_secondsElapsed)}", style: const TextStyle(fontSize: 18)),
              if (isTop) ...[
                const SizedBox(height: 15),
                const Text("New Top 10 Score!", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: "Your Name",
                    labelStyle: TextStyle(color: Colors.purple.shade300),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.purple.shade200),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primaryDark, width: 2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                )
              ]
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (isTop && nameCtrl.text.isNotEmpty) {
                  await _saveScore(nameCtrl.text, _secondsElapsed);
                } else if (isTop && nameCtrl.text.isEmpty) {
                  await _saveScore("Anonymous", _secondsElapsed);
                }
                if (mounted) {
                  Navigator.pop(context);
                  _showLeaderboard();
                }
              },
              child: Text("Continue", style: TextStyle(fontSize: 16, color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
            )
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Game Over", style: TextStyle(color: Color(0xFFFDA4AF), fontWeight: FontWeight.bold)),
          content: const Text("You made 3 mistakes! Better luck next time.", style: TextStyle(fontSize: 16)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _startNewGame(_difficulty);
              },
              child: Text("Try Again", style: TextStyle(fontSize: 16, color: AppColors.primaryDark)),
            )
          ],
        );
      },
    );
  }

  void _showLeaderboard() async {
    final prefs = await SharedPreferences.getInstance();
    String key = 'leaderboard_${_difficulty.name}';
    List<String> records = prefs.getStringList(key) ?? [];
    List<LeaderboardEntry> entries = records.map((e) => LeaderboardEntry.fromJson(jsonDecode(e))).toList();
    entries.sort((a, b) => a.timeInSeconds.compareTo(b.timeInSeconds));

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFDFBFF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Center(
            child: Text(
              "Top 10 - ${_difficulty.name.toUpperCase()}",
              style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold),
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: entries.isEmpty
                ? const Center(child: Text("No scores yet!", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      var entry = entries[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.accentPastel,
                          child: Text("${index + 1}", style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(entry.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                        trailing: Text(_formatTime(entry.timeInSeconds), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                        subtitle: Text(entry.date, style: const TextStyle(fontSize: 12)),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _startNewGame(_difficulty);
              },
              child: Text("Play Again", style: TextStyle(fontSize: 16, color: AppColors.primaryDark)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close", style: TextStyle(fontSize: 16, color: Colors.grey)),
            )
          ],
        );
      },
    );
  }

  // --- UI BUILDERS ---

  Widget _buildTopControls() {
    return Column(
      children: [
        // Difficulty Segmented Control
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: Difficulty.values.map((d) {
              bool isSelected = _difficulty == d;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _startNewGame(d),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryPastel : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        d.name[0].toUpperCase() + d.name.substring(1),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.purple.shade300,
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
        // Stats
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFFDA4AF)),
                  const SizedBox(width: 8),
                  Text(
                    "Mistakes: $_mistakes / 3",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Color(0xFFA7F3D0)),
                  const SizedBox(width: 8),
                  Text(
                    _formatTime(_secondsElapsed),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(builder: (context, constraints) {
      double boardSize = min(constraints.maxWidth, constraints.maxHeight) - 32;
      if (boardSize > 500) boardSize = 500;
      
      // FIXED: The outer border takes 3px on each side (6px total). 
      // We subtract an additional 1px of safety margin to prevent any microscopic layout overflows in the web renderer.
      double cellSize = (boardSize - 7) / 9;

      return Container(
        width: boardSize,
        height: boardSize,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.purple.shade300, width: 3),
          boxShadow: [
            BoxShadow(color: Colors.purple.withOpacity(0.1), blurRadius: 10, spreadRadius: 5)
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min, // Compresses tightly inside the available space
            children: List.generate(9, (r) => Row(
                  mainAxisSize: MainAxisSize.min, // Compresses tightly inside the available space
                  children: List.generate(9, (c) => _buildCell(r, c, cellSize)),
                )),
          ),
        ),
      );
    });
  }

  Widget _buildCell(int r, int c, double size) {
    SudokuCell cell = _grid[r][c];
    bool isSelected = r == _selectedRow && c == _selectedCol;

    // Check if cell has same value as selected cell
    bool isSameValue = false;
    if (_selectedRow != -1 && _selectedCol != -1) {
      int selValue = _grid[_selectedRow][_selectedCol].currentValue;
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
      bgColor = AppColors.primaryPastel.withOpacity(0.4);
    } else if (cell.isFixed) {
      bgColor = AppColors.fixedCellBg;
    }

    return GestureDetector(
      onTap: () => setState(() {
        _selectedRow = r;
        _selectedCol = c;
      }),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            top: BorderSide(width: r % 3 == 0 && r != 0 ? 2 : 0.5, color: Colors.purple.shade300),
            left: BorderSide(width: c % 3 == 0 && c != 0 ? 2 : 0.5, color: Colors.purple.shade300),
          ),
        ),
        child: Center(
          child: Text(
            cell.currentValue == 0 ? "" : cell.currentValue.toString(),
            style: TextStyle(
              fontSize: size * 0.5,
              fontWeight: cell.isFixed ? FontWeight.bold : FontWeight.w600,
              color: cell.isFixed ? const Color(0xFF1F2937) : AppColors.primaryDark,
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
          onPressed: _useCheck,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text("Check"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primaryDark,
            shape: const StadiumBorder(),
            elevation: 2,
          ),
        ),
        const SizedBox(width: 20),
        ElevatedButton.icon(
          onPressed: _useHint,
          icon: const Icon(Icons.lightbulb_outline),
          label: const Text("Hint"),
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
          Row(
            children: List.generate(5, (i) => _buildPadButton(i + 1)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ...List.generate(4, (i) => _buildPadButton(i + 6)),
              _buildEraseButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPadButton(int num) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: InkWell(
          onTap: () => _onNumberInput(num),
          borderRadius: BorderRadius.circular(15),
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(color: Colors.purple.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                ],
              ),
              child: Center(
                child: Text(
                  num.toString(),
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
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
          onTap: () => _onNumberInput(0),
          borderRadius: BorderRadius.circular(15),
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(color: Colors.purple.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                ],
              ),
              child: Center(
                child: Icon(Icons.backspace_outlined, color: AppColors.primaryDark),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- KEYBOARD INPUT ---

  /// Moves the selected cell by [dr] rows and [dc] columns, clamped to the
  /// board bounds. If nothing is selected yet, starts at (0, 0).
  void _moveSelection(int dr, int dc) {
    setState(() {
      _selectedRow = (_selectedRow == -1 ? 0 : _selectedRow + dr).clamp(0, 8);
      _selectedCol = (_selectedCol == -1 ? 0 : _selectedCol + dc).clamp(0, 8);
    });
  }

  /// Handles physical keyboard events so players on web/desktop can use
  /// their keyboard instead of (or alongside) the on-screen number pad.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // Only act on initial key-down and auto-repeated key events.
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    // Map both main-row digits and numpad digits to their numeric value.
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
      _onNumberInput(digitKeys[key]!);
      return KeyEventResult.handled;
    }

    // Delete or Backspace → erase the selected cell.
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      _onNumberInput(0);
      return KeyEventResult.handled;
    }

    // Arrow keys → move the selected cell.
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveSelection(-1, 0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveSelection(1, 0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _moveSelection(0, -1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _moveSelection(0, 1);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: ConfettiOverlay(
        showConfetti: _showConfetti,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text("StojkoDoku", style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold, fontSize: 24)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.leaderboard_rounded, color: Colors.purple.shade400),
              onPressed: _showLeaderboard,
            )
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

// --- CONFETTI EFFECT ---

class ConfettiOverlay extends StatefulWidget {
  final Widget child;
  final bool showConfetti;

  const ConfettiOverlay({Key? key, required this.child, required this.showConfetti}) : super(key: key);

  @override
  _ConfettiOverlayState createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  List<ConfettiParticle> _particles = [];
  Random rand = Random();
  double _lastWidth = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(ConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showConfetti && !oldWidget.showConfetti) {
      if (_lastWidth > 0) _generateParticles(_lastWidth);
      _ctrl.forward(from: 0);
    }
  }

  void _generateParticles(double width) {
    _particles = List.generate(150, (index) {
      return ConfettiParticle(
        x: rand.nextDouble() * width,
        y: -50.0 - rand.nextDouble() * 200,
        dx: rand.nextDouble() * 200 - 100,
        dy: rand.nextDouble() * 400 + 200,
        size: rand.nextDouble() * 6 + 4,
        color: Colors.primaries[rand.nextInt(Colors.primaries.length)],
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.showConfetti && _ctrl.isAnimating)
          Positioned.fill(
            child: IgnorePointer(
              child: LayoutBuilder(builder: (context, constraints) {
                if (_lastWidth != constraints.maxWidth) {
                  _lastWidth = constraints.maxWidth;
                }
                return CustomPaint(
                  painter: ConfettiPainter(_particles, _ctrl.value),
                );
              }),
            ),
          )
      ],
    );
  }
}

class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  final double progress;

  ConfettiPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final paint = Paint()..color = p.color;
      // Calculate dynamic physics positions
      double x = p.x + p.dx * progress;
      double y = p.y + p.dy * progress + 400 * progress * progress; // Acceleration for gravity
      canvas.drawCircle(Offset(x, y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class ConfettiParticle {
  double x, y, dx, dy, size;
  Color color;
  ConfettiParticle({
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required this.size,
    required this.color,
  });
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_colors.dart';
import '../logic/game_notifier.dart';

typedef CellStateRecord = (
  int currentValue,
  bool isErrorHighlight,
  bool isSelected,
  bool isSameValue,
  bool isFixed,
  bool hasMistake,
);

class AnimatedSudokuCell extends StatefulWidget {
  final int row;
  final int col;
  final double size;

  const AnimatedSudokuCell({
    super.key,
    required this.row,
    required this.col,
    required this.size,
  });

  @override
  State<AnimatedSudokuCell> createState() => _AnimatedSudokuCellState();
}

class _AnimatedSudokuCellState extends State<AnimatedSudokuCell> with TickerProviderStateMixin {
  late AnimationController _popController;
  late Animation<double> _scaleAnimation;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2).chain(CurveTween(curve: Curves.easeOut)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 50),
    ]).animate(_popController);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -4.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 4.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: -4.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 4.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _popController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<GameNotifier, CellStateRecord>(
      selector: (context, notifier) {
        final cell = notifier.grid[widget.row][widget.col];
        final isSelected = widget.row == notifier.selectedRow && widget.col == notifier.selectedCol;

        bool isSameValue = false;
        if (notifier.selectedRow != -1 && notifier.selectedCol != -1) {
          final selValue = notifier.grid[notifier.selectedRow][notifier.selectedCol].currentValue;
          if (selValue != 0 && cell.currentValue == selValue) {
            isSameValue = true;
          }
        }

        return (
          cell.currentValue,
          cell.isErrorHighlight,
          isSelected,
          isSameValue,
          cell.isFixed,
          cell.hasMistake,
        );
      },
      builder: (context, data, child) {
        return _CellContent(
          row: widget.row,
          col: widget.col,
          size: widget.size,
          data: data,
          popController: _popController,
          scaleAnimation: _scaleAnimation,
          shakeController: _shakeController,
          shakeAnimation: _shakeAnimation,
        );
      },
    );
  }
}

class _CellContent extends StatefulWidget {
  final int row;
  final int col;
  final double size;
  final CellStateRecord data;
  final AnimationController popController;
  final Animation<double> scaleAnimation;
  final AnimationController shakeController;
  final Animation<double> shakeAnimation;

  const _CellContent({
    required this.row,
    required this.col,
    required this.size,
    required this.data,
    required this.popController,
    required this.scaleAnimation,
    required this.shakeController,
    required this.shakeAnimation,
  });

  @override
  State<_CellContent> createState() => _CellContentState();
}

class _CellContentState extends State<_CellContent> {
  @override
  void didUpdateWidget(covariant _CellContent oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldVal = oldWidget.data.$1;
    final newVal = widget.data.$1;
    final oldHasMistake = oldWidget.data.$6;
    final newHasMistake = widget.data.$6;

    // Trigger animations when the cell's value changes to a new non-zero value
    if (newVal != 0 && newVal != oldVal) {
      if (newHasMistake && !oldHasMistake) {
        widget.shakeController.forward(from: 0.0);
      } else if (!newHasMistake) {
        widget.popController.forward(from: 0.0);
      }
    } else if (newVal != 0 && newHasMistake && !oldHasMistake) {
      // Trigger shake if mistake is marked but value was same (e.g. they typed the same wrong number again)
      // Actually if they typed the same wrong number again, value doesn't change, but hasMistake might toggle if they erased it, but if they erased it newVal=0.
      widget.shakeController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (currentValue, isErrorHighlight, isSelected, isSameValue, isFixed, _) = widget.data;
    final notifier = context.read<GameNotifier>();

    Color bgColor = Colors.white;
    if (isSelected) {
      bgColor = AppColors.accentPastel;
    } else if (isErrorHighlight) {
      bgColor = AppColors.errorPastel;
    } else if (isSameValue) {
      bgColor = AppColors.primaryPastel.withValues(alpha: 0.4);
    } else if (isFixed) {
      bgColor = AppColors.fixedCellBg;
    }

    return GestureDetector(
      onTap: () => notifier.selectCell(widget.row, widget.col),
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.popController, widget.shakeController]),
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(widget.shakeAnimation.value, 0),
            child: Transform.scale(
              scale: widget.scaleAnimation.value,
              child: child,
            ),
          );
        },
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              top: BorderSide(
                width: widget.row % 3 == 0 && widget.row != 0 ? 2 : 0.5,
                color: Colors.purple.shade300,
              ),
              left: BorderSide(
                width: widget.col % 3 == 0 && widget.col != 0 ? 2 : 0.5,
                color: Colors.purple.shade300,
              ),
            ),
          ),
          child: Center(
            child: Text(
              currentValue == 0 ? '' : currentValue.toString(),
              style: TextStyle(
                fontSize: widget.size * 0.5,
                fontWeight: isFixed ? FontWeight.bold : FontWeight.w600,
                color: isFixed ? const Color(0xFF1F2937) : AppColors.primaryDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

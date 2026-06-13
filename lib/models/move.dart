class Move {
  final int row;
  final int col;
  final int previousValue;
  final bool previousHasMistake;

  Move({
    required this.row,
    required this.col,
    required this.previousValue,
    required this.previousHasMistake,
  });
}

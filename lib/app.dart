import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'logic/game_notifier.dart';
import 'screens/game_screen.dart';

class SudokuApp extends StatelessWidget {
  const SudokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameNotifier()..initGame(),
      child: MaterialApp(
        title: 'StojkoDoku',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.purple,
          scaffoldBackgroundColor: const Color(0xFFFDFBFF),
          useMaterial3: true,
        ),
        home: const SudokuGameScreen(),
      ),
    );
  }
}

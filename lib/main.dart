// =============================================================
// main.dart
// アプリの入口です。テーマ（色）を決めて、ゲーム画面を表示します。
// =============================================================

import 'package:flutter/material.dart';

import 'game/game_screen.dart';

void main() {
  runApp(const PokerApp());
}

class PokerApp extends StatelessWidget {
  const PokerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ポーカー',
      debugShowCheckedModeBanner: false, // 右上のDEBUG帯を消す
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const GameScreen(),
    );
  }
}

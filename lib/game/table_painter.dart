// =============================================================
// table_painter.dart
// 背景の「ポーカーテーブル（緑のフェルト）」を描く部品です。
// CustomPaint から呼ばれ、画面いっぱいに緑の盤面と装飾を描きます。
// ゲーム進行には関係しない、見た目だけの担当です。
// =============================================================

import 'package:flutter/material.dart';

class TablePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1) 背景：中央が明るい緑、外側が暗い緑のグラデーション
    final bgPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment.center,
        radius: 0.9,
        colors: [Color(0xFF1B7A4B), Color(0xFF0B3D24)],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 2) 中央に楕円形のテーブル枠を描いて「卓」らしさを出す
    final tableRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.92,
      height: size.height * 0.78,
    );
    final borderPaint = Paint()
      ..color = const Color(0xFF6D4C2F) // 木枠っぽい茶色
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawOval(tableRect, borderPaint);

    final innerLine = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawOval(tableRect.deflate(14), innerLine);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

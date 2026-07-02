// =============================================================
// playing_card_widget.dart
// トランプ1枚を画面に描く部品です。
//   ・faceUp が true なら表（数字＋マーク）、false なら裏模様
//   ・表⇄裏の切り替えで横回転の「めくりアニメ」が走る
//   ・selected=true で「交換に選ばれた」ハイライト＋少し浮く演出
//   ・onTap を渡すとクリックで交換選択を切り替えられる
// =============================================================

import 'dart:math';

import 'package:flutter/material.dart';

import 'models.dart';

class PlayingCardWidget extends StatelessWidget {
  final PlayingCard card; // 表示するカード
  final double width; // カードの幅（高さは自動で 1.4 倍）
  final bool selected; // 交換対象に選ばれているか
  final VoidCallback? onTap; // クリック時の動作（null なら選択不可）

  const PlayingCardWidget({
    super.key,
    required this.card,
    this.width = 64,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final height = width * 1.4;

    // 中身（表 or 裏）をめくりアニメ付きで切り替える
    final flippable = AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, animation) {
        final rotate = Tween(begin: pi, end: 0.0).animate(animation);
        return AnimatedBuilder(
          animation: rotate,
          builder: (context, child) {
            final isUnderHalf = rotate.value.abs() > pi / 2;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001) // 奥行きを少し付けて立体的に
                ..rotateY(rotate.value),
              child: isUnderHalf ? const SizedBox.shrink() : child,
            );
          },
          child: child,
        );
      },
      child: card.faceUp
          ? _CardFront(card: card, width: width, height: height)
          : _CardBack(
              key: const ValueKey('back'),
              width: width,
              height: height,
            ),
    );

    // 選択中は少し上に浮かせ、金色の枠を付ける
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      transform: Matrix4.translationValues(0, selected ? -14 : 0, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? Colors.amber : Colors.transparent,
          width: 3,
        ),
      ),
      child: flippable,
    );

    // onTap があるときだけクリックを受け付ける
    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}

// -------------------------------------------------------------
// カードの表面
// -------------------------------------------------------------
class _CardFront extends StatelessWidget {
  final PlayingCard card;
  final double width;
  final double height;

  const _CardFront({
    required this.card,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final color = card.suit.color;
    return Container(
      key: const ValueKey('front'),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(1, 2)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(left: 4, top: 2, child: _corner(color)),
          Center(
            child: Text(
              card.suit.symbol,
              style: TextStyle(fontSize: width * 0.5, color: color),
            ),
          ),
          Positioned(
            right: 4,
            bottom: 2,
            child: Transform.rotate(angle: pi, child: _corner(color)),
          ),
        ],
      ),
    );
  }

  // 角の「数字＋マーク」
  Widget _corner(Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          card.rankLabel,
          style: TextStyle(
            fontSize: width * 0.26,
            fontWeight: FontWeight.bold,
            color: color,
            height: 1.0,
          ),
        ),
        Text(
          card.suit.symbol,
          style: TextStyle(fontSize: width * 0.22, color: color, height: 1.0),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// カードの裏面
// -------------------------------------------------------------
class _CardBack extends StatelessWidget {
  final double width;
  final double height;

  const _CardBack({
    super.key,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(1, 2)),
        ],
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7B1FA2), Color(0xFF4A148C)],
        ),
      ),
      child: Center(
        child: Container(
          width: width * 0.6,
          height: height * 0.7,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white38, width: 1.5),
          ),
          child: Icon(Icons.casino, color: Colors.white54, size: width * 0.4),
        ),
      ),
    );
  }
}

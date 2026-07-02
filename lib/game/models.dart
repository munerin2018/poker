// =============================================================
// models.dart
// ポーカーで使う「データの形」をまとめたファイルです。
// 見た目や進行の処理は書かず、純粋なデータだけを定義します。
// （データと処理を分けると、後から読みやすく・直しやすくなります）
// =============================================================

import 'package:flutter/material.dart';

// -------------------------------------------------------------
// トランプのマーク（スート）
// -------------------------------------------------------------
enum Suit {
  spades, // ♠ スペード
  hearts, // ♥ ハート
  diamonds, // ♦ ダイヤ
  clubs, // ♣ クラブ
}

extension SuitView on Suit {
  String get symbol {
    switch (this) {
      case Suit.spades:
        return '♠';
      case Suit.hearts:
        return '♥';
      case Suit.diamonds:
        return '♦';
      case Suit.clubs:
        return '♣';
    }
  }

  // ハート・ダイヤは赤、スペード・クラブは黒
  bool get isRed => this == Suit.hearts || this == Suit.diamonds;
  Color get color => isRed ? const Color(0xFFD32F2F) : const Color(0xFF212121);
}

// -------------------------------------------------------------
// トランプ1枚
//   suit  … マーク
//   rank  … 数字（1=エース, 11=J, 12=Q, 13=K）
//   faceUp… 表向きか（false なら裏を表示）
// -------------------------------------------------------------
class PlayingCard {
  final Suit suit;
  final int rank; // 1〜13
  bool faceUp;

  PlayingCard({
    required this.suit,
    required this.rank,
    this.faceUp = true,
  });

  // ポーカーでの数字の強さ。エースは一番強い 14 として扱う。
  // （A-2-3-4-5 の「ホイール」ストレートのときだけ役判定側で 1 扱いにする）
  int get pokerValue => rank == 1 ? 14 : rank;

  // 画面に出す文字（A, 2〜10, J, Q, K）
  String get rankLabel {
    switch (rank) {
      case 1:
        return 'A';
      case 11:
        return 'J';
      case 12:
        return 'Q';
      case 13:
        return 'K';
      default:
        return '$rank';
    }
  }
}

// -------------------------------------------------------------
// ポーカーの役（強い順）。enum の並び順がそのまま強さで、
// index が小さいほど強い役です（royalFlush=0 が最強）。
// -------------------------------------------------------------
enum HandRank {
  royalFlush, // ロイヤルストレートフラッシュ
  straightFlush, // ストレートフラッシュ
  fourOfAKind, // フォーカード
  fullHouse, // フルハウス
  flush, // フラッシュ
  straight, // ストレート
  threeOfAKind, // スリーカード
  twoPair, // ツーペア
  onePair, // ワンペア
  highCard, // ハイカード（役なし）
}

extension HandRankView on HandRank {
  // 画面表示用の日本語名
  String get label {
    switch (this) {
      case HandRank.royalFlush:
        return 'ロイヤルストレートフラッシュ';
      case HandRank.straightFlush:
        return 'ストレートフラッシュ';
      case HandRank.fourOfAKind:
        return 'フォーカード';
      case HandRank.fullHouse:
        return 'フルハウス';
      case HandRank.flush:
        return 'フラッシュ';
      case HandRank.straight:
        return 'ストレート';
      case HandRank.threeOfAKind:
        return 'スリーカード';
      case HandRank.twoPair:
        return 'ツーペア';
      case HandRank.onePair:
        return 'ワンペア';
      case HandRank.highCard:
        return 'ハイカード';
    }
  }
}

// -------------------------------------------------------------
// 役判定の結果。
//   rank      … 役の種類
//   tiebreak  … 同じ役どうしを比べるための数字（強い順に並ぶ）
//               例) ワンペアなら [ペアの数字, キッカー高, 中, 低]
// -------------------------------------------------------------
class HandResult {
  final HandRank rank;
  final List<int> tiebreak;

  HandResult(this.rank, this.tiebreak);
}

// -------------------------------------------------------------
// このラウンドの勝敗
// -------------------------------------------------------------
enum RoundOutcome { win, lose, push }

// -------------------------------------------------------------
// ゲームの進行段階（フェーズ）
// -------------------------------------------------------------
enum GamePhase {
  ready, // 開始前（スタート画面）
  betting, // 掛け金を決める（BET）
  playerDraw, // 交換するカードを選ぶ（CHANGE）
  cpuDraw, // CPUが交換中（自動）
  showdownReady, // 勝負の準備完了（SHOWDOWN 待ち）
  roundResult, // このラウンドの結果
  gameOver, // 5戦終了（最終結果）
}

// -------------------------------------------------------------
// 参加者（あなた・CPU）
// -------------------------------------------------------------
class Participant {
  final String name;
  final bool isHuman;
  int chips; // 所持チップ
  int bet; // このラウンドの掛け金
  List<PlayingCard> hand = []; // 手札（5枚）
  HandResult? result; // 役判定の結果（ショーダウン後）
  RoundOutcome? outcome; // 勝敗（結果表示中）

  Participant({
    required this.name,
    required this.isHuman,
    this.chips = 100,
  }) : bet = 0;

  // 新しいラウンドのためにリセット
  void resetForNewRound() {
    hand = [];
    bet = 0;
    result = null;
    outcome = null;
  }
}

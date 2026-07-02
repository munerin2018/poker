// =============================================================
// poker_logic.dart
// ポーカーの「ルールに関する計算」だけを集めたファイルです。
// 画面には一切触れず、ここでは
//   ・山札を作る／シャッフルする／配る
//   ・5枚の手札から役を判定する（HandEvaluator）
//   ・2人の手札を比べて勝敗を決める（compareHands）
//   ・CPUがどのカードを交換するか決める（CpuAi）
// を行います。
// =============================================================

import 'dart:math';

import 'models.dart';

// -------------------------------------------------------------
// 山札（デッキ）
// -------------------------------------------------------------
class Deck {
  final List<PlayingCard> _cards = [];
  final Random _random = Random();

  Deck() {
    reset();
  }

  int get remaining => _cards.length;

  // 52枚を作り直してシャッフルする
  void reset() {
    _cards.clear();
    for (final suit in Suit.values) {
      for (int rank = 1; rank <= 13; rank++) {
        _cards.add(PlayingCard(suit: suit, rank: rank));
      }
    }
    _cards.shuffle(_random);
  }

  // 上から1枚引く（足りなければ作り直す）
  PlayingCard draw({bool faceUp = true}) {
    if (_cards.isEmpty) reset();
    final card = _cards.removeLast();
    card.faceUp = faceUp;
    return card;
  }
}

// -------------------------------------------------------------
// 役判定
// 5枚のカードを受け取り、HandResult（役＋比較用の数字）を返します。
// -------------------------------------------------------------
class HandEvaluator {
  static HandResult evaluate(List<PlayingCard> cards) {
    // 1) 各カードの「強さの数字」を取り出す（A=14, K=13, ...）
    final values = cards.map((c) => c.pokerValue).toList()
      ..sort((a, b) => b.compareTo(a)); // 大きい順

    // 2) 同じ数字が何枚あるか数える（ペア・スリーカード判定用）
    final Map<int, int> counts = {};
    for (final v in values) {
      counts[v] = (counts[v] ?? 0) + 1;
    }

    // 3) フラッシュ（全部同じマーク）か
    final isFlush = cards.every((c) => c.suit == cards.first.suit);

    // 4) ストレート（5枚が連番）か。連番なら最高位の数字も求める。
    final straightHigh = _straightHigh(values);
    final isStraight = straightHigh != null;

    // 5) 「枚数が多い順 → 数字が大きい順」に並べた数字リスト。
    //    これがペア系の比較（tiebreak）にそのまま使えます。
    //    例) フルハウス(K3枚,2が2枚) → [13, 2]
    //        ツーペア(A,A,9,9,3)     → [14, 9, 3]
    final byCount = counts.keys.toList()
      ..sort((a, b) {
        final byNum = counts[b]!.compareTo(counts[a]!); // 枚数が多い方を前へ
        if (byNum != 0) return byNum;
        return b.compareTo(a); // 同じ枚数なら数字が大きい方を前へ
      });

    final countsSorted = byCount.map((v) => counts[v]!).toList()
      ..sort((a, b) => b.compareTo(a)); // 例) フルハウス→[3,2]

    // 6) 上から順に役を判定していく（強い役から確認）
    if (isStraight && isFlush) {
      // 最高が A(14) ならロイヤル、それ以外はストレートフラッシュ
      final rank =
          straightHigh == 14 ? HandRank.royalFlush : HandRank.straightFlush;
      return HandResult(rank, [straightHigh]);
    }
    if (countsSorted.first == 4) {
      return HandResult(HandRank.fourOfAKind, byCount); // [4枚の数字, キッカー]
    }
    if (countsSorted.first == 3 && countsSorted[1] == 2) {
      return HandResult(HandRank.fullHouse, byCount); // [3枚の数字, 2枚の数字]
    }
    if (isFlush) {
      return HandResult(HandRank.flush, values); // 高い順に全部
    }
    if (isStraight) {
      return HandResult(HandRank.straight, [straightHigh]);
    }
    if (countsSorted.first == 3) {
      return HandResult(HandRank.threeOfAKind, byCount); // [3枚, キッカー, キッカー]
    }
    if (countsSorted.first == 2 && countsSorted[1] == 2) {
      return HandResult(HandRank.twoPair, byCount); // [高ペア, 低ペア, キッカー]
    }
    if (countsSorted.first == 2) {
      return HandResult(HandRank.onePair, byCount); // [ペア, キッカー×3]
    }
    return HandResult(HandRank.highCard, values); // 役なし：高い順に全部
  }

  // ストレートかどうかを調べ、成立するなら「最高位の数字」を返す。
  // 成立しなければ null。
  static int? _straightHigh(List<int> valuesDesc) {
    // 重複を除いた数字の集合を作る
    final unique = valuesDesc.toSet().toList()..sort((a, b) => b.compareTo(a));
    if (unique.length != 5) return null; // 重複があればストレートではない

    // 通常の連番（例: 10,9,8,7,6）→ 最大-最小=4
    if (unique.first - unique.last == 4) return unique.first;

    // ホイール（A,5,4,3,2）。A=14 を 1 とみなした 5,4,3,2,1 の連番。
    // この場合の最高位は 5 として扱う。
    if (unique.contains(14) &&
        unique.contains(5) &&
        unique.contains(4) &&
        unique.contains(3) &&
        unique.contains(2)) {
      return 5;
    }
    return null;
  }
}

// -------------------------------------------------------------
// 勝敗比較
// 2つの HandResult を比べ、
//   正の数 … a の勝ち / 0 … 引き分け / 負の数 … b の勝ち
// を返します。
// -------------------------------------------------------------
int compareHands(HandResult a, HandResult b) {
  // まず役の強さ（index が小さいほど強い）
  if (a.rank.index != b.rank.index) {
    return b.rank.index - a.rank.index; // a の方が index 小→正の数→a勝ち
  }
  // 同じ役なら tiebreak を上位から比べる
  final len = min(a.tiebreak.length, b.tiebreak.length);
  for (int i = 0; i < len; i++) {
    if (a.tiebreak[i] != b.tiebreak[i]) {
      return a.tiebreak[i] - b.tiebreak[i];
    }
  }
  return 0; // 完全に同じ → 引き分け
}

// -------------------------------------------------------------
// CPUの交換AI
// 「どのカードを捨てる（交換する）か」をカードのインデックス一覧で返します。
// 役に絡まないカードを捨て、役を伸ばす定番の考え方です。
// -------------------------------------------------------------
class CpuAi {
  static List<int> cardsToExchange(List<PlayingCard> hand) {
    final result = HandEvaluator.evaluate(hand);

    switch (result.rank) {
      // 強い完成役は手を変えない（全部キープ）
      case HandRank.royalFlush:
      case HandRank.straightFlush:
      case HandRank.fullHouse:
      case HandRank.flush:
      case HandRank.straight:
        return [];

      // フォーカード：4枚を残し、余り1枚だけ交換（運試し）
      case HandRank.fourOfAKind:
        return _indicesNotIn(hand, _topCountValues(hand, 4));

      // スリーカード：3枚を残して2枚交換
      case HandRank.threeOfAKind:
        return _indicesNotIn(hand, _topCountValues(hand, 3));

      // ツーペア：4枚を残して1枚交換
      case HandRank.twoPair:
        return _indicesNotIn(hand, _topCountValues(hand, 2));

      // ワンペア：ペアの2枚を残して3枚交換
      case HandRank.onePair:
        return _indicesNotIn(hand, _topCountValues(hand, 2));

      // 役なし：一番強いカード1枚だけ残して4枚交換
      case HandRank.highCard:
        return _indicesNotIn(hand, _highestValueSet(hand));
    }
  }

  // 指定した「残す数字の集合」に含まれないカードのインデックスを返す
  static List<int> _indicesNotIn(List<PlayingCard> hand, Set<int> keepValues) {
    final result = <int>[];
    for (int i = 0; i < hand.length; i++) {
      if (!keepValues.contains(hand[i].pokerValue)) {
        result.add(i);
      }
    }
    return result;
  }

  // 「ちょうど count 枚ある数字」を残す対象として集める
  // （ペア=2, スリーカード=3, フォーカード=4）
  static Set<int> _topCountValues(List<PlayingCard> hand, int count) {
    final Map<int, int> counts = {};
    for (final c in hand) {
      counts[c.pokerValue] = (counts[c.pokerValue] ?? 0) + 1;
    }
    return counts.entries
        .where((e) => e.value == count)
        .map((e) => e.key)
        .toSet();
  }

  // 一番強い数字を1つだけ残す（ハイカードのとき用）
  static Set<int> _highestValueSet(List<PlayingCard> hand) {
    int best = 0;
    for (final c in hand) {
      if (c.pokerValue > best) best = c.pokerValue;
    }
    return {best};
  }
}

// ポーカーの役判定（HandEvaluator）と勝敗比較（compareHands）の
// 自動テストです。`flutter test` で実行できます。

import 'package:flutter_test/flutter_test.dart';

import 'package:poker/game/models.dart';
import 'package:poker/game/poker_logic.dart';

// テスト用に「マーク+数字」からカードを作る短縮関数
PlayingCard c(Suit s, int rank) => PlayingCard(suit: s, rank: rank);

void main() {
  group('役判定', () {
    test('ロイヤルストレートフラッシュ', () {
      final hand = [
        c(Suit.spades, 1), // A
        c(Suit.spades, 13), // K
        c(Suit.spades, 12), // Q
        c(Suit.spades, 11), // J
        c(Suit.spades, 10), // 10
      ];
      expect(HandEvaluator.evaluate(hand).rank, HandRank.royalFlush);
    });

    test('ストレートフラッシュ', () {
      final hand = [
        c(Suit.hearts, 9),
        c(Suit.hearts, 8),
        c(Suit.hearts, 7),
        c(Suit.hearts, 6),
        c(Suit.hearts, 5),
      ];
      expect(HandEvaluator.evaluate(hand).rank, HandRank.straightFlush);
    });

    test('A-2-3-4-5 のホイールはストレート', () {
      final hand = [
        c(Suit.spades, 1), // A
        c(Suit.hearts, 2),
        c(Suit.clubs, 3),
        c(Suit.diamonds, 4),
        c(Suit.spades, 5),
      ];
      expect(HandEvaluator.evaluate(hand).rank, HandRank.straight);
    });

    test('フォーカード', () {
      final hand = [
        c(Suit.spades, 7),
        c(Suit.hearts, 7),
        c(Suit.clubs, 7),
        c(Suit.diamonds, 7),
        c(Suit.spades, 2),
      ];
      expect(HandEvaluator.evaluate(hand).rank, HandRank.fourOfAKind);
    });

    test('フルハウス', () {
      final hand = [
        c(Suit.spades, 10),
        c(Suit.hearts, 10),
        c(Suit.clubs, 10),
        c(Suit.diamonds, 4),
        c(Suit.spades, 4),
      ];
      expect(HandEvaluator.evaluate(hand).rank, HandRank.fullHouse);
    });

    test('フラッシュ', () {
      final hand = [
        c(Suit.clubs, 2),
        c(Suit.clubs, 5),
        c(Suit.clubs, 9),
        c(Suit.clubs, 11),
        c(Suit.clubs, 13),
      ];
      expect(HandEvaluator.evaluate(hand).rank, HandRank.flush);
    });

    test('ツーペア', () {
      final hand = [
        c(Suit.spades, 8),
        c(Suit.hearts, 8),
        c(Suit.clubs, 3),
        c(Suit.diamonds, 3),
        c(Suit.spades, 13),
      ];
      expect(HandEvaluator.evaluate(hand).rank, HandRank.twoPair);
    });

    test('ハイカード', () {
      final hand = [
        c(Suit.spades, 2),
        c(Suit.hearts, 5),
        c(Suit.clubs, 9),
        c(Suit.diamonds, 11),
        c(Suit.spades, 13),
      ];
      expect(HandEvaluator.evaluate(hand).rank, HandRank.highCard);
    });
  });

  group('勝敗比較', () {
    test('強い役が勝つ（フラッシュ > ストレート）', () {
      final flush = HandEvaluator.evaluate([
        c(Suit.clubs, 2),
        c(Suit.clubs, 5),
        c(Suit.clubs, 9),
        c(Suit.clubs, 11),
        c(Suit.clubs, 13),
      ]);
      final straight = HandEvaluator.evaluate([
        c(Suit.spades, 9),
        c(Suit.hearts, 8),
        c(Suit.clubs, 7),
        c(Suit.diamonds, 6),
        c(Suit.spades, 5),
      ]);
      expect(compareHands(flush, straight) > 0, isTrue);
    });

    test('同じワンペアはキッカーで決まる', () {
      // どちらも K のペア。キッカーが強い方が勝ち。
      final strong = HandEvaluator.evaluate([
        c(Suit.spades, 13),
        c(Suit.hearts, 13),
        c(Suit.clubs, 12), // Q キッカー
        c(Suit.diamonds, 5),
        c(Suit.spades, 2),
      ]);
      final weak = HandEvaluator.evaluate([
        c(Suit.diamonds, 13),
        c(Suit.clubs, 13),
        c(Suit.hearts, 10), // 10 キッカー
        c(Suit.spades, 5),
        c(Suit.hearts, 2),
      ]);
      expect(compareHands(strong, weak) > 0, isTrue);
    });

    test('完全に同じ強さは引き分け（0）', () {
      final a = HandEvaluator.evaluate([
        c(Suit.spades, 10),
        c(Suit.hearts, 10),
        c(Suit.clubs, 4),
        c(Suit.diamonds, 7),
        c(Suit.spades, 9),
      ]);
      final b = HandEvaluator.evaluate([
        c(Suit.clubs, 10),
        c(Suit.diamonds, 10),
        c(Suit.hearts, 4),
        c(Suit.spades, 7),
        c(Suit.clubs, 9),
      ]);
      expect(compareHands(a, b), 0);
    });
  });
}

## 完了

* Flutter（Web）プロジェクトの初期化（パッケージ名 `poker`）
* データ定義（カード・役・役判定結果・参加者・ゲーム状態）
* ポーカーロジック（山札・役判定・勝敗比較・CPU交換AI）
* カード表示ウィジェット（表／裏＋めくりアニメ＋交換選択ハイライト）
* テーブル背景の描画（緑フェルト＋楕円卓）
* ゲーム本体（BET → CHANGE（交換）→ CPU交換 → SHOWDOWN → 精算 → 5戦 → 最終結果）
* Enterキー操作（各フェーズの主ボタンを実行）
* スタート／最終結果オーバーレイ（開始・再戦フロー）
* `flutter analyze` クリア / テスト合格（widget＋役判定11件）/ Webビルド成功

## 作業中

* 動作確認・調整（ブラウザでのプレイ感の確認）

## 未着手

### Phase 2 強化: 物理挙動
* [ ] カード配布アニメーション（今は即配り＋めくりアニメのみ）
* [ ] カード交換アニメーション
* [ ] チップ移動アニメーション

### Phase 4: ブラッシュアップ
* [ ] 効果音の実装（配る・めくる・勝敗）
* [ ] 勝利演出・敗北演出
* [ ] Web版としての最適化
* [ ] CPU交換AIの強化（ストレート/フラッシュ狙いの判断など）

## メモ
* 起動: `run.bat` をダブルクリック（または `flutter run -d chrome`）
* 主要コード:
  * `lib/main.dart` … 入口・テーマ
  * `lib/game/models.dart` … データ定義（カード・役・参加者・状態）
  * `lib/game/poker_logic.dart` … 山札・役判定・勝敗比較・CPU交換AI
  * `lib/game/game_screen.dart` … ゲーム本体（進行・操作・画面）
  * `lib/game/playing_card_widget.dart` … カード1枚の描画（めくり＋選択）
  * `lib/game/table_painter.dart` … テーブル背景の描画
* テスト:
  * `test/widget_test.dart` … 開始画面の表示
  * `test/poker_logic_test.dart` … 役判定・勝敗比較

// =============================================================
// game_screen.dart
// ポーカー（5カードドロー）の本体。画面表示と進行（フェーズ）を
// ひとつの State でまとめて管理します。
//
// 進行の流れ：
//   ready（開始前）
//     → betting（掛け金を決めて配る：BET）
//     → playerDraw（交換するカードを選ぶ：CHANGE）
//     → cpuDraw（CPUが自動で交換）
//     → showdownReady（勝負ボタン待ち：SHOWDOWN）
//     → roundResult（役判定・勝敗・精算）
//     →（5戦まで betting に戻る）→ gameOver（最終結果）
//
// ベットは「同額ポット方式」：あなたの掛け金 B に CPU も同額 B を出し、
// 勝者がポット(2B)を獲得（実質 勝ち+B / 負け-B / 引き分けは返還）。
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'playing_card_widget.dart';
import 'poker_logic.dart';
import 'table_painter.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // ---- 設定値（調整したいときはここを変える）----
  static const int totalRounds = 5; // 何戦行うか
  static const int startChips = 100; // 各自の開始チップ
  static const int betStep = 10; // 掛け金の刻み
  static const int minBet = 10; // 最低掛け金
  static const int handSize = 5; // 配る枚数

  // ---- ゲームの状態 ----
  late Deck _deck;
  late Participant _you;
  late Participant _cpu;

  GamePhase _phase = GamePhase.ready;
  int _round = 1;
  int _selectedBet = minBet;
  final Set<int> _exchangeSelection = {}; // 交換に選んだカードの位置
  bool _busy = false; // 自動進行中（連打防止）

  // Enterキー操作のためのフォーカス
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _setupNewGame();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // 現在のポット（掛け金の合計）
  int get _pot => _you.bet + _cpu.bet;

  // -----------------------------------------------------------
  // 初期化・開始
  // -----------------------------------------------------------
  void _setupNewGame() {
    _deck = Deck();
    _you = Participant(name: 'あなた', isHuman: true, chips: startChips);
    _cpu = Participant(name: 'CPU', isHuman: false, chips: startChips);
    _round = 1;
    _selectedBet = minBet;
    _exchangeSelection.clear();
    _busy = false;
    _phase = GamePhase.ready;
  }

  void _startGame() {
    setState(() {
      _setupNewGame();
      _phase = GamePhase.betting;
      _selectedBet = _clampBet(minBet);
    });
  }

  // -----------------------------------------------------------
  // 掛け金（BET）
  // -----------------------------------------------------------
  // 上限は設けない（持ち点を超えて賭けられる。負けるとマイナスもあり得る）
  int _clampBet(int value) => value < minBet ? minBet : value;

  void _changeBet(int delta) {
    setState(() => _selectedBet = _clampBet(_selectedBet + delta));
  }

  // 掛け金を確定 → 5枚ずつ配る。CPUは同額をポットに出す。
  void _placeBetAndDeal() {
    _you.bet = _clampBet(_selectedBet);
    _cpu.bet = _you.bet; // 同額ポット

    // あなたは表向き、CPUは裏向きで配る
    _you.hand = List.generate(handSize, (_) => _deck.draw(faceUp: true));
    _cpu.hand = List.generate(handSize, (_) => _deck.draw(faceUp: false));

    setState(() {
      _exchangeSelection.clear();
      _phase = GamePhase.playerDraw;
    });
  }

  // -----------------------------------------------------------
  // カード交換（CHANGE）
  // -----------------------------------------------------------
  // playerDraw 中、カードをタップして交換対象を選ぶ／外す
  void _toggleCardSelection(int index) {
    if (_phase != GamePhase.playerDraw) return;
    setState(() {
      if (_exchangeSelection.contains(index)) {
        _exchangeSelection.remove(index);
      } else {
        _exchangeSelection.add(index);
      }
    });
  }

  // 選んだカードを交換し、続けてCPUが自動で交換する
  Future<void> _onChange() async {
    if (_phase != GamePhase.playerDraw || _busy) return;
    _busy = true;

    // あなたの選んだカードを引き直す
    setState(() {
      for (final i in _exchangeSelection) {
        _you.hand[i] = _deck.draw(faceUp: true);
      }
      _exchangeSelection.clear();
      _phase = GamePhase.cpuDraw;
    });

    // 少し間を置いてCPUの交換（裏向きのまま入れ替え）
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final discard = CpuAi.cardsToExchange(_cpu.hand);
    setState(() {
      for (final i in discard) {
        _cpu.hand[i] = _deck.draw(faceUp: false);
      }
      _phase = GamePhase.showdownReady;
    });
    _busy = false;
  }

  // -----------------------------------------------------------
  // 勝負（SHOWDOWN）
  // -----------------------------------------------------------
  void _onShowdown() {
    if (_phase != GamePhase.showdownReady) return;

    // CPUの手札を表にする（めくりアニメが走る）
    for (final c in _cpu.hand) {
      c.faceUp = true;
    }
    _settleRound();
  }

  // 役判定 → 勝敗 → チップ精算
  void _settleRound() {
    final youResult = HandEvaluator.evaluate(_you.hand);
    final cpuResult = HandEvaluator.evaluate(_cpu.hand);
    _you.result = youResult;
    _cpu.result = cpuResult;

    final cmp = compareHands(youResult, cpuResult);
    if (cmp > 0) {
      // あなたの勝ち：CPUの掛け金ぶん獲得
      _you.outcome = RoundOutcome.win;
      _cpu.outcome = RoundOutcome.lose;
      _you.chips += _cpu.bet;
      _cpu.chips -= _cpu.bet;
    } else if (cmp < 0) {
      // CPUの勝ち
      _you.outcome = RoundOutcome.lose;
      _cpu.outcome = RoundOutcome.win;
      _you.chips -= _you.bet;
      _cpu.chips += _you.bet;
    } else {
      // 引き分け：掛け金は返還（増減なし）
      _you.outcome = RoundOutcome.push;
      _cpu.outcome = RoundOutcome.push;
    }

    setState(() => _phase = GamePhase.roundResult);
  }

  // -----------------------------------------------------------
  // 次のラウンドへ
  // -----------------------------------------------------------
  void _nextRound() {
    if (_round >= totalRounds) {
      setState(() => _phase = GamePhase.gameOver);
      return;
    }
    _round++;
    _you.resetForNewRound();
    _cpu.resetForNewRound();
    setState(() {
      _selectedBet = _clampBet(minBet);
      _exchangeSelection.clear();
      _phase = GamePhase.betting;
    });
  }

  // -----------------------------------------------------------
  // Enterキー：今のフェーズの「主ボタン」を押す
  // -----------------------------------------------------------
  void _onEnter() {
    switch (_phase) {
      case GamePhase.ready:
        _startGame();
        break;
      case GamePhase.betting:
        _placeBetAndDeal();
        break;
      case GamePhase.playerDraw:
        _onChange();
        break;
      case GamePhase.showdownReady:
        _onShowdown();
        break;
      case GamePhase.roundResult:
        _nextRound();
        break;
      case GamePhase.gameOver:
        _startGame();
        break;
      case GamePhase.cpuDraw:
        break; // 自動進行中は何もしない
    }
  }

  // ===========================================================
  // 画面の組み立て
  // ===========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // KeyboardListener で Enter を拾う
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
            _onEnter();
          }
        },
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: TablePainter())),
            SafeArea(child: _buildTable()),
            if (_phase == GamePhase.ready) _buildStartOverlay(),
            if (_phase == GamePhase.gameOver) _buildResultOverlay(),
          ],
        ),
      ),
    );
  }

  // テーブル全体（上：CPU / 中央：ポット / 下：あなた / 操作パネル）
  Widget _buildTable() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSeat(_cpu, isOpponent: true),
              _buildCenter(),
              _buildSeat(_you, isOpponent: false),
            ],
          ),
        ),
        _buildControlPanel(),
      ],
    );
  }

  // 画面上部：ラウンド表示
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.casino, color: Colors.amber, size: 20),
          const SizedBox(width: 8),
          Text(
            '第 $_round 戦  /  全 $totalRounds 戦',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // 中央：ポット表示
  Widget _buildCenter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.savings, color: Colors.amberAccent, size: 22),
        const SizedBox(height: 2),
        Text(
          'POT  $_pot',
          style: const TextStyle(
            color: Colors.amberAccent,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // 1人ぶんの座席（名前・チップ・ベット・役・手札）
  Widget _buildSeat(Participant p, {required bool isOpponent}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 相手は手札を上、自分は名札を上にして「向かい合う」見た目にする
        if (isOpponent) ...[
          FittedBox(fit: BoxFit.scaleDown, child: _buildHandRow(p)),
          const SizedBox(height: 6),
          FittedBox(fit: BoxFit.scaleDown, child: _buildNamePlate(p)),
        ] else ...[
          FittedBox(fit: BoxFit.scaleDown, child: _buildNamePlate(p)),
          const SizedBox(height: 6),
          FittedBox(fit: BoxFit.scaleDown, child: _buildHandRow(p)),
        ],
      ],
    );
  }

  // 名札（名前・チップ・ベット・役・勝敗バッジ）
  Widget _buildNamePlate(Participant p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            p.name,
            style: TextStyle(
              color: p.isHuman ? Colors.lightBlueAccent : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 10),
          Text('💰${p.chips}',
              style: const TextStyle(color: Colors.white, fontSize: 14)),
          if (p.bet > 0) ...[
            const SizedBox(width: 8),
            Text('賭け${p.bet}',
                style:
                    const TextStyle(color: Colors.orangeAccent, fontSize: 14)),
          ],
          // 役（ショーダウン後のみ）
          if (p.result != null && _phase == GamePhase.roundResult) ...[
            const SizedBox(width: 10),
            Text(
              p.result!.rank.label,
              style: const TextStyle(color: Colors.amber, fontSize: 14),
            ),
          ],
          // 勝敗バッジ
          if (p.outcome != null && _phase == GamePhase.roundResult) ...[
            const SizedBox(width: 8),
            _outcomeBadge(p.outcome!),
          ],
        ],
      ),
    );
  }

  Widget _outcomeBadge(RoundOutcome outcome) {
    late final String label;
    late final Color color;
    switch (outcome) {
      case RoundOutcome.win:
        label = 'WIN';
        color = Colors.green;
        break;
      case RoundOutcome.lose:
        label = 'LOSE';
        color = Colors.red;
        break;
      case RoundOutcome.push:
        label = 'PUSH';
        color = Colors.blueGrey;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  // 手札を横に並べる。あなたの番(playerDraw)だけタップで交換選択できる。
  Widget _buildHandRow(Participant p) {
    final selectable = p.isHuman && _phase == GamePhase.playerDraw;
    final cardWidth = p.isHuman ? 60.0 : 48.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < p.hand.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: PlayingCardWidget(
              card: p.hand[i],
              width: cardWidth,
              selected: selectable && _exchangeSelection.contains(i),
              onTap: selectable ? () => _toggleCardSelection(i) : null,
            ),
          ),
      ],
    );
  }

  // -----------------------------------------------------------
  // 画面下部の操作パネル（フェーズで中身が変わる）
  // -----------------------------------------------------------
  Widget _buildControlPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      color: Colors.black.withValues(alpha: 0.25),
      child: _controlContent(),
    );
  }

  Widget _controlContent() {
    switch (_phase) {
      case GamePhase.betting:
        return _bettingControls();
      case GamePhase.playerDraw:
        return _drawControls();
      case GamePhase.cpuDraw:
        return _statusText('CPU が交換しています…');
      case GamePhase.showdownReady:
        return _showdownControls();
      case GamePhase.roundResult:
        return _resultControls();
      case GamePhase.ready:
      case GamePhase.gameOver:
        return const SizedBox(height: 8); // オーバーレイ側で操作
    }
  }

  Widget _statusText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 16)),
    );
  }

  // BET：掛け金選択
  Widget _bettingControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('掛け金を決めてください',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        const Text('※ 持ち点を超えて賭けられます（負けるとマイナスになります）',
            style: TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _roundButton(Icons.remove, () => _changeBet(-betStep)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('$_selectedBet',
                  style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
            ),
            _roundButton(Icons.add, () => _changeBet(betStep)),
          ],
        ),
        const SizedBox(height: 10),
        _mainButton('BET（カードを配る）', Icons.style, _placeBetAndDeal),
      ],
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white24,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  // CHANGE：交換
  Widget _drawControls() {
    final count = _exchangeSelection.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count == 0
              ? '交換したいカードをタップ（無ければそのままCHANGE）'
              : '$count 枚を交換します',
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        const SizedBox(height: 10),
        _mainButton('CHANGE（交換）', Icons.swap_horiz, _onChange),
      ],
    );
  }

  // SHOWDOWN：勝負
  Widget _showdownControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('カードを公開して勝負！',
            style: TextStyle(color: Colors.white, fontSize: 15)),
        const SizedBox(height: 10),
        _mainButton('SHOWDOWN（勝負）', Icons.visibility, _onShowdown),
      ],
    );
  }

  // 結果：次の戦へ
  Widget _resultControls() {
    final isLast = _round >= totalRounds;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'あなた：${_outcomeWord(_you.outcome)}（${_you.result?.rank.label ?? ''}）',
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        const SizedBox(height: 8),
        _mainButton(isLast ? '最終結果を見る' : '次の戦へ', Icons.arrow_forward,
            _nextRound),
      ],
    );
  }

  // 大きめの主ボタン（共通デザイン）
  Widget _mainButton(String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _outcomeWord(RoundOutcome? o) {
    switch (o) {
      case RoundOutcome.win:
        return '勝ち';
      case RoundOutcome.lose:
        return '負け';
      case RoundOutcome.push:
        return '引き分け';
      case null:
        return '-';
    }
  }

  // -----------------------------------------------------------
  // オーバーレイ（開始前 / 最終結果）
  // -----------------------------------------------------------
  Widget _buildStartOverlay() {
    return _overlayBox(
      title: '♠ ポーカー ♦',
      lines: const [
        '5カードドロー・全5戦',
        '持ち点100スタート・CPUと勝負',
        'カードを交換して強い役を作ろう',
      ],
      buttonLabel: 'Start Game',
      onPressed: _startGame,
    );
  }

  Widget _buildResultOverlay() {
    final String verdict;
    if (_you.chips > _cpu.chips) {
      verdict = '🎉 あなたの勝ち！';
    } else if (_you.chips < _cpu.chips) {
      verdict = '😢 CPU の勝ち…';
    } else {
      verdict = '🤝 引き分け';
    }
    return _overlayBox(
      title: verdict,
      lines: [
        'あなたの持ち点：${_you.chips}',
        'CPU の持ち点：${_cpu.chips}',
      ],
      buttonLabel: 'Restart',
      onPressed: _startGame,
    );
  }

  Widget _overlayBox({
    required String title,
    required List<String> lines,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(line,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 16)),
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: Text(buttonLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

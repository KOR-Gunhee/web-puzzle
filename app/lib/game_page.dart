import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'jigsaw.dart';
import 'sound.dart';

const _difficulties = {
  2: '4조각 (아기)',
  3: '9조각 (쉬움)',
  4: '16조각 (보통)',
  5: '25조각 (어려움)',
  6: '36조각 (고수)',
};

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final _rng = Random();
  final _sfx = Sfx();
  final _confetti = ConfettiController(duration: const Duration(seconds: 3));
  final _stopwatch = Stopwatch();
  Timer? _ticker;

  Uint8List? _bytes;
  ui.Image? _image;
  int _grid = 3;
  bool _guideOn = true;

  bool _started = false;
  List<List<PieceShape>> _shapes = [];
  final Set<int> _placed = {};
  List<int> _queue = []; // 아직 놓지 않은 조각 번호(y*grid+x). 맨 앞이 현재 조각.

  bool _dragging = false;
  Offset? _dragPos; // null이면 트레이 위 기본 위치

  int get _total => _grid * _grid;

  @override
  void dispose() {
    _ticker?.cancel();
    _confetti.dispose();
    _sfx.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    try {
      final bytes = await file.readAsBytes();
      final descriptor =
          await ui.ImageDescriptor.encoded(await ui.ImmutableBuffer.fromUint8List(bytes));
      final codec = await descriptor.instantiateCodec(
          targetWidth: min(descriptor.width, 1600));
      final frame = await codec.getNextFrame();
      _resetGame();
      setState(() {
        _bytes = bytes;
        _image = frame.image;
      });
    } catch (_) {
      _message('이미지 파일을 읽지 못했어요.');
    }
  }

  void _resetGame() {
    _ticker?.cancel();
    _stopwatch
      ..stop()
      ..reset();
    _started = false;
    _placed.clear();
    _queue = [];
    _dragPos = null;
    _dragging = false;
  }

  void _start() {
    if (_image == null) {
      _message('먼저 사진을 불러와주세요.');
      return;
    }
    setState(() {
      _resetGame();
      _shapes = generateShapes(_grid, _rng);
      _queue = List.generate(_total, (i) => i)..shuffle(_rng);
      _started = true;
    });
    _stopwatch.start();
    _ticker = Timer.periodic(
        const Duration(seconds: 1), (_) => setState(() {}));
  }

  String get _timeText {
    final s = _stopwatch.elapsed.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  void _message(String text) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(text, textAlign: TextAlign.center),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('확인'))
        ],
      ),
    );
  }

  void _showPreview() {
    if (_bytes == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: Stack(children: [
          Padding(
              padding: const EdgeInsets.all(8), child: Image.memory(_bytes!)),
          Positioned(
              right: 0,
              top: 0,
              child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context))),
        ]),
      ),
    );
  }

  void _onDrop(PuzzleGeometry g, Offset boardOrigin, Offset piecePos) {
    final idx = _queue.first;
    final gx = idx % _grid, gy = idx ~/ _grid;
    final target = boardOrigin +
        Offset(gx * g.pieceW - g.pad, gy * g.pieceH - g.pad);
    final threshold = max(24.0, min(g.pieceW, g.pieceH) * 0.3);

    if ((piecePos - target).distance < threshold) {
      setState(() {
        _placed.add(idx);
        _queue.removeAt(0);
        _dragging = false;
        _dragPos = null;
      });
      if (_queue.isEmpty) {
        _finish();
      } else {
        _sfx.snap();
      }
    } else {
      setState(() {
        _dragging = false;
        _dragPos = null; // 트레이로 복귀
      });
      _sfx.wrong();
    }
  }

  void _finish() {
    _stopwatch.stop();
    _ticker?.cancel();
    _sfx.tada();
    _confetti.play();
    final time = _timeText;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _message('🎉 완벽해요! 🎉\n소요 시간: $time\n다른 난이도로 다시 도전해보세요!');
      }
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(children: [
          _buildControls(),
          _buildStatus(),
          Expanded(child: _buildPlayArea()),
        ]),
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.center,
        children: [
          FilledButton.tonalIcon(
            onPressed: _pickImage,
            icon: const Icon(Icons.photo_library),
            label: const Text('사진'),
          ),
          DropdownButton<int>(
            value: _grid,
            underline: const SizedBox.shrink(),
            items: [
              for (final e in _difficulties.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _grid = v;
                _resetGame();
              });
            },
          ),
          IconButton.filledTonal(
            tooltip: _guideOn ? '가이드 끄기' : '가이드 켜기',
            isSelected: _guideOn,
            onPressed: () => setState(() => _guideOn = !_guideOn),
            icon: const Icon(Icons.lightbulb_outline),
            selectedIcon: const Icon(Icons.lightbulb),
          ),
          IconButton.filledTonal(
            tooltip: '완성 그림',
            onPressed: _bytes == null ? null : _showPreview,
            icon: const Icon(Icons.visibility),
          ),
          FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('퍼즐 섞기'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatus() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text('⏱ $_timeText   |   🧩 ${_placed.length} / ${_started ? _total : 0}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildPlayArea() {
    final image = _image;
    if (image == null) {
      return const Center(
          child: Text('사진을 불러와 퍼즐을 시작해보세요', style: TextStyle(fontSize: 16)));
    }

    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth, h = c.maxHeight;
      final trayH = _started ? (h * 0.26).clamp(90.0, 220.0) : 0.0;
      final areaW = w - 16, areaH = h - trayH - 16;
      final scale = min(areaW / image.width, areaH / image.height);
      final bw = image.width * scale, bh = image.height * scale;
      final g = PuzzleGeometry(_grid, bw, bh);
      final boardOrigin = Offset((w - bw) / 2, (h - trayH - bh) / 2);

      Widget? piece;
      if (_started && _queue.isNotEmpty) {
        final idx = _queue.first;
        final size = g.pieceCanvasSize;
        final home = Offset((w - size.width) / 2, h - trayH / 2 - size.height / 2);
        final pos = _dragPos ?? home;
        piece = AnimatedPositioned(
          key: ValueKey('${_grid}_$idx'),
          duration: _dragging ? Duration.zero : const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          left: pos.dx,
          top: pos.dy,
          width: size.width,
          height: size.height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => setState(() {
              _dragging = true;
              _dragPos = pos;
            }),
            onPanUpdate: (d) {
              final next = (_dragPos ?? pos) + d.delta;
              setState(() {
                _dragPos = Offset(
                  next.dx.clamp(-size.width + 50, w - 50),
                  next.dy.clamp(-size.height + 50, h - 50),
                );
              });
            },
            onPanEnd: (_) => _onDrop(g, boardOrigin, _dragPos ?? pos),
            onPanCancel: () => setState(() {
              _dragging = false;
              _dragPos = null;
            }),
            child: CustomPaint(
              size: size,
              painter: _PiecePainter(image, g, idx % _grid, idx ~/ _grid,
                  _shapes[idx ~/ _grid][idx % _grid], _dragging),
            ),
          ),
        );
      }

      return Stack(clipBehavior: Clip.none, children: [
        if (_started)
          Positioned(
            left: 8,
            right: 8,
            bottom: 4,
            height: trayH - 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('남은 조각 ${_queue.length}개',
                      style: const TextStyle(color: Colors.black45, fontSize: 12)),
                ),
              ),
            ),
          ),
        Positioned(
          left: boardOrigin.dx,
          top: boardOrigin.dy,
          width: bw,
          height: bh,
          child: CustomPaint(
            painter: _BoardPainter(image, g, _started ? _shapes : null,
                Set.of(_placed), _guideOn),
          ),
        ),
        ?piece,
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 30,
            gravity: 0.2,
          ),
        ),
      ]);
    });
  }
}

class _PiecePainter extends CustomPainter {
  final ui.Image image;
  final PuzzleGeometry g;
  final int gx, gy;
  final PieceShape shape;
  final bool lifted;

  _PiecePainter(this.image, this.g, this.gx, this.gy, this.shape, this.lifted);

  @override
  void paint(Canvas canvas, Size size) {
    if (lifted) {
      canvas.save();
      canvas.translate(g.pad + 2, g.pad + 4);
      canvas.drawPath(
          buildJigsawPath(g.pieceW, g.pieceH, shape, g.tab),
          Paint()
            ..color = const Color(0x55000000)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.restore();
    }
    paintPiece(canvas, image, g, gx, gy, shape);
  }

  @override
  bool shouldRepaint(_PiecePainter old) =>
      old.gx != gx || old.gy != gy || old.lifted != lifted || old.g.boardW != g.boardW;
}

class _BoardPainter extends CustomPainter {
  final ui.Image image;
  final PuzzleGeometry g;
  final List<List<PieceShape>>? shapes;
  final Set<int> placed;
  final bool guide;

  _BoardPainter(this.image, this.g, this.shapes, this.placed, this.guide);

  @override
  void paint(Canvas canvas, Size size) {
    final board = Offset.zero & size;
    canvas.drawRect(board, Paint()..color = Colors.white);

    if (guide) {
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        board,
        Paint()
          ..color = const Color(0x40FFFFFF) // 알파 25%로 연하게
          ..filterQuality = FilterQuality.medium,
      );
    }

    final s = shapes;
    if (s != null) {
      final line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0x66808080);
      for (var y = 0; y < g.grid; y++) {
        for (var x = 0; x < g.grid; x++) {
          if (placed.contains(y * g.grid + x)) continue;
          canvas.save();
          canvas.translate(x * g.pieceW, y * g.pieceH);
          canvas.drawPath(
              buildJigsawPath(g.pieceW, g.pieceH, s[y][x], g.tab), line);
          canvas.restore();
        }
      }
      for (final i in placed) {
        final x = i % g.grid, y = i ~/ g.grid;
        canvas.save();
        canvas.translate(x * g.pieceW - g.pad, y * g.pieceH - g.pad);
        paintPiece(canvas, image, g, x, y, s[y][x]);
        canvas.restore();
      }
    }

    canvas.drawRect(
        board,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF94A3B8));
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.placed.length != placed.length ||
      old.guide != guide ||
      old.shapes != shapes ||
      old.g.boardW != g.boardW ||
      old.g.boardH != g.boardH ||
      old.image != image;
}

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 조각 네 변의 모양. 0=평평, 1=바깥으로 돌출, -1=안쪽으로 파임.
class PieceShape {
  final int top, right, bottom, left;
  const PieceShape(this.top, this.right, this.bottom, this.left);
}

List<List<PieceShape>> generateShapes(int grid, Random rng) {
  final tops = List.generate(grid, (_) => List.filled(grid, 0));
  final rights = List.generate(grid, (_) => List.filled(grid, 0));
  final bottoms = List.generate(grid, (_) => List.filled(grid, 0));
  final lefts = List.generate(grid, (_) => List.filled(grid, 0));

  for (var y = 0; y < grid; y++) {
    for (var x = 0; x < grid; x++) {
      if (y > 0) tops[y][x] = -bottoms[y - 1][x];
      if (x > 0) lefts[y][x] = -rights[y][x - 1];
      if (x < grid - 1) rights[y][x] = rng.nextBool() ? 1 : -1;
      if (y < grid - 1) bottoms[y][x] = rng.nextBool() ? 1 : -1;
    }
  }
  return List.generate(
    grid,
    (y) => List.generate(
        grid, (x) => PieceShape(tops[y][x], rights[y][x], bottoms[y][x], lefts[y][x])),
  );
}

/// 조각 윤곽 경로. 원점은 조각 본체의 왼쪽 위 모서리, t는 돌기 크기.
Path buildJigsawPath(double w, double h, PieceShape s, double t) {
  final cx = w / 2, cy = h / 2;
  final neck = t * 0.45;
  final bulbW = t * 0.9;
  final bulbH = t;
  final p = Path()..moveTo(0, 0);

  if (s.top == 0) {
    p.lineTo(w, 0);
  } else {
    final k = s.top.toDouble();
    p.lineTo(cx - neck, 0);
    p.cubicTo(cx - neck, -bulbH * 0.1 * k, cx - bulbW, -bulbH * 0.3 * k,
        cx - bulbW, -bulbH * 0.6 * k);
    p.cubicTo(cx - bulbW, -bulbH * 1.15 * k, cx + bulbW, -bulbH * 1.15 * k,
        cx + bulbW, -bulbH * 0.6 * k);
    p.cubicTo(cx + bulbW, -bulbH * 0.3 * k, cx + neck, -bulbH * 0.1 * k,
        cx + neck, 0);
    p.lineTo(w, 0);
  }

  if (s.right == 0) {
    p.lineTo(w, h);
  } else {
    final k = s.right.toDouble();
    p.lineTo(w, cy - neck);
    p.cubicTo(w + bulbH * 0.1 * k, cy - neck, w + bulbH * 0.3 * k, cy - bulbW,
        w + bulbH * 0.6 * k, cy - bulbW);
    p.cubicTo(w + bulbH * 1.15 * k, cy - bulbW, w + bulbH * 1.15 * k,
        cy + bulbW, w + bulbH * 0.6 * k, cy + bulbW);
    p.cubicTo(w + bulbH * 0.3 * k, cy + bulbW, w + bulbH * 0.1 * k, cy + neck,
        w, cy + neck);
    p.lineTo(w, h);
  }

  if (s.bottom == 0) {
    p.lineTo(0, h);
  } else {
    final k = s.bottom.toDouble();
    p.lineTo(cx + neck, h);
    p.cubicTo(cx + neck, h + bulbH * 0.1 * k, cx + bulbW, h + bulbH * 0.3 * k,
        cx + bulbW, h + bulbH * 0.6 * k);
    p.cubicTo(cx + bulbW, h + bulbH * 1.15 * k, cx - bulbW,
        h + bulbH * 1.15 * k, cx - bulbW, h + bulbH * 0.6 * k);
    p.cubicTo(cx - bulbW, h + bulbH * 0.3 * k, cx - neck, h + bulbH * 0.1 * k,
        cx - neck, h);
    p.lineTo(0, h);
  }

  if (s.left == 0) {
    p.lineTo(0, 0);
  } else {
    final k = s.left.toDouble();
    p.lineTo(0, cy + neck);
    p.cubicTo(-bulbH * 0.1 * k, cy + neck, -bulbH * 0.3 * k, cy + bulbW,
        -bulbH * 0.6 * k, cy + bulbW);
    p.cubicTo(-bulbH * 1.15 * k, cy + bulbW, -bulbH * 1.15 * k, cy - bulbW,
        -bulbH * 0.6 * k, cy - bulbW);
    p.cubicTo(-bulbH * 0.3 * k, cy - bulbW, -bulbH * 0.1 * k, cy - neck, 0,
        cy - neck);
    p.lineTo(0, 0);
  }
  p.close();
  return p;
}

/// 보드 위의 배치 정보. 보드 좌표계(픽셀) 기준.
class PuzzleGeometry {
  final int grid;
  final double boardW, boardH;
  late final double pieceW = boardW / grid;
  late final double pieceH = boardH / grid;
  late final double tab = min(pieceW, pieceH) * 0.22;
  late final double pad = tab * 1.5;

  PuzzleGeometry(this.grid, this.boardW, this.boardH);

  Size get pieceCanvasSize => Size(pieceW + pad * 2, pieceH + pad * 2);
}

/// 이미지를 조각 모양으로 잘라 (0,0)에서 pad만큼 안쪽에 그린다.
void paintPiece(Canvas canvas, ui.Image image, PuzzleGeometry g, int gx,
    int gy, PieceShape shape) {
  final path = buildJigsawPath(g.pieceW, g.pieceH, shape, g.tab);
  final sx = image.width / g.boardW, sy = image.height / g.boardH;
  final tx = gx * g.pieceW, ty = gy * g.pieceH;

  canvas.save();
  canvas.translate(g.pad, g.pad);
  canvas.clipPath(path, doAntiAlias: true);
  canvas.drawImageRect(
    image,
    Rect.fromLTWH((tx - g.pad) * sx, (ty - g.pad) * sy,
        (g.pieceW + g.pad * 2) * sx, (g.pieceH + g.pad * 2) * sy),
    Rect.fromLTWH(-g.pad, -g.pad, g.pieceW + g.pad * 2, g.pieceH + g.pad * 2),
    Paint()..filterQuality = FilterQuality.medium,
  );
  canvas.restore();

  canvas.save();
  canvas.translate(g.pad, g.pad);
  canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0x4D000000));
  canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x66FFFFFF));
  canvas.restore();
}

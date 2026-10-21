import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

const _sampleRate = 22050;

/// 주파수 변화(f0→f1)와 지수 감쇠 볼륨을 가진 톤을 16bit mono WAV로 만든다.
Uint8List _tone(double f0, double f1, double seconds, double volume,
    {bool triangle = false}) {
  final n = (_sampleRate * seconds).round();
  final data = ByteData(44 + n * 2);
  void str(int off, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(off + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + n * 2, Endian.little);
  str(8, 'WAVEfmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, _sampleRate, Endian.little);
  data.setUint32(28, _sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, n * 2, Endian.little);

  var phase = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / n;
    final freq = f0 * pow(f1 / f0, t);
    phase += 2 * pi * freq / _sampleRate;
    final wave = triangle ? (2 / pi) * asin(sin(phase)) : sin(phase);
    final env = pow(0.03, t); // 1 → 0.03 지수 감쇠
    data.setInt16(44 + i * 2, (wave * env * volume * 32767).round(),
        Endian.little);
  }
  return data.buffer.asUint8List();
}

class Sfx {
  final _snap = _tone(800, 300, 0.1, 0.3);
  final _wrong = _tone(220, 160, 0.15, 0.25);
  final _tada = [440.0, 554.37, 659.25, 880.0]
      .map((f) => _tone(f, f, 0.5, 0.2, triangle: true))
      .toList();
  final _player = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);

  Future<void> snap() => _player.play(BytesSource(_snap));

  Future<void> wrong() => _player.play(BytesSource(_wrong));

  Future<void> tada() async {
    for (final bytes in _tada) {
      final p = AudioPlayer();
      p.onPlayerComplete.listen((_) => p.dispose());
      await p.play(BytesSource(bytes));
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  void dispose() => _player.dispose();
}

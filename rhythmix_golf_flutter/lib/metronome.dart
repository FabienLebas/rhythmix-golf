// Métronome : un cycle complet (départ, sommet, impact, pause) est calculé
// en un fichier WAV puis lu en boucle. Les écarts entre les bips sont donc
// exacts à l'échantillon près, et le son continue écran verrouillé et en
// mode silencieux (session audio « lecture »).

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

const double _lead = 0.3; // petit silence avant le premier bip

Uint8List buildCycleWav(double b, double d, double pause, {int sr = 44100}) {
  final total = ((b + d + pause) * sr).round();
  final buf = Float32List(total);

  void tone(double t0, double f, double len) {
    final s0 = (t0 * sr).round();
    final ns = ((len + 0.05) * sr).round();
    for (var i = 0; i < ns; i++) {
      final idx = s0 + i;
      if (idx >= total) break;
      final t = i / sr;
      double g;
      if (t < 0.005) {
        g = 0.0001 * math.pow(5000, t / 0.005).toDouble();
      } else if (t < len) {
        g = 0.5 * math.pow(0.0002, (t - 0.005) / (len - 0.005)).toDouble();
      } else {
        g = 0.0001;
      }
      buf[idx] += g * math.sin(2 * math.pi * f * t);
    }
  }

  tone(_lead, 660, 0.12); // départ (grave)
  tone(_lead + b, 880, 0.12); // sommet (moyen)
  tone(_lead + b + d, 1320, 0.25); // impact (aigu)

  final bytes = ByteData(44 + total * 2);
  void ws(int o, String s) {
    for (var k = 0; k < s.length; k++) {
      bytes.setUint8(o + k, s.codeUnitAt(k));
    }
  }

  ws(0, 'RIFF');
  bytes.setUint32(4, 36 + total * 2, Endian.little);
  ws(8, 'WAVE');
  ws(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, sr, Endian.little);
  bytes.setUint32(28, sr * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  ws(36, 'data');
  bytes.setUint32(40, total * 2, Endian.little);
  for (var i = 0; i < total; i++) {
    final v = (buf[i] * 1.6).clamp(-1.0, 1.0);
    bytes.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
  }
  return bytes.buffer.asUint8List();
}

class Metronome {
  final AudioPlayer _player = AudioPlayer();
  bool running = false;
  double _b = 0.81, _d = 0.27, _cycle = 4;
  File? _file;

  Future<void> init() async {
    try {
      final s = await AudioSession.instance;
      await s.configure(const AudioSessionConfiguration.music());
    } catch (_) {}
  }

  Future<void> start(double b, double d, double pause) async {
    _b = b;
    _d = d;
    _cycle = b + d + pause;
    running = true;
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/rhythmix_${DateTime.now().microsecondsSinceEpoch}.wav');
    await f.writeAsBytes(buildCycleWav(b, d, pause), flush: true);
    final old = _file;
    _file = f;
    await _player.stop();
    if (!running) return;
    await _player.setFilePath(f.path);
    await _player.setLoopMode(LoopMode.one);
    if (!running) return;
    _player.play();
    if (old != null) {
      try {
        await old.delete();
      } catch (_) {}
    }
  }

  Future<void> stop() async {
    running = false;
    await _player.stop();
  }

  /// Étiquette du temps en cours (pour l'affichage), ou null à l'arrêt.
  String? label() {
    if (!running || !_player.playing || _cycle <= 0) return null;
    final p = _player.position.inMicroseconds / 1e6;
    if (p < _lead) return null;
    final t = (p - _lead) % _cycle;
    if (t < _b) return 'Départ';
    if (t < _b + _d) return 'Sommet';
    return 'Impact';
  }
}

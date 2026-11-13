// Son du métronome : un cycle (départ, sommet, impact, pause) calculé en WAV
// (lib/metronome.dart). Vérifie le format et l'instant exact de chaque bip.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rhythmix_golf/metronome.dart';

const _lead = 0.3; // silence avant le premier bip

/// Amplitude d'une fréquence autour de l'instant t (fenêtre de 40 ms, Goertzel).
double tonePower(ByteData wav, double t, double f, {int sr = 44100}) {
  final s0 = (t * sr).round(), n = (0.04 * sr).round();
  var re = 0.0, im = 0.0;
  for (var i = 0; i < n; i++) {
    final v = wav.getInt16(44 + (s0 + i) * 2, Endian.little) / 32768;
    re += v * math.cos(2 * math.pi * f * i / sr);
    im += v * math.sin(2 * math.pi * f * i / sr);
  }
  return math.sqrt(re * re + im * im) / n;
}

/// Premier échantillon audible après [from] secondes.
double onset(ByteData wav, double from, {int sr = 44100}) {
  final total = (wav.lengthInBytes - 44) ~/ 2;
  for (var i = (from * sr).round(); i < total; i++) {
    if (wav.getInt16(44 + i * 2, Endian.little).abs() > 1000) return i / sr;
  }
  return double.infinity;
}

void main() {
  group('buildCycleWav', () {
    final bytes = buildCycleWav(0.81, 0.27, 3);
    final wav = ByteData.sublistView(bytes);
    String tag(int o) => String.fromCharCodes(bytes.sublist(o, o + 4));

    test('en-tête WAV PCM 16 bits mono 44,1 kHz', () {
      expect(tag(0), 'RIFF');
      expect(tag(8), 'WAVE');
      expect(tag(12), 'fmt ');
      expect(tag(36), 'data');
      expect(wav.getUint16(20, Endian.little), 1); // PCM
      expect(wav.getUint16(22, Endian.little), 1); // mono
      expect(wav.getUint32(24, Endian.little), 44100);
      expect(wav.getUint16(34, Endian.little), 16);
      expect(wav.getUint32(4, Endian.little), bytes.length - 8);
      expect(wav.getUint32(40, Endian.little), bytes.length - 44);
    });

    test('durée du cycle = montée + descente + pause (lecture en boucle sans dérive)', () {
      final samples = (bytes.length - 44) ~/ 2;
      expect(samples, ((0.81 + 0.27 + 3) * 44100).round());
    });

    test('trois bips aux bons instants : départ, sommet (+ montée), impact (+ descente)', () {
      final t1 = onset(wav, 0), t2 = onset(wav, _lead + 0.81 - 0.01), t3 = onset(wav, _lead + 0.81 + 0.27 - 0.01);
      // l'attaque (rampe de 5 ms) décale un peu le seuil : même décalage pour les 3 bips
      expect(t1, closeTo(_lead, 0.005));
      expect(t2 - t1, closeTo(0.81, 0.002));
      expect(t3 - t2, closeTo(0.27, 0.002));
    });

    test('hauteurs : départ grave 660 Hz, sommet 880 Hz, impact aigu 1320 Hz', () {
      final starts = [_lead, _lead + 0.81, _lead + 0.81 + 0.27];
      final freqs = [660.0, 880.0, 1320.0];
      for (var k = 0; k < 3; k++) {
        final own = tonePower(wav, starts[k] + 0.005, freqs[k]);
        for (var j = 0; j < 3; j++) {
          if (j != k) expect(own, greaterThan(5 * tonePower(wav, starts[k] + 0.005, freqs[j])));
        }
      }
    });

    test('pas de saturation, silence pendant la pause', () {
      final samples = (bytes.length - 44) ~/ 2;
      var peak = 0;
      for (var i = 0; i < samples; i++) {
        peak = math.max(peak, wav.getInt16(44 + i * 2, Endian.little).abs());
      }
      expect(peak, lessThanOrEqualTo(32767));
      expect(peak, greaterThan(10000), reason: 'bips audibles');
      expect(onset(wav, _lead + 0.81 + 0.27 + 0.4), double.infinity);
    });

    test('tempo putting 0,60 / 0,30 s', () {
      final w = ByteData.sublistView(buildCycleWav(0.6, 0.3, 2));
      final t1 = onset(w, 0), t2 = onset(w, _lead + 0.59), t3 = onset(w, _lead + 0.89);
      expect(t2 - t1, closeTo(0.6, 0.002));
      expect(t3 - t2, closeTo(0.3, 0.002));
      expect((w.lengthInBytes - 44) ~/ 2, (2.9 * 44100).round());
    });
  });
}

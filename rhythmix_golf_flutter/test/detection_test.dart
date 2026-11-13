// Tests unitaires des briques de la détection (lib/detection.dart).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rhythmix_golf/detection.dart';

void main() {
  group('jr (arrondi identique à Math.round de JavaScript)', () {
    test('arrondit .5 vers le haut, y compris pour les négatifs', () {
      expect(jr(2.5), 3);
      expect(jr(-2.5), -2); // Math.round(-2.5) == -2 (≠ Dart round() == -3)
      expect(jr(1.49), 1);
      expect(jr(0.5 * 60), 30);
    });
  });

  group('argMax', () {
    test('renvoie le premier maximum', () {
      expect(argMax([1, 3, 2, 3]), 1);
      expect(argMax([5]), 0);
    });
  });

  group('kParams', () {
    test('réglages de détection inchangés', () {
      final g = kParams['grand']!, p = kParams['putt']!;
      expect([g.hip, g.off, g.pre, g.bw, g.fb, g.amp, g.ratio, g.ratioT], [true, 0, 0.35, 0.6, 0.5, 0.05, 8, 3]);
      expect([p.hip, p.off, p.pre, p.bw, p.fb, p.amp, p.ratio, p.ratioT], [false, 0, 0.3, 0.5, 0.4, 0.008, 5, 2]);
    });
  });

  group('audioImpact', () {
    test('null si pas de son', () {
      expect(audioImpact(null), isNull);
      expect(audioImpact([]), isNull);
    });
    test('instant du pic (fenêtres de 10 ms), amplitude et rapport pic / médiane', () {
      final env = List<double>.filled(300, 0.01)..[187] = 0.8;
      final a = audioImpact(env)!;
      expect(a.t, closeTo(1.87, 1e-12));
      expect(a.amp, 0.8);
      expect(a.ratio, closeTo(80, 1e-9));
    });
    test('médiane plancher à 0,0005 (son quasi muet)', () {
      final env = List<double>.filled(100, 0)..[10] = 0.01;
      expect(audioImpact(env)!.ratio, closeTo(20, 1e-9));
    });
  });

  group('thumbLuma', () {
    test('image uniforme -> miniature uniforme', () {
      final g = Uint8List(40 * 30)..fillRange(0, 1200, 77);
      final t = thumbLuma(g, 40, 30, 8, 6);
      expect(t.length, 48);
      expect(t.every((v) => (v - 77).abs() < 1e-4), isTrue);
    });
    test('échantillonnage bilinéaire au centre des pixels', () {
      // Dégradé horizontal 0..255 sur 4 px, réduit à 2 px : moyenne de chaque paire.
      final g = Uint8List.fromList([0, 85, 170, 255]);
      final t = thumbLuma(g, 4, 1, 2, 1);
      expect(t[0], closeTo(42.5, 1e-4));
      expect(t[1], closeTo(212.5, 1e-4));
    });
  });

  group('motionCurve', () {
    test('différence moyenne entre images successives, lissée sur 3 points', () {
      Float32List f(double v) => Float32List.fromList([v, v]);
      final q = motionCurve([f(0), f(0), f(10), f(10), f(10)]);
      // brut : [0, 0, 10, 0, 0] -> lissé : [0, 10/3, 10/3, 10/3, 0]
      expect(q, [0, closeTo(10 / 3, 1e-9), closeTo(10 / 3, 1e-9), closeTo(10 / 3, 1e-9), 0]);
    });
    test('vidéo immobile -> courbe nulle', () {
      final f = Float32List.fromList([5, 6, 7]);
      expect(motionCurve([f, f, f]).every((v) => v == 0), isTrue);
    });
  });

  group('hipTop', () {
    test('null si les images manquent ou sont vides', () {
      expect(hipTop(50, const [], 10, 10, 100, 60), isNull);
      expect(hipTop(50, List.filled(100, Uint8List(0)), 0, 0, 100, 60), isNull);
    });
  });

  group('detectGrand / detectPutt : invariants', () {
    List<double> swing(int n, int s, int top, int imp) => List<double>.generate(n, (i) {
          if (i < s) return 0.01;
          if (i < top) return 1.0;
          if (i < top + 3) return 0.2;
          if (i <= imp) return 0.4 + 2.0 * (i - top) / (imp - top);
          if (i < imp + 20) return 1.0;
          return 0.01;
        });

    test('ordre départ < sommet < impact, et impact au son quand il est net', () {
      final q = swing(240, 60, 108, 124);
      final d = detectGrand(q: q, fps: 60, p: kParams['grand']!, au: const AudioHit(124 / 60, 0.5, 50));
      expect(d.markers[0], lessThan(d.markers[1]));
      expect(d.markers[1], lessThan(d.markers[2]));
      expect(d.markers[2], 124);
      expect(d.audioT, isNotNull);
      expect(d.viaHip, isFalse);
    });

    test('son trop faible : impact estimé d’après le mouvement', () {
      final q = swing(240, 60, 108, 124);
      final d = detectGrand(q: q, fps: 60, p: kParams['grand']!, au: const AudioHit(0.5, 0.01, 50));
      expect(d.audioT, isNull);
      expect(d.markers[2], 124 - jr(0.05 * 60));
    });

    test('putt : repères dans l’ordre', () {
      final q = List<double>.generate(180, (i) {
        if (i >= 50 && i < 80) return 0.2;
        if (i >= 80 && i < 84) return 0.01;
        if (i >= 84 && i < 100) return 0.5;
        return 0.005;
      });
      final d = detectPutt(q: q, fps: 60);
      expect(d.markers[0], lessThan(d.markers[1]));
      expect(d.markers[1], lessThan(d.markers[2]));
    });
  });
}

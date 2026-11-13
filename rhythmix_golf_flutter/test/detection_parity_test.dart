// Parité web <-> app : l'app Flutter doit placer EXACTEMENT les mêmes repères
// que le site (index.html) sur chaque cas de référence.
// Les repères attendus sont calculés en exécutant le code du site
// (tests/fixtures/generate-detection-cases.mjs).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rhythmix_golf/detection.dart';

import 'helpers.dart';

void main() {
  final cases = loadDetectionCases();

  test('les cas de référence sont présents', () {
    expect(cases.length, greaterThanOrEqualTo(15));
    expect(cases.where((c) => c['mode'] == 'putt'), isNotEmpty);
    expect(cases.where((c) => (c['expected'] as Map)['viaHip'] == true), isNotEmpty,
        reason: 'au moins un cas doit passer par le suivi des hanches');
    expect(cases.where((c) => (c['expected'] as Map)['audioUsed'] == true), isNotEmpty);
  });

  for (final c in cases) {
    test('mêmes repères que le site : ${c['name']}', () {
      final q = doubles(c['q']);
      final fps = (c['fps'] as num).toDouble();
      final exp = c['expected'] as Map<String, dynamic>;
      final p = kParams[c['mode']]!;

      // Le son : même calcul que le site à partir de l'enveloppe.
      AudioHit? au;
      if (c['env'] != null) {
        au = audioImpact(doubles(c['env']));
        final ref = c['au'] as Map<String, dynamic>;
        expect(au!.t, closeTo((ref['t'] as num).toDouble(), 1e-9));
        expect(au.amp, closeTo((ref['amp'] as num).toDouble(), 1e-9));
        expect(au.ratio, closeTo((ref['ratio'] as num).toDouble(), 1e-6));
      } else if (c['au'] != null) {
        final a = c['au'] as Map<String, dynamic>;
        au = AudioHit((a['t'] as num).toDouble(), (a['amp'] as num).toDouble(), (a['ratio'] as num).toDouble());
      }

      // Les images des hanches : reconstruites à l'identique (entiers).
      List<Uint8List>? big;
      var aw = 0, ah = 0;
      final hip = c['hip'] as Map<String, dynamic>?;
      if (hip != null) {
        aw = hip['w'] as int;
        ah = hip['h'] as int;
        final prof = (hip['profile'] as List).cast<int>();
        final shifts = (hip['shifts'] as List).cast<int>();
        final pad = hip['pad'] as int, bg = hip['background'] as int;
        big = [
          for (var i = 0; i < q.length; i++)
            () {
              final im = Uint8List(aw * ah)..fillRange(0, aw * ah, bg);
              for (var y = hip['rowFrom'] as int; y < (hip['rowTo'] as int); y++) {
                for (var x = 0; x < aw; x++) {
                  im[y * aw + x] = prof[x - shifts[i] + pad];
                }
              }
              return im;
            }(),
        ];
      }

      final Detection det = p.hip
          ? detectGrand(q: q, fps: fps, p: p, au: au, big: big, aw: aw, ah: ah)
          : detectPutt(q: q, fps: fps);

      expect(det.markers, (exp['markers'] as List).cast<int>(), reason: 'Départ / Sommet / Impact');
      if (p.hip) {
        expect(det.audioT != null, exp['audioUsed'], reason: 'impact repéré au son ?');
        expect(det.viaHip, exp['viaHip'], reason: 'sommet repéré aux hanches ?');
      }
    });
  }
}

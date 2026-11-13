// Réglages du métronome, persistance et historique (lib/app_state.dart).

import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rhythmix_golf/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<AppState> loaded([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final s = AppState(metronome: FakeMetronome());
  await s.load();
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('valeurs par défaut', () {
    test('grand jeu 0,81 / 0,27 s (3:1), putting 0,60 / 0,30 s (2:1)', () async {
      final s = await loaded();
      expect(s.mode, 'grand');
      expect([s.tempo['grand']!.b, s.tempo['grand']!.d], [0.81, 0.27]);
      expect([s.tempo['putt']!.b, s.tempo['putt']!.d], [0.60, 0.30]);
      expect(s.ratioTarget, 3);
      expect(s.pause, 3);
      expect(s.lock, isTrue);
      expect(s.speed, 100);
      s.setMode('putt');
      expect(s.ratioTarget, 2);
    });

    test('constantes inchangées', () {
      expect(kDefaults, {
        'grand': [0.81, 0.27],
        'putt': [0.60, 0.30],
      });
      expect(kRatioTolerance, 0.15);
      expect(kHistoryMax, 200);
    });
  });

  group('montée / descente', () {
    test('ratio verrouillé : changer la montée recalcule la descente (ratio exact 3:1)', () async {
      final s = await loaded();
      s.setB(0.9);
      expect([s.cur.b, s.cur.d], [0.9, 0.3]);
      s.setD(0.25);
      expect([s.cur.b, s.cur.d], [0.75, 0.25]);
    });

    test('ratio verrouillé : arrondi au centième, montée = descente x 3 telle qu’affichée', () async {
      final s = await loaded();
      s.setB(1.0); // 1,00 / 3 = 0,333 -> 0,33 -> montée 0,99
      expect([s.cur.b, s.cur.d], [0.99, 0.33]);
    });

    test('ratio verrouillé hors cible : le ratio courant est conservé', () async {
      final s = await loaded();
      s.setLock(false);
      s.setB(1.0); // ratio 1,0 / 0,27 ≈ 3,7
      s.setLock(true);
      s.setD(0.2);
      expect(s.cur.d, 0.2);
      expect(s.cur.b, closeTo(0.2 * 1.0 / 0.27, 0.006));
    });

    test('ratio libre : une seule durée change', () async {
      final s = await loaded();
      s.setLock(false);
      s.setB(1.2);
      expect([s.cur.b, s.cur.d], [1.2, 0.27]);
      s.setD(0.4);
      expect([s.cur.b, s.cur.d], [1.2, 0.4]);
    });

    test('valeurs nulles, négatives ou NaN ignorées', () async {
      final s = await loaded();
      s.setB(0);
      s.setB(-1);
      s.setD(double.nan);
      expect([s.cur.b, s.cur.d], [0.81, 0.27]);
    });

    test('un réglage remet la vitesse à 100 %', () async {
      final s = await loaded();
      s.setSpeed(120);
      s.setB(0.9);
      expect(s.speed, 100);
    });
  });

  group('vitesse', () {
    test('à droite plus rapide, ratio conservé, retour exact à 100 %', () async {
      final s = await loaded();
      s.setSpeed(120);
      expect(s.cur.d, 0.23); // 0,27 x 100 / 120 = 0,225 -> 0,23
      expect(s.cur.b, 0.69);
      s.setSpeed(60);
      expect([s.cur.b, s.cur.d], [1.35, 0.45]);
      s.setSpeed(100);
      expect([s.cur.b, s.cur.d], [0.81, 0.27], reason: 'la base de 100 % est conservée');
    });
  });

  group('modes, réinitialisation, pause', () {
    test('chaque mode garde ses réglages ; changer de mode remet la vitesse à 100 %', () async {
      final s = await loaded();
      s.setB(0.9);
      s.setSpeed(110);
      s.setMode('putt');
      expect(s.speed, 100);
      expect([s.cur.b, s.cur.d], [0.6, 0.3]);
      s.setMode('grand');
      expect(s.cur.d, closeTo(0.27, 0.005));
    });

    test('valeurs par défaut du mode courant uniquement', () async {
      final s = await loaded();
      s.setB(0.9);
      s.setMode('putt');
      s.setB(0.8);
      s.reset();
      expect([s.cur.b, s.cur.d], [0.6, 0.3]);
      expect(s.tempo['grand']!.b, 0.9);
    });

    test('pause et ratio verrouillé', () async {
      final s = await loaded();
      s.setPause(5.5);
      expect(s.pause, 5.5);
      s.setLock(false);
      expect(s.lock, isFalse);
    });
  });

  group('persistance (shared_preferences)', () {
    test('réglages enregistrés puis relus', () async {
      final s = await loaded();
      s.setB(0.9);
      s.setMode('putt');
      s.setB(0.7);
      s.setPause(4);
      s.setLock(false);
      final p = await SharedPreferences.getInstance();
      expect(p.getString('mode'), 'putt');
      expect(p.getDouble('grand_b'), 0.9);
      expect(p.getDouble('grand_d'), 0.3);
      expect(p.getDouble('putt_b'), 0.7);
      expect(p.getDouble('pause'), 4);
      expect(p.getBool('lock'), isFalse);

      final s2 = AppState(metronome: FakeMetronome());
      await s2.load();
      expect(s2.mode, 'putt');
      expect([s2.tempo['grand']!.b, s2.tempo['grand']!.d], [0.9, 0.3]);
      expect(s2.pause, 4);
      expect(s2.lock, isFalse);
    });

    test('valeurs enregistrées invalides ignorées', () async {
      final s = await loaded({'mode': 'golf', 'grand_b': -1.0, 'grand_d': 0.3});
      expect(s.mode, 'grand');
      expect(s.cur.b, 0.81);
    });

    test('ratio enregistré proche de 3:1 recalé exactement', () async {
      final s = await loaded({'grand_b': 0.812, 'grand_d': 0.271});
      expect([s.cur.b, s.cur.d], [0.81, 0.27]);
    });
  });

  group('analyse vidéo -> métronome', () {
    test('applyTarget règle le tempo cible et remet la vitesse à 100 %', () async {
      final s = await loaded();
      s.setSpeed(130);
      s.applyTarget(0.3 * 3, 0.3);
      expect([s.cur.b, s.cur.d], [0.9, 0.3]);
      expect(s.speed, 100);
    });
  });

  group('historique', () {
    test('un point par vidéo et par mode ; retouche = mise à jour, pas de doublon', () async {
      final s = await loaded();
      s.recordTempo('v1', 0.9, 0.3);
      s.recordTempo('v1', 0.95, 0.3); // repères retouchés
      expect(s.history['grand']!.length, 1);
      expect(s.history['grand']!.single.b, 0.95);
      s.recordTempo('v2', 0.6, 0.3);
      expect(s.history['grand']!.length, 2);
      s.setMode('putt');
      s.recordTempo('v1', 0.6, 0.3); // même vidéo analysée en putting
      expect(s.history['putt']!.single.id, 'v1-putt');
      expect(s.history['grand']!.length, 2);
    });

    test('durées invalides ignorées', () async {
      final s = await loaded();
      s.recordTempo('v', 0, 0.3);
      s.recordTempo('v', 0.5, -1);
      expect(s.history['grand'], isEmpty);
    });

    test('200 points maximum : les plus anciens sont retirés', () async {
      final s = await loaded();
      for (var i = 0; i < 205; i++) {
        s.recordTempo('v$i', 0.9, 0.3);
      }
      expect(s.history['grand']!.length, 200);
      expect(s.history['grand']!.first.id, 'v5-grand');
    });

    test('enregistré, relu, puis effacé pour le mode courant seulement', () async {
      final s = await loaded();
      s.recordTempo('a', 0.9, 0.3);
      s.setMode('putt');
      s.recordTempo('b', 0.6, 0.3);
      final p = await SharedPreferences.getInstance();
      final raw = jsonDecode(p.getString('history_grand')!) as List;
      expect(raw.single['id'], 'a-grand');
      expect(raw.single.keys, containsAll(['id', 't', 'b', 'd']));

      final s2 = AppState(metronome: FakeMetronome());
      await s2.load();
      expect(s2.history['grand']!.single.ratio, closeTo(3, 1e-9));
      expect(s2.history['putt']!.single.ratio, closeTo(2, 1e-9));

      s.clearHistory();
      expect(s.history['putt'], isEmpty);
      expect(s.history['grand']!.length, 1);
      expect(p.getString('history_putt'), '[]');
    });

    test('entrées corrompues ignorées à la lecture', () async {
      final s = await loaded({
        'history_grand': jsonEncode([
          {'id': 'ok', 't': 0, 'b': 0.9, 'd': 0.3},
          {'id': 'neg', 't': 0, 'b': -1, 'd': 0.3},
          {'id': 3, 't': 0, 'b': 0.9, 'd': 0.3},
          'n’importe quoi',
        ]),
        'history_putt': 'pas du json',
      });
      expect(s.history['grand']!.map((e) => e.id), ['ok']);
    });
  });

  group('verdict du tempo', () {
    test('± 0,15 autour de la cible = dans la cible ; au-dessus trop lent ; en dessous trop rapide', () {
      expect(tempoStatus(3.0, 3), TempoStatus.ok);
      expect(tempoStatus(3.15, 3), TempoStatus.ok);
      expect(tempoStatus(2.85, 3), TempoStatus.ok);
      expect(tempoStatus(3.16, 3), TempoStatus.slow, reason: 'juste au-delà de la tolérance');
      expect(tempoStatus(2.84, 3), TempoStatus.fast);
      expect(tempoStatus(3.5, 3), TempoStatus.slow);
      expect(tempoStatus(2.5, 3), TempoStatus.fast);
      expect(tempoStatus(2.2, 2), TempoStatus.slow);
      expect(tempoStatus(1.7, 2), TempoStatus.fast);
      expect(tempoStatusLabel(TempoStatus.ok), 'Dans la cible');
      expect(tempoStatusLabel(TempoStatus.slow), 'Trop lent');
      expect(tempoStatusLabel(TempoStatus.fast), 'Trop rapide');
    });
  });

  group('formats', () {
    test('fmt2 et round2', () {
      expect(fmt2(0.81), '0,81');
      expect(fmt2(1.5), '1,50');
      expect(round2(0.225), 0.23);
      expect(round2(0.8149), 0.81);
    });
  });

  group('métronome', () {
    test('démarrer / arrêter avec le tempo courant', () async {
      final m = FakeMetronome();
      SharedPreferences.setMockInitialValues({});
      final s = AppState(metronome: m);
      await s.load();
      await s.toggleMetronome();
      expect(s.running, isTrue);
      expect(m.starts.single, (0.81, 0.27, 3.0));
      await s.toggleMetronome();
      expect(s.running, isFalse);
      expect(m.stops, 1);
    });

    test('un réglage pendant la lecture relance le métronome 300 ms plus tard', () {
      fakeAsync((async) {
        final m = FakeMetronome();
        final s = AppState(metronome: m); // sans load() : valeurs par défaut
        s.toggleMetronome();
        async.flushMicrotasks();
        s.setB(0.9);
        s.setB(0.96); // réglages rapprochés : une seule relance
        async.elapse(const Duration(milliseconds: 299));
        expect(m.starts.length, 1);
        async.elapse(const Duration(milliseconds: 2));
        expect(m.starts.length, 2);
        expect(m.starts.last, (0.96, 0.32, 3.0));
      });
    });
  });
}

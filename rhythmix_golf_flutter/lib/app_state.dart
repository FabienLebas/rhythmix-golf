import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'metronome.dart';

class Tempo {
  Tempo(this.b, this.d);
  double b; // montée (s)
  double d; // descente (s)
}

/// Valeurs par défaut : grand jeu 0,81 / 0,27 s (3:1), putting 0,60 / 0,30 s (2:1).
const Map<String, List<double>> kDefaults = {
  'grand': [0.81, 0.27],
  'putt': [0.60, 0.30],
};

class AppState extends ChangeNotifier {
  String mode = 'grand';
  final Map<String, Tempo> tempo = {
    'grand': Tempo(kDefaults['grand']![0], kDefaults['grand']![1]),
    'putt': Tempo(kDefaults['putt']![0], kDefaults['putt']![1]),
  };
  double pause = 3;
  bool lock = true;
  double speed = 100;
  final Metronome metronome = Metronome();

  SharedPreferences? _prefs;
  Timer? _restart;

  Tempo get cur => tempo[mode]!;
  int get ratioTarget => mode == 'grand' ? 3 : 2;
  bool get running => metronome.running;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _prefs = p;
      mode = p.getString('mode') ?? mode;
      if (mode != 'grand' && mode != 'putt') mode = 'grand';
      for (final k in ['grand', 'putt']) {
        final b = p.getDouble('${k}_b'), d = p.getDouble('${k}_d');
        if (b != null && d != null && b > 0 && d > 0) tempo[k] = Tempo(b, d);
      }
      pause = p.getDouble('pause') ?? pause;
      lock = p.getBool('lock') ?? lock;
    } catch (_) {}
    await metronome.init();
  }

  void _save() {
    final p = _prefs;
    if (p == null) return;
    p.setString('mode', mode);
    for (final k in ['grand', 'putt']) {
      p.setDouble('${k}_b', tempo[k]!.b);
      p.setDouble('${k}_d', tempo[k]!.d);
    }
    p.setDouble('pause', pause);
    p.setBool('lock', lock);
  }

  void _changed({bool restart = true}) {
    _save();
    notifyListeners();
    if (restart && metronome.running) {
      _restart?.cancel();
      _restart = Timer(const Duration(milliseconds: 300), () {
        if (metronome.running) metronome.start(cur.b, cur.d, pause);
      });
    }
  }

  void setMode(String m) {
    if (m == mode) return;
    mode = m;
    speed = 100;
    _changed();
  }

  void setB(double v) {
    if (!(v > 0)) return;
    final r = cur.b / cur.d;
    cur.b = v;
    if (lock) cur.d = v / r;
    speed = 100;
    _changed();
  }

  void setD(double v) {
    if (!(v > 0)) return;
    final r = cur.b / cur.d;
    cur.d = v;
    if (lock) cur.b = v * r;
    speed = 100;
    _changed();
  }

  /// Vitesse en % : à droite plus rapide (durées plus courtes), ratio conservé.
  void setSpeed(double n) {
    final f = speed / n;
    cur.b *= f;
    cur.d *= f;
    speed = n;
    _changed();
  }

  void setLock(bool v) {
    lock = v;
    _changed(restart: false);
  }

  void setPause(double v) {
    pause = v;
    _changed();
  }

  void reset() {
    final dft = kDefaults[mode]!;
    tempo[mode] = Tempo(dft[0], dft[1]);
    speed = 100;
    _changed();
  }

  /// Réglage automatique après l'analyse d'une vidéo (tempo cible).
  void applyTarget(double b, double d) {
    if ((cur.b - b).abs() < 1e-6 && (cur.d - d).abs() < 1e-6) return;
    tempo[mode] = Tempo(b, d);
    speed = 100;
    _changed();
  }

  Future<void> toggleMetronome() async {
    if (metronome.running) {
      _restart?.cancel();
      await metronome.stop();
    } else {
      final f = metronome.start(cur.b, cur.d, pause);
      notifyListeners();
      await f;
    }
    notifyListeners();
  }
}

String fmt2(double x) => x.toStringAsFixed(2).replaceAll('.', ',');

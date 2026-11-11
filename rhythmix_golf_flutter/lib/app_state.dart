import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'metronome.dart';
import 'purchase.dart';

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

/// Un point de l'historique : un tempo mesuré sur une vidéo.
class HistoryEntry {
  HistoryEntry({required this.id, required this.time, required this.b, required this.d});
  final String id;
  final DateTime time;
  double b; // montée (s)
  double d; // descente (s)
  double get ratio => b / d;

  Map<String, dynamic> toJson() => {'id': id, 't': time.millisecondsSinceEpoch, 'b': b, 'd': d};

  static HistoryEntry? fromJson(Object? o) {
    if (o is! Map) return null;
    final id = o['id'], t = o['t'], b = o['b'], d = o['d'];
    if (id is! String || t is! num || b is! num || d is! num || b <= 0 || d <= 0) return null;
    return HistoryEntry(id: id, time: DateTime.fromMillisecondsSinceEpoch(t.toInt()), b: b.toDouble(), d: d.toDouble());
  }
}

/// Écart toléré autour du ratio cible pour parler de « dans la cible ».
const double kRatioTolerance = 0.15;
const int kHistoryMax = 200;

enum TempoStatus { ok, slow, fast }

TempoStatus tempoStatus(double ratio, int target) {
  if ((ratio - target).abs() <= kRatioTolerance) return TempoStatus.ok;
  return ratio > target ? TempoStatus.slow : TempoStatus.fast;
}

String tempoStatusLabel(TempoStatus s) => switch (s) {
      TempoStatus.ok => 'Dans la cible',
      TempoStatus.slow => 'Trop lent',
      TempoStatus.fast => 'Trop rapide',
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

  /// Analyses gratuites et achat intégré.
  final PurchaseService purchase = PurchaseService();

  /// Historique du tempo, stocké sur l'appareil (pas de base de données).
  final Map<String, List<HistoryEntry>> history = {'grand': [], 'putt': []};

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
      for (final k in ['grand', 'putt']) {
        final raw = p.getString('history_$k');
        if (raw == null) continue;
        final l = jsonDecode(raw);
        if (l is List) {
          history[k] = l.map(HistoryEntry.fromJson).whereType<HistoryEntry>().toList();
        }
      }
    } catch (_) {}
    await metronome.init();
    await purchase.init();
    purchase.addListener(notifyListeners);
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

  void _saveHistory(String m) {
    _prefs?.setString('history_$m', jsonEncode([for (final e in history[m]!) e.toJson()]));
  }

  /// Ajoute (ou met à jour, si les repères sont retouchés) le point d'une vidéo.
  void recordTempo(String videoId, double b, double d) {
    if (!(b > 0 && d > 0)) return;
    final id = '$videoId-$mode';
    final l = history[mode]!;
    final i = l.indexWhere((e) => e.id == id);
    if (i >= 0) {
      final e = l[i];
      if ((e.b - b).abs() < 1e-4 && (e.d - d).abs() < 1e-4) return;
      e.b = b;
      e.d = d;
    } else {
      l.add(HistoryEntry(id: id, time: DateTime.now(), b: b, d: d));
      if (l.length > kHistoryMax) l.removeRange(0, l.length - kHistoryMax);
    }
    _saveHistory(mode);
    notifyListeners();
  }

  void clearHistory() {
    history[mode]!.clear();
    _saveHistory(mode);
    notifyListeners();
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

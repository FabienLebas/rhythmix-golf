// Détection automatique Départ / Sommet / Impact.
// Portage fidèle de l'algorithme de la version web (vérifié sur la vidéo de
// référence : images 78 / 138 / 153). Code pur Dart, sans dépendance Flutter.

import 'dart:math' as math;
import 'dart:typed_data';

/// Arrondi identique à Math.round de JavaScript.
int jr(num x) => (x + 0.5).floor();

class DetectParams {
  const DetectParams({
    required this.hip,
    required this.off,
    required this.pre,
    required this.bw,
    required this.fb,
    required this.amp,
    required this.ratio,
    required this.ratioT,
  });
  final bool hip; // suivi des hanches (grand jeu)
  final double off; // décalage appliqué au son d'impact (s)
  final double pre, bw, fb, amp, ratio;
  final int ratioT; // ratio cible montée / descente
}

const Map<String, DetectParams> kParams = {
  'grand': DetectParams(hip: true, off: 0, pre: 0.35, bw: 0.6, fb: 0.5, amp: 0.05, ratio: 8, ratioT: 3),
  'putt': DetectParams(hip: false, off: 0, pre: 0.3, bw: 0.5, fb: 0.4, amp: 0.008, ratio: 5, ratioT: 2),
};

class AudioHit {
  const AudioHit(this.t, this.amp, this.ratio);
  final double t; // instant du pic sonore (s)
  final double amp; // amplitude du pic
  final double ratio; // pic / médiane
}

class Detection {
  const Detection(this.markers, {this.audioT, this.viaHip = false});
  final List<int> markers; // [départ, sommet, impact]
  final double? audioT;
  final bool viaHip;
}

int argMax(List<double> q) {
  var k = 0;
  for (var i = 1; i < q.length; i++) {
    if (q[i] > q[k]) k = i;
  }
  return k;
}

double _median(List<double> sorted) {
  final l = sorted.length;
  if (l == 0) return 0;
  return l.isOdd ? sorted[(l - 1) ~/ 2] : (sorted[l ~/ 2 - 1] + sorted[l ~/ 2]) / 2;
}

List<double> _slice(List<double> q, int a, int b) {
  final s = a.clamp(0, q.length).toInt();
  final e = b.clamp(s, q.length).toInt();
  return q.sublist(s, e);
}

/// Enveloppe sonore (max par fenêtre de 10 ms) -> pic d'impact.
AudioHit? audioImpact(List<double>? env) {
  if (env == null || env.isEmpty) return null;
  final sorted = [...env]..sort();
  final med = sorted[sorted.length ~/ 2];
  final pk = argMax(env);
  return AudioHit(pk / 100, env[pk], env[pk] / math.max(med, 0.0005));
}

/// Miniature (tw x th) en niveaux de gris, échantillonnée en bilinéaire
/// sans anti-crénelage depuis l'image de travail (w x h), exactement comme
/// le dessin sur canvas de la version web : même courbe de mouvement sur
/// iPhone et Android.
Float32List thumbLuma(Uint8List g, int w, int h, int tw, int th) {
  final out = Float32List(tw * th);
  final sx = w / tw, sy = h / th;
  for (var y = 0; y < th; y++) {
    final fy = (y + 0.5) * sy - 0.5;
    final y0 = fy.floor();
    final wy = fy - y0;
    final ya = y0.clamp(0, h - 1).toInt(), yb = (y0 + 1).clamp(0, h - 1).toInt();
    for (var x = 0; x < tw; x++) {
      final fx = (x + 0.5) * sx - 0.5;
      final x0 = fx.floor();
      final wx = fx - x0;
      final xa = x0.clamp(0, w - 1).toInt(), xb = (x0 + 1).clamp(0, w - 1).toInt();
      final top = g[ya * w + xa] * (1 - wx) + g[ya * w + xb] * wx;
      final bot = g[yb * w + xa] * (1 - wx) + g[yb * w + xb] * wx;
      out[y * tw + x] = top * (1 - wy) + bot * wy;
    }
  }
  return out;
}

/// Courbe de mouvement : différence moyenne entre images successives
/// (miniatures en niveaux de gris), lissée sur 3 points.
List<double> motionCurve(List<Float32List> lum) {
  final n = lum.length;
  final e = List<double>.filled(n, 0);
  for (var r = 1; r < n; r++) {
    final a = lum[r], b = lum[r - 1];
    var sa = 0.0;
    for (var j = 0; j < a.length; j++) {
      sa += (a[j] - b[j]).abs();
    }
    e[r] = sa / a.length;
  }
  return List<double>.generate(n, (i) {
    final v = e[i];
    final p = i > 0 ? e[i - 1] : v;
    final nx = i < n - 1 ? e[i + 1] : v;
    return (p + v + nx) / 3;
  });
}

/// Sommet du backswing repéré au départ latéral des hanches (vue de face).
/// [big] : images en niveaux de gris de [w] x [h] pixels.
int? hipTop(int ip, List<Uint8List> big, int w, int h, int n, double fps) {
  if (big.length < n || w <= 0 || h <= 0) return null;
  final lo = math.max(1, ip - jr(1.0 * fps));
  final hi = math.min(n - 1, ip + jr(0.25 * fps));
  if (hi < lo) return null;
  final re = Float32List(h);
  for (var i = lo; i <= hi; i++) {
    final a = big[i], b = big[i - 1];
    for (var y = 0; y < h; y++) {
      var sm = 0.0;
      final row = y * w;
      for (var x = 0; x < w; x++) {
        sm += (a[row + x] - b[row + x]).abs();
      }
      re[y] += sm;
    }
  }
  var mx = 0.0;
  for (var y = 0; y < h; y++) {
    if (re[y] > mx) mx = re[y];
  }
  var y0 = 0, y1 = h - 1;
  while (y0 < h && re[y0] < 0.25 * mx) {
    y0++;
  }
  while (y1 > 0 && re[y1] < 0.25 * mx) {
    y1--;
  }
  if (y1 - y0 < 20) return null;
  final by0 = jr(y0 + 0.5 * (y1 - y0)), by1 = jr(y0 + 0.7 * (y1 - y0));
  final prof = <int, Float32List>{};
  for (var i = lo - 1; i <= hi; i++) {
    final pr = Float32List(w);
    final img = big[i];
    for (var y = by0; y <= by1; y++) {
      for (var x = 0; x < w; x++) {
        pr[x] += img[y * w + x];
      }
    }
    for (var x = 0; x < w; x++) {
      pr[x] /= (by1 - by0 + 1);
    }
    prof[i] = pr;
  }
  final dmap = <int, double>{};
  final maxd = math.max(2, jr(w / 27));
  dmap[lo - 1] = 0;
  for (var i = lo; i <= hi; i++) {
    final costs = <double>[];
    final pa = prof[i]!, pb = prof[i - 1]!;
    for (var d = -maxd; d <= maxd; d++) {
      var c = 0.0;
      var cnt = 0;
      for (var x = math.max(0, d); x < math.min(w, w + d); x++) {
        c += (pa[x] - pb[x - d]).abs();
        cnt++;
      }
      costs.add(cnt > 0 ? c / cnt : double.infinity);
    }
    var k = 0;
    for (var c = 1; c < costs.length; c++) {
      if (costs[c] < costs[k]) k = c;
    }
    var sh = (k - maxd).toDouble();
    if (k > 0 && k < costs.length - 1) {
      final den = costs[k - 1] - 2 * costs[k] + costs[k + 1];
      if (den > 1e-9) sh += 0.5 * (costs[k - 1] - costs[k + 1]) / den;
    }
    dmap[i] = dmap[i - 1]! + sh;
  }
  final seg = <double>[];
  for (var i = ip - jr(0.71 * fps); i <= ip - jr(0.27 * fps); i++) {
    final v = dmap[i];
    if (v != null) seg.add(v);
  }
  if (seg.isEmpty) return null;
  seg.sort();
  final m = _median(seg);
  final endv = dmap[math.min(hi, ip + jr(0.14 * fps))];
  if (endv == null) return null;
  if ((endv - m).abs() < 0.8 * (w / 108)) return null;
  final sgn = endv > m ? 1 : -1;
  final lim = m + 0.1 * (endv - m);
  var t = ip;
  while (t > ip - jr(0.8 * fps)) {
    final v = dmap[t];
    if (v == null || !(sgn * (v - lim) > 0)) break;
    t--;
  }
  return t + 2;
}

/// Grand jeu : impact par le son (sinon le mouvement), sommet par les
/// hanches (sinon le mouvement), départ par la sortie du calme.
Detection detectGrand({
  required List<double> q,
  required double fps,
  required DetectParams p,
  AudioHit? au,
  List<Uint8List>? big,
  int aw = 0,
  int ah = 0,
}) {
  final n = q.length;
  final double? at = (au != null && au.amp > p.amp && au.ratio > p.ratio) ? au.t : null;
  final ip = at == null
      ? math.max(0, argMax(q) - jr(0.05 * fps))
      : math.max(0, math.min(n - 1, jr((at + p.off) * fps)));
  final lo = math.max(0, ip - jr(p.pre * fps));
  final hi = math.min(n - 1, ip + jr(0.15 * fps));
  var pk = lo;
  for (var k = lo; k <= hi; k++) {
    if (q[k] > q[pk]) pk = k;
  }
  var it = pk;
  while (it > 0 && q[it] >= 0.25 * q[pk]) {
    it--;
  }
  it = math.max(0, it - 1);
  final ith = (p.hip && big != null) ? hipTop(ip, big, aw, ah, n, fps) : null;
  var viaHip = false;
  if (ith != null && ith < ip - jr(0.1 * fps) && ith > ip - jr(0.9 * fps)) {
    it = ith;
    viaHip = true;
  }
  final st = _start(q, it, fps, p.bw, 0.2, 0.1, p.fb);
  return Detection([st, it, ip], audioT: at, viaHip: viaHip);
}

/// Putting : tout par le mouvement (le bruit d'un putt est trop faible).
Detection detectPutt({required List<double> q, required double fps}) {
  var ip = argMax(q);
  ip = math.max(0, ip - jr(0.03 * fps));
  final lo = math.max(0, ip - jr(0.7 * fps));
  final hi = math.max(lo, ip - jr(0.12 * fps));
  var it = lo;
  for (var k = lo; k <= hi && k < q.length; k++) {
    if (q[k] < q[it]) it = k;
  }
  final st = _start(q, it, fps, 0.5, 0.15, 0.2, 0.5);
  return Detection([st, it, ip]);
}

/// Départ : on remonte depuis le sommet jusqu'à trouver 3 images calmes.
int _start(List<double> q, int it, double fps, double bw, double gap, double frac, double fb) {
  final bl = math.max(0, it - jr(bw * fps));
  final bh = math.max(bl + 1, it - jr(gap * fps));
  final sw = _slice(q, bl, bh + 1)..sort();
  final med = _median(sw);
  final all = [...q]..sort();
  final fl = all[(0.15 * q.length).floor().clamp(0, q.length - 1).toInt()];
  final thr = fl + frac * (med - fl);
  var st = it - jr(gap * fps);
  while (st > 3) {
    var ok = true;
    for (var j = 0; j < 3; j++) {
      if (st - j >= q.length || q[st - j] >= thr) {
        ok = false;
        break;
      }
    }
    if (ok) break;
    st--;
  }
  if (st <= 3 || st >= it) {
    st = math.max(0, it - jr(fb * fps));
  } else {
    st = st + 1;
  }
  return st;
}

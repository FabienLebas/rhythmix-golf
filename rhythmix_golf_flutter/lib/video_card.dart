import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'app_state.dart';
import 'detection.dart';
import 'format.dart';
import 'l10n/app_localizations.dart';
import 'native.dart';
import 'paywall.dart';
import 'strip.dart';
import 'texts.dart';
import 'widgets.dart';

/// Texte affiché, construit au moment de l'affichage : si la langue de
/// l'appareil change pendant qu'il est à l'écran, il suit.
typedef _Msg = String Function(AppLocalizations l);

String _intro(AppLocalizations l) => l.videoIntro;

enum _Fail { unreadable, tooShort, noMotion }

/// Vidéo inutilisable (illisible, trop courte, sans mouvement).
class _VideoFail implements Exception {
  const _VideoFail(this.kind);
  final _Fail kind;

  String text(AppLocalizations l) => switch (kind) {
        _Fail.unreadable => l.failUnreadable,
        _Fail.tooShort => l.failTooShort,
        _Fail.noMotion => l.failNoMotion,
      };
}

class VideoCard extends StatefulWidget {
  const VideoCard({super.key, required this.state});
  final AppState state;

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  String? _path;
  VideoInfo? _info;
  double _fps = 30;
  int _n = 0;
  final List<ui.Image> _thumbs = [];
  final List<Uint8List> _big = [];
  int _aw = 0, _ah = 0, _tw = 36, _th = 64;
  double _cw = 36;
  List<double>? _q;
  AudioHit? _au;
  List<int?> _m = [null, null, null];
  int? _sel;
  double _pos = 0;
  int _cur = -1;
  bool _busy = false;
  _Msg _hint = _intro;
  _Msg _status = (_) => '—';
  Uint8List? _pv;
  int _pvWant = -1;
  bool _pvLoading = false;
  late String _lastMode;
  int _job = 0;
  String _videoId = '';
  // Mode dans lequel la vidéo a été choisie : seul cet historique reçoit le point.
  String _videoMode = '';

  AppState get s => widget.state;

  @override
  void initState() {
    super.initState();
    _lastMode = s.mode;
    s.addListener(_onState);
  }

  @override
  void dispose() {
    s.removeListener(_onState);
    _job++;
    for (final im in _thumbs) {
      im.dispose();
    }
    super.dispose();
  }

  void _onState() {
    if (s.mode != _lastMode) {
      _lastMode = s.mode;
      if (!_busy && _q != null) {
        _detect();
      } else if (mounted) {
        setState(() {});
      }
    }
  }

  // ---------- Chargement et analyse ----------

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;
    // Gratuité épuisée : proposer l'achat avant même d'ouvrir la caméra ou la galerie.
    if (!s.purchase.canAnalyze) {
      await showPaywall(context, s.purchase);
      if (!s.purchase.canAnalyze || !mounted) return;
    }
    XFile? x;
    try {
      x = await ImagePicker().pickVideo(source: source, maxDuration: const Duration(seconds: 20));
    } catch (e) {
      setState(() => _status = (l) => source == ImageSource.camera ? l.errOpenCamera('$e') : l.errOpenGallery('$e'));
      return;
    }
    if (x == null || !mounted) return;
    final path = x.path;
    final job = ++_job;
    _videoId = DateTime.now().millisecondsSinceEpoch.toString();
    _videoMode = s.mode;
    final old = List<ui.Image>.from(_thumbs);
    setState(() {
      _path = path;
      _info = null;
      _n = 0;
      _thumbs.clear();
      _big.clear();
      _q = null;
      _au = null;
      _m = [null, null, null];
      _sel = null;
      _pos = 0;
      _cur = -1;
      _pv = null;
      _busy = true;
      _hint = _intro;
      _status = (l) => l.statusLoading;
    });
    for (final im in old) {
      im.dispose();
    }
    try {
      final info = await NativeVideo.info(path);
      if (info.width <= 0 || info.height <= 0 || info.durationMs <= 0) {
        throw const _VideoFail(_Fail.unreadable);
      }
      final fps = (info.fps > 5 && info.fps < 500) ? info.fps : 30.0;
      var n = (info.durationMs / 1000 * fps).floor();
      if (info.frameCount > 0) n = math.min(n, info.frameCount);
      n = math.min(n, 900);
      if (n < 10) throw const _VideoFail(_Fail.tooShort);
      // Images de travail : réduites par moitiés successives (petit côté entre 120 et 240 px).
      var aw = info.width, ah = info.height;
      while (math.min(aw, ah) / 2 >= 120) {
        aw = jr(aw / 2);
        ah = jr(ah / 2);
      }
      const th = 64;
      final tw = math.max(24, jr(th * info.width / info.height));
      if (!mounted || job != _job) return;
      setState(() {
        _info = info;
        _fps = fps;
        _aw = aw;
        _ah = ah;
        _tw = tw;
        _th = th;
        _cw = math.min(tw, 44).toDouble();
        _hint = (l) => l.hintFps(fmtTrim(fps, l.localeName));
      });
      _cur = 0;
      _requestPreview();
      final lum = <Float32List>[];
      final sw = Stopwatch()..start();
      for (var start = 0; start < n; start += 30) {
        final c = math.min(30, n - start);
        final b = await NativeVideo.frames(
          path: path,
          start: start,
          count: c,
          aw: aw,
          ah: ah,
          tw: tw,
          th: th,
          fps: fps,
          frameCount: info.frameCount,
        );
        if (!mounted || job != _job) return;
        for (var k = 0; k < c; k++) {
          final g = Uint8List.sublistView(b.gray, k * aw * ah, (k + 1) * aw * ah);
          _big.add(g);
          lum.add(thumbLuma(g, aw, ah, tw, th));
          final px = Uint8List.fromList(Uint8List.sublistView(b.rgba, k * tw * th * 4, (k + 1) * tw * th * 4));
          _thumbs.add(await rgbaToImage(px, tw, th));
        }
        if (!mounted || job != _job) return;
        final done = start + c, secs = sw.elapsed.inSeconds;
        setState(() => _status = (l) => l.statusAnalyzing((100 * done / n).round(), done, n, secs));
      }
      final q = motionCurve(lum);
      if (q.reduce(math.max) < 0.003) throw const _VideoFail(_Fail.noMotion);
      List<double>? env;
      try {
        env = await NativeVideo.audioEnvelope(path);
      } catch (_) {}
      if (!mounted || job != _job) return;
      setState(() {
        _n = n;
        _q = q;
        _au = audioImpact(env);
        _busy = false;
        _status = (_) => '—';
      });
      // Une analyse réussie compte (une seule fois par vidéo : retoucher les repères
      // ou changer de mode ne consomme rien).
      s.purchase.recordAnalysis();
      _detect();
    } catch (e) {
      if (!mounted || job != _job) return;
      setState(() {
        _busy = false;
        _n = 0;
        _status = (l) => l.errAnalyze(e is _VideoFail ? e.text(l) : '$e');
      });
    }
  }

  void _detect() {
    final q = _q;
    if (q == null || _n == 0) return;
    final p = kParams[s.mode]!;
    Detection det;
    _Msg hint;
    if (!p.hip) {
      det = detectPutt(q: q, fps: _fps);
      hint = (l) => '${l.hintPutt} ${l.videoCheck}';
    } else {
      det = detectGrand(q: q, fps: _fps, p: p, au: _au, big: _big, aw: _aw, ah: _ah);
      final at = det.audioT, hip = det.viaHip;
      hint = (l) {
        final main = at == null
            ? (hip ? l.hintGrandMotionHip : l.hintGrandMotion)
            : (hip ? l.hintGrandBallHip(fmtTrim(at, l.localeName)) : l.hintGrandBall(fmtTrim(at, l.localeName)));
        return '$main ${l.videoCheck}';
      };
    }
    setState(() {
      _m = List<int?>.from(det.markers);
      _cur = -1;
      _sel = 0;
      _hint = hint;
    });
    _setPos(det.markers[0].toDouble());
  }

  // ---------- Navigation dans les images ----------

  void _setPos(double p) {
    if (_n == 0) return;
    final np = p.clamp(0, (_n - 1).toDouble()).toDouble();
    final f = np.round();
    final changed = f != _cur;
    setState(() {
      _pos = np;
      if (changed) {
        _cur = f;
        if (_sel != null) _m[_sel!] = _cur;
      }
    });
    if (changed) _requestPreview();
    _applyTempo();
  }

  void _step(int d) {
    if (_n == 0 || _busy) return;
    _setPos((_pos.round() + d).toDouble());
  }

  void _tapMarker(int i) {
    if (_n == 0 || _busy) return;
    if (_sel == i) {
      setState(() => _sel = null);
      return;
    }
    _m[i] ??= _pos.round();
    _sel = i;
    _setPos(_m[i]!.toDouble());
  }

  void _requestPreview() {
    if (_path == null || _cur < 0) return;
    _pvWant = _cur;
    if (!_pvLoading) _loadPreview();
  }

  Future<void> _loadPreview() async {
    _pvLoading = true;
    final info = _info;
    while (mounted && _path != null && info != null) {
      final want = _pvWant;
      Uint8List? b;
      try {
        b = await NativeVideo.preview(path: _path!, index: want, fps: _fps, frameCount: info.frameCount);
      } catch (_) {}
      if (!mounted) return;
      if (b != null) setState(() => _pv = b);
      if (_pvWant == want) break;
    }
    _pvLoading = false;
  }

  // ---------- Tempo ----------

  (double, double)? _measured() {
    if (_m.contains(null) || _n == 0) return null;
    final b = (_m[1]! - _m[0]!) / _fps, d = (_m[2]! - _m[1]!) / _fps;
    return (b, d);
  }

  /// Le métronome est réglé sur le tempo cible : descente conservée,
  /// montée = descente x ratio (3 au grand jeu, 2 au putting).
  void _applyTempo() {
    final md = _measured();
    if (md == null) return;
    final (b, d) = md;
    if (b <= 0 || d <= 0) return;
    s.applyTarget(d * s.ratioTarget, d);
    // Changer de mode avec la vidéo chargée relance la détection : ne pas
    // enregistrer cette même vidéo dans l'historique de l'autre mode.
    if (_videoId.isNotEmpty && s.mode == _videoMode) s.recordTempo(_videoId, b, d);
  }

  // ---------- Interface ----------

  List<Widget> _results(AppLocalizations l, TextStyle muted) {
    final loc = l.localeName;
    final md = _measured();
    if (md == null) return [InfoBox(_status(l))];
    final (b, d) = md;
    if (b <= 0 || d <= 0) return [InfoBox(l.resultOrder)];
    final r = s.ratioTarget;
    // Tempo cible arrondi comme le métronome : montée = exactement r x descente.
    final dd = math.max(0.01, round2(d)), bb = dd * r, rt = b / d;
    final String adv;
    if ((rt - r).abs() <= 0.15) {
      adv = l.adviceClose(r);
    } else if (s.mode == 'grand') {
      adv = rt > r
          ? l.adviceGrandSlow(fmt2(b - bb, loc), fmt2(b, loc), fmt2(bb, loc))
          : l.adviceGrandFast(fmt2(bb - b, loc), fmt2(b, loc), fmt2(bb, loc));
    } else {
      // Au putting, c'est l'équilibre montée / descente qui compte :
      // on peut corriger d'un côté comme de l'autre.
      adv = rt > r ? l.advicePuttSlow(fmt2(b, loc), fmt2(bb, loc)) : l.advicePuttFast(fmt2(b, loc), fmt2(bb, loc));
    }
    return [
      InfoBox(l.resultRhythm(fmt2(b, loc), fmt2(d, loc), fmt1(rt, loc), fmt2(b + d, loc))),
      InfoBox(adv),
      Text(l.resultMetroSet(s.mode, r, fmt2(bb, loc), fmt2(dd, loc)), style: muted),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final l = AppLocalizations.of(context);
    final loc = l.localeName;
    final muted = TextStyle(fontSize: 13, color: t.colorScheme.onSurfaceVariant);
    final info = _info;
    final ready = _n > 0 && !_busy;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.analyzeTitle(s.mode),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(l.filmTip, style: muted),
            const SizedBox(height: 10),
            FreeTrialBanner(purchase: s.purchase),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _busy ? null : () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.videocam),
                    label: Text(l.btnFilm),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.video_library),
                    label: Text(l.btnPick),
                  ),
                ),
              ],
            ),
            if (info != null) ...[
              const SizedBox(height: 10),
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.45),
                  child: AspectRatio(
                    aspectRatio: info.width / info.height,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const ColoredBox(color: Colors.black),
                          if (_pv != null) Image.memory(_pv!, fit: BoxFit.contain, gaplessPlayback: true),
                          if (_n > 0)
                            Positioned(
                              left: 8,
                              bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  l.frameLabel(_cur, _n - 1, fmt3(_cur / _fps, loc)),
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _overview(t),
            const SizedBox(height: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (d) {
                if (ready) _setPos(_pos - d.delta.dx / _cw);
              },
              onHorizontalDragEnd: (_) {
                if (ready) _setPos(_pos.roundToDouble());
              },
              child: Container(
                height: 76,
                decoration: BoxDecoration(
                  color: t.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: t.colorScheme.outlineVariant),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox.expand(
                    child: CustomPaint(
                      painter: StripPainter(
                        frames: _thumbs,
                        count: _n,
                        pos: _pos,
                        markers: _m,
                        tw: _tw,
                        th: _th,
                        cw: _cw,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Flèches en icônes : ◀ / ▶ deviendraient des emojis sur Android.
                // Boutons étroits (4 par ligne) : marges réduites et contenu réduit
                // si besoin, pour ne jamais déborder sur un petit écran.
                for (final st in const [(-5, '−5'), (-1, '−1'), (1, '+1'), (5, '+5')]) ...[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                      onPressed: ready ? () => _step(st.$1) : null,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (st.$1 == -1) const Icon(Icons.arrow_left_rounded, size: 22),
                            Text(st.$2),
                            if (st.$1 == 1) const Icon(Icons.arrow_right_rounded, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (st.$1 != 5) const SizedBox(width: 6),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  Expanded(
                    child: _sel == i
                        ? FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: markerColors[i],
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                            ),
                            onPressed: ready ? () => _tapMarker(i) : null,
                            child: _markerLabel(l, i),
                          )
                        : OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: markerColors[i],
                              side: BorderSide(color: markerColors[i]),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                            ),
                            onPressed: ready ? () => _tapMarker(i) : null,
                            child: _markerLabel(l, i),
                          ),
                  ),
                  if (i < 2) const SizedBox(width: 6),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(_hint(l), style: muted),
            ..._results(l, muted),
            if (info != null && !_busy && _n > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l.videoInfo(info.width, info.height, fmtTrim(_fps, loc), fmt1(info.durationMs / 1000, loc)),
                  style: muted.copyWith(fontSize: 11),
                ),
              ),
            const SizedBox(height: 8),
            Text(l.stripHelp, style: muted),
          ],
        ),
      ),
    );
  }

  Widget _markerLabel(AppLocalizations l, int i) {
    final name = markerName(l, i);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        _m[i] == null ? '$name —' : '$name · ${_m[i]}',
        maxLines: 1,
      ),
    );
  }

  Widget _overview(ThemeData t) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        double x(num i) => _n > 1 ? w * i / (_n - 1) : 0.0;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            if (_n > 1 && !_busy) _setPos(d.localPosition.dx / w * (_n - 1));
          },
          child: SizedBox(
            height: 20,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 3,
                  height: 14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: t.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                ),
                for (var k = 0; k < 3; k++)
                  if (_m[k] != null && _n > 1)
                    Positioned(
                      left: x(_m[k]!) - 3,
                      top: 3,
                      width: 6,
                      height: 14,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: markerColors[k],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                if (_n > 1)
                  Positioned(
                    left: x(_pos) - 1.5,
                    top: 0,
                    width: 3,
                    height: 20,
                    child: ColoredBox(color: t.colorScheme.onSurface),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

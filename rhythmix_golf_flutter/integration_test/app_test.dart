// Tests sur appareil (simulateur iOS, émulateur Android ou téléphone branché).
// Ils vérifient ce que les tests sur ordinateur ne peuvent pas couvrir :
//   - le décodage vidéo natif (AVFoundation sur iOS, MediaCodec sur Android) ;
//   - le son réel du métronome (just_audio, session audio) ;
//   - les vrais plugins (shared_preferences, achat intégré).
//
// Lancer :  flutter test integration_test            (appareil par défaut)
//           flutter test integration_test -d <id>    (voir flutter devices)

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rhythmix_golf/app_state.dart';
import 'package:rhythmix_golf/detection.dart';
import 'package:rhythmix_golf/main.dart';
import 'package:rhythmix_golf/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'swing_video.g.dart';

/// Écart toléré entre le repère détecté et la vérité terrain (images).
/// Le décodage varie un peu selon l'appareil ; le site trouve 49 / 99 / 112.
const _tol = 4;

class _Picker extends ImagePickerPlatform {
  _Picker(this.path);
  final String path;
  @override
  Future<XFile?> getVideo({
    required ImageSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    Duration? maxDuration,
  }) async =>
      XFile(path);
}

Future<String> _videoFile() async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/rhythmix_swing_test.mp4');
  await f.writeAsBytes(base64Decode(swingVideoBase64), flush: true);
  return f.path;
}

Future<AppState> _startApp(WidgetTester t) async {
  final p = await SharedPreferences.getInstance();
  await p.clear();
  final s = AppState();
  await s.load();
  await t.pumpWidget(RhythmixApp(state: s));
  await t.pumpAndSettle();
  return s;
}

/// Fait défiler jusqu'au bouton (petits écrans) puis le touche.
Future<void> _tapVisible(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
}

Future<void> _waitFor(WidgetTester t, Finder f, {Duration timeout = const Duration(seconds: 90)}) async {
  final end = DateTime.now().add(timeout);
  while (f.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) fail('introuvable après ${timeout.inSeconds} s : $f');
    await t.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('décodage vidéo natif', () {
    late String path;
    setUpAll(() async => path = await _videoFile());

    testWidgets('informations : taille, cadence, nombre d’images, durée', (t) async {
      final info = await NativeVideo.info(path);
      expect(info.width, swingTruth.width);
      expect(info.height, swingTruth.height);
      expect(info.fps, closeTo(swingTruth.fps, 0.5));
      expect(info.frameCount, inInclusiveRange(swingTruth.frames - 1, swingTruth.frames));
      expect(info.durationMs, closeTo(swingTruth.frames / swingTruth.fps * 1000, 40));
    });

    testWidgets('images exactes, son, aperçu, puis détection proche de la vérité', (t) async {
      final info = await NativeVideo.info(path);
      final fps = info.fps;
      final n = math.min((info.durationMs / 1000 * fps).floor(), info.frameCount);
      // même réduction que lib/video_card.dart
      var aw = info.width, ah = info.height;
      while (math.min(aw, ah) / 2 >= 120) {
        aw = jr(aw / 2);
        ah = jr(ah / 2);
      }
      const th = 64;
      final tw = math.max(24, jr(th * info.width / info.height));
      final big = <Uint8List>[], lum = <Float32List>[];
      for (var start = 0; start < n; start += 30) {
        final c = math.min(30, n - start);
        final b = await NativeVideo.frames(
            path: path, start: start, count: c, aw: aw, ah: ah, tw: tw, th: th, fps: fps, frameCount: info.frameCount);
        expect(b.gray.length, c * aw * ah);
        expect(b.rgba.length, c * tw * th * 4);
        for (var k = 0; k < c; k++) {
          final g = Uint8List.sublistView(b.gray, k * aw * ah, (k + 1) * aw * ah);
          big.add(g);
          lum.add(thumbLuma(g, aw, ah, tw, th));
        }
      }
      final q = motionCurve(lum);
      // immobile avant le départ, mouvement pendant le swing
      expect(q.sublist(5, swingTruth.start - 4).reduce(math.max), lessThan(0.2));
      expect(q.reduce(math.max), greaterThan(0.5));

      final env = await NativeVideo.audioEnvelope(path);
      expect(env, isNotNull);
      final au = audioImpact(env)!;
      expect(au.t, closeTo(swingTruth.impact / swingTruth.fps, 0.06), reason: 'bruit de la balle');

      final pv = await NativeVideo.preview(path: path, index: swingTruth.top, fps: fps, frameCount: info.frameCount);
      expect(pv, isNotNull);
      expect(pv!.sublist(0, 2), [0xFF, 0xD8], reason: 'aperçu JPEG');

      final det = detectGrand(q: q, fps: fps, p: kParams['grand']!, au: au, big: big, aw: aw, ah: ah);
      final m = det.markers;
      expect(det.audioT, isNotNull);
      expect(m[0], closeTo(swingTruth.start, _tol), reason: 'départ');
      expect(m[1], closeTo(swingTruth.top, _tol), reason: 'sommet');
      expect(m[2], closeTo(swingTruth.impact, _tol), reason: 'impact');
      final putt = detectPutt(q: q, fps: fps).markers;
      expect(putt[0] < putt[1] && putt[1] < putt[2], isTrue);
    });
  });

  group('application complète', () {
    testWidgets('métronome : valeurs par défaut, mode putting, son réel démarré puis arrêté', (t) async {
      final s = await _startApp(t);
      expect(find.text('Métronome · grand jeu 3:1'), findsOneWidget);
      expect(find.text('Montée 0,81 s · Descente 0,27 s · Ratio 3,00:1 · Swing 1,08 s'), findsOneWidget);

      await _tapVisible(t, find.text('⛳ Putting'));
      await t.pumpAndSettle();
      expect(find.text('Métronome · putting 2:1'), findsOneWidget);
      expect(find.text('Montée 0,60 s · Descente 0,30 s · Ratio 2,00:1 · Swing 0,90 s'), findsOneWidget);

      await _tapVisible(t, find.text('▶ Démarrer'));
      await t.pump(const Duration(seconds: 1));
      expect(s.running, isTrue);
      expect(find.text('■ Arrêter'), findsOneWidget);
      // les étiquettes suivent le son réellement joué
      await _waitFor(t, find.byWidgetPredicate((w) => w is Text && ['Départ', 'Sommet', 'Impact'].contains(w.data)),
          timeout: const Duration(seconds: 10));
      await _tapVisible(t, find.text('■ Arrêter'));
      await t.pump(const Duration(milliseconds: 500));
      expect(s.running, isFalse);
      expect(find.text('▶ Démarrer'), findsOneWidget);

      final p = await SharedPreferences.getInstance();
      expect(p.getString('mode'), 'putt', reason: 'réglages enregistrés sur l’appareil');
    });

    testWidgets('analyse d’une vidéo de la galerie de bout en bout', (t) async {
      ImagePickerPlatform.instance = _Picker(await _videoFile());
      final s = await _startApp(t);
      await _tapVisible(t, find.text('Choisir une vidéo'));
      await _waitFor(t, find.textContaining('Détection terminée'));
      await t.pumpAndSettle();

      expect(find.textContaining('impact repéré grâce au bruit de la balle'), findsOneWidget);
      expect(find.textContaining('Ton rythme : montée'), findsOneWidget);
      expect(find.text('Vidéo : 270 × 480 · 60 images/s · 3,0 s'), findsOneWidget);
      expect(s.purchase.used, 1);
      final h = s.history['grand']!.single;
      expect(h.ratio, inInclusiveRange(2.0, 5.0));
      // métronome réglé sur le tempo cible : montée = 3 x descente
      expect(s.cur.b, closeTo(s.cur.d * 3, 1e-9));
      expect(s.cur.d, closeTo(h.d, 0.006));
    });
  });
}

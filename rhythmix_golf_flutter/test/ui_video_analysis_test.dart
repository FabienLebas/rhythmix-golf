// Interface : parcours complet d'analyse vidéo (lib/video_card.dart), avec une
// fausse galerie / caméra et un faux décodeur natif (canal « rhythmix_native »).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:rhythmix_golf/app_state.dart';
import 'package:rhythmix_golf/detection.dart';

import 'helpers.dart';

/// Repères attendus : même chaîne de calcul que l'app, appliquée aux images
/// du faux décodeur (vérifie le découpage par lots, la taille des images…).
List<int> expectedMarkers(FakeVideo v, String mode) {
  const aw = 120, ah = 216, tw = 36, th = 64; // 120 x 216 : pas de réduction
  final big = [for (var i = 0; i < v.frames; i++) v.gray(i, aw, ah)];
  final q = motionCurve([for (final g in big) thumbLuma(g, aw, ah, tw, th)]);
  if (mode == 'putt') return detectPutt(q: q, fps: v.fps).markers;
  return detectGrand(q: q, fps: v.fps, p: kParams['grand']!, au: audioImpact(v.envelope()), big: big, aw: aw, ah: ah)
      .markers;
}

Finder markerButton(String name) => find.byWidgetPredicate(
    (w) => w is Text && (w.data ?? '').startsWith(name) && ((w.data ?? '').contains('·') || (w.data ?? '').contains('—')));

String markerText(WidgetTester t, String name) => t.widget<Text>(markerButton(name)).data!;

Future<(AppState, FakeVideo, FakeImagePicker)> setup(WidgetTester t,
    {FakeVideo? video, Map<String, Object> prefs = const {}}) async {
  final v = video ?? FakeVideo();
  final picker = FakeImagePicker();
  ImagePickerPlatform.instance = picker;
  v.install(t);
  addTearDown(() =>
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('rhythmix_native'), null));
  final s = await pumpApp(t, prefs: prefs);
  return (s, v, picker);
}

Future<void> analyse(WidgetTester t, {String button = 'Choisir une vidéo'}) async {
  await t.tap(find.text(button));
  await pumpUntil(t, () => find.textContaining('Détection terminée').evaluate().isNotEmpty ||
      find.textContaining('Impossible').evaluate().isNotEmpty);
  await t.pump();
}

String f2(double x) => x.toStringAsFixed(2).replaceAll('.', ',');

void main() {
  setUp(() => installFakeStore());

  testWidgets('avant toute vidéo : boutons de repères inactifs', (t) async {
    await setup(t);
    expect(find.text('Filmer'), findsOneWidget);
    expect(find.text('Choisir une vidéo'), findsOneWidget);
    expect(find.text('Départ —'), findsOneWidget);
    expect(find.text('Sommet —'), findsOneWidget);
    expect(find.text('Impact —'), findsOneWidget);
    expect(t.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '+1 ▶')).onPressed, isNull);
  });

  testWidgets('analyse réussie : repères, tempo, conseil, métronome réglé, historique, gratuité', (t) async {
    final (s, v, picker) = await setup(t);
    await analyse(t);
    expect(picker.calls, [ImageSource.gallery]);
    expect(v.calls.where((c) => c == 'info').length, 1);
    expect(v.calls.where((c) => c == 'frames').length, 4, reason: '120 images lues par lots de 30');
    expect(v.calls, contains('audioEnvelope'));

    final m = expectedMarkers(v, 'grand');
    expect(m[2], v.impact, reason: 'impact au bruit de la balle');
    expect(markerText(t, 'Départ'), 'Départ · ${m[0]}');
    expect(markerText(t, 'Sommet'), 'Sommet · ${m[1]}');
    expect(markerText(t, 'Impact'), 'Impact · ${m[2]}');
    expect(find.textContaining('impact repéré grâce au bruit de la balle, à 1,42 s'), findsOneWidget);

    final b = (m[1] - m[0]) / 60, d = (m[2] - m[1]) / 60;
    expect(
        find.text('Ton rythme : montée ${f2(b)} s, descente ${f2(d)} s, '
            'ratio ${(b / d).toStringAsFixed(1).replaceAll('.', ',')}:1 (swing ${f2(b + d)} s).'),
        findsOneWidget);
    final dd = round2(d);
    expect(find.text('Le métronome est réglé sur ton tempo cible grand jeu 3:1 : montée ${f2(dd * 3)} s, descente ${f2(dd)} s.'),
        findsOneWidget);
    // métronome réglé sur le tempo cible (descente gardée, montée = 3 x descente)
    expect(s.cur.d, dd);
    expect(s.cur.b, closeTo(dd * 3, 1e-9));
    // un point dans l'historique, une analyse gratuite consommée
    expect(s.history['grand']!.length, 1);
    expect(s.history['grand']!.single.ratio, closeTo(b / d, 1e-9));
    expect(s.purchase.used, 1);
    expect(find.textContaining('il t’en reste 2 sur 3'), findsOneWidget);
    expect(find.text('Vidéo : 120 × 216 · 60 images/s · 2,0 s'), findsOneWidget);
    expect(find.text('Image ${m[0]} / 119 · ${(m[0] / 60).toStringAsFixed(3)} s'), findsOneWidget);
  });

  testWidgets('« Filmer » ouvre la caméra', (t) async {
    final (_, _, picker) = await setup(t);
    await analyse(t, button: 'Filmer');
    expect(picker.calls, [ImageSource.camera]);
  });

  testWidgets('retoucher un repère : tempo recalculé, même point d’historique, rien de consommé', (t) async {
    final (s, v, _) = await setup(t);
    await analyse(t);
    final m = expectedMarkers(v, 'grand');
    await t.tap(markerButton('Impact'));
    await t.pump();
    await t.tap(find.text('+1 ▶'));
    await t.pump();
    expect(markerText(t, 'Impact'), 'Impact · ${m[2] + 1}');
    await t.tap(find.text('+5'));
    await t.pump();
    expect(markerText(t, 'Impact'), 'Impact · ${m[2] + 6}');
    await t.tap(find.text('−5'));
    await t.tap(find.text('◀ −1'));
    await t.tap(find.text('◀ −1'));
    await t.pump();
    expect(markerText(t, 'Impact'), 'Impact · ${m[2] - 1}');
    final d = (m[2] - 1 - m[1]) / 60;
    expect(s.cur.d, round2(d));
    expect(s.history['grand']!.length, 1);
    expect(s.history['grand']!.single.d, closeTo(d, 1e-9));
    expect(s.purchase.used, 1);
  });

  testWidgets('repères dans le mauvais ordre : message', (t) async {
    final (_, v, _) = await setup(t);
    await analyse(t);
    final m = expectedMarkers(v, 'grand');
    // après la détection, Départ est déjà sélectionné : l'amener après le sommet
    for (var i = 0; i < (m[1] - m[0]) ~/ 5 + 1; i++) {
      await t.tap(find.text('+5'));
    }
    await t.pump();
    expect(find.text('L’ordre doit être : départ, sommet, impact.'), findsOneWidget);
  });

  testWidgets('toucher le repère sélectionné le désélectionne : la bande ne le déplace plus', (t) async {
    final (_, v, _) = await setup(t);
    await analyse(t);
    final m = expectedMarkers(v, 'grand');
    await t.tap(markerButton('Départ')); // sélectionné après la détection -> désélectionné
    await t.pump();
    await t.tap(find.text('+5'));
    await t.pump();
    expect(markerText(t, 'Départ'), 'Départ · ${m[0]}');
    expect(find.text('Image ${m[0] + 5} / 119 · ${((m[0] + 5) / 60).toStringAsFixed(3)} s'), findsOneWidget);
  });

  testWidgets('changer de mode après l’analyse : nouvelle détection (putt), sans consommer', (t) async {
    final (s, v, _) = await setup(t);
    await analyse(t);
    await t.tap(find.text('⛳ Putting'));
    await t.pumpAndSettle();
    final m = expectedMarkers(v, 'putt');
    expect(markerText(t, 'Départ'), 'Départ · ${m[0]}');
    expect(markerText(t, 'Impact'), 'Impact · ${m[2]}');
    expect(find.textContaining('putt : repérage par le mouvement, sans le son'), findsOneWidget);
    expect(find.textContaining('tempo cible putting 2:1'), findsOneWidget);
    expect(s.purchase.used, 1);
    expect(s.history['putt']!.length, 1);
    expect(s.history['grand']!.length, 1);
  });

  testWidgets('sans son exploitable : impact estimé d’après le mouvement', (t) async {
    await setup(t, video: FakeVideo(withSound: false));
    await analyse(t);
    expect(find.textContaining('son non exploitable'), findsOneWidget);
  });

  testWidgets('gratuité épuisée : fenêtre d’achat avant d’ouvrir la galerie', (t) async {
    final (_, _, picker) = await setup(t, prefs: {'free_analyses_used': 3});
    await t.tap(find.text('Choisir une vidéo'));
    await t.pumpAndSettle();
    expect(find.text('Pour le prix d’un seau de balles'), findsOneWidget);
    await t.tap(find.text('Fermer'));
    await t.pumpAndSettle();
    expect(picker.calls, isEmpty);
  });

  testWidgets('après achat : analyses illimitées', (t) async {
    final (s, _, picker) = await setup(t, prefs: {'free_analyses_used': 3, 'unlocked': true});
    await analyse(t);
    expect(picker.calls, [ImageSource.gallery]);
    expect(s.purchase.used, 3);
  });

  testWidgets('sélection annulée : rien ne change', (t) async {
    final (s, v, picker) = await setup(t);
    picker.path = null;
    await t.tap(find.text('Choisir une vidéo'));
    await t.pump();
    expect(v.calls, isEmpty);
    expect(s.purchase.used, 0);
  });

  testWidgets('vidéo trop courte : message, analyse non décomptée', (t) async {
    final (s, _, _) = await setup(t, video: FakeVideo(frames: 6, start: 1, top: 3, impact: 4));
    await analyse(t);
    expect(find.text('Impossible d’analyser cette vidéo (Exception: vidéo trop courte).'), findsOneWidget);
    expect(s.purchase.used, 0);
    expect(s.history['grand'], isEmpty);
  });

  testWidgets('vidéo sans mouvement : message, analyse non décomptée', (t) async {
    final (s, _, _) = await setup(t, video: FakeVideo(start: 500, top: 600, impact: 700));
    await analyse(t);
    expect(find.text('Impossible d’analyser cette vidéo (Exception: aucun mouvement détecté).'), findsOneWidget);
    expect(s.purchase.used, 0);
  });

  testWidgets('vidéo illisible (le décodeur échoue) : message', (t) async {
    final (s, _, _) = await setup(t);
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('rhythmix_native'), (c) async {
      throw PlatformException(code: 'decode', message: 'format inconnu');
    });
    await analyse(t);
    expect(find.textContaining('Impossible d’analyser cette vidéo'), findsOneWidget);
    expect(s.purchase.used, 0);
    expect(find.text('Choisir une vidéo'), findsOneWidget);
    expect(t.widget<FilledButton>(find.ancestor(of: find.text('Choisir une vidéo'), matching: find.byWidgetPredicate((w) => w is FilledButton))).onPressed,
        isNotNull,
        reason: 'on peut réessayer');
  });

  test('le faux décodeur produit une vraie courbe de swing', () {
    final v = FakeVideo();
    final big = [for (var i = 0; i < v.frames; i++) v.gray(i, 120, 216)];
    final q = motionCurve([for (final g in big) thumbLuma(g, 120, 216, 36, 64)]);
    expect(q.sublist(0, 25).reduce(math.max), 0);
    expect(q.reduce(math.max), greaterThan(0.003));
  });
}

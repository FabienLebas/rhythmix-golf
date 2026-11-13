// Interface : écran d'accueil, choix du mode, carte du métronome.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rhythmix_golf/history_card.dart';
import 'package:rhythmix_golf/metronome_card.dart';
import 'package:rhythmix_golf/video_card.dart';

import 'helpers.dart';

Finder field(String label) => find.widgetWithText(TextField, label);
String fieldText(WidgetTester t, String label) => t.widget<TextField>(field(label)).controller!.text;

void main() {
  setUp(() => installFakeStore());

  testWidgets('écran d’accueil : mode, métronome, analyse vidéo, historique', (t) async {
    await pumpApp(t);
    expect(find.text('🏌️ Grand jeu'), findsOneWidget);
    expect(find.text('⛳ Putting'), findsOneWidget);
    expect(find.text('tempo 3 : 1'), findsOneWidget);
    expect(find.text('tempo 2 : 1'), findsOneWidget);
    expect(find.byType(MetronomeCard), findsOneWidget);
    expect(find.byType(VideoCard), findsOneWidget);
    expect(find.byType(HistoryCard), findsOneWidget);
    expect(find.text('Métronome · grand jeu 3:1'), findsOneWidget);
    expect(find.text('Analyser un grand jeu'), findsOneWidget);
    expect(find.text('Historique · grand jeu'), findsOneWidget);
    // ordre vertical sur téléphone : mode, métronome, vidéo, historique
    final y = [find.text('🏌️ Grand jeu'), find.byType(MetronomeCard), find.byType(VideoCard), find.byType(HistoryCard)]
        .map((f) => t.getTopLeft(f).dy)
        .toList();
    expect(y, orderedEquals([...y]..sort()));
  });

  testWidgets('grand écran (>= 900 px) : métronome et vidéo côte à côte', (t) async {
    await pumpApp(t, wide: true);
    final m = t.getTopLeft(find.byType(MetronomeCard)), v = t.getTopLeft(find.byType(VideoCard));
    expect(m.dy, v.dy);
    expect(v.dx, greaterThan(m.dx + 300));
    expect(t.getSize(find.byType(MetronomeCard)).width, 400);
    expect(t.getTopLeft(find.byType(HistoryCard)).dy, greaterThan(m.dy));
  });

  testWidgets('valeurs par défaut affichées', (t) async {
    await pumpApp(t);
    expect(fieldText(t, 'Montée (secondes)'), '0,81');
    expect(fieldText(t, 'Descente (secondes)'), '0,27');
    expect(find.text('Montée 0,81 s · Descente 0,27 s · Ratio 3,00:1 · Swing 1,08 s'), findsOneWidget);
    expect(find.text('Vitesse du swing : 100 %'), findsOneWidget);
    expect(find.text('Pause entre deux swings : 3,0 s'), findsOneWidget);
    expect(find.text('▶ Démarrer'), findsOneWidget);
    expect(t.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value, isTrue);
  });

  testWidgets('passer au putting puis revenir au grand jeu', (t) async {
    final s = await pumpApp(t);
    await t.tap(find.text('⛳ Putting'));
    await t.pumpAndSettle(); // le thème change avec une animation
    expect(s.mode, 'putt');
    expect(find.text('Métronome · putting 2:1'), findsOneWidget);
    expect(find.text('Analyser un putt'), findsOneWidget);
    expect(find.text('Historique · putting'), findsOneWidget);
    expect(fieldText(t, 'Montée (secondes)'), '0,60');
    expect(fieldText(t, 'Descente (secondes)'), '0,30');
    expect(find.text('Montée 0,60 s · Descente 0,30 s · Ratio 2,00:1 · Swing 0,90 s'), findsOneWidget);
    // couleur du thème : bleu au putting, vert au grand jeu
    final blue = Theme.of(t.element(find.byType(MetronomeCard))).colorScheme.primary;
    await t.tap(find.text('🏌️ Grand jeu'));
    await t.pumpAndSettle();
    expect(s.mode, 'grand');
    final green = Theme.of(t.element(find.byType(MetronomeCard))).colorScheme.primary;
    expect(green, isNot(blue));
    expect(green.b, lessThan(green.g), reason: 'grand jeu : dominante verte');
    expect(blue.b, greaterThan(blue.g), reason: 'putting : dominante bleue');
  });

  testWidgets('saisie de la montée (virgule acceptée) avec ratio gardé', (t) async {
    final s = await pumpApp(t);
    await t.enterText(field('Montée (secondes)'), '0,9');
    await t.pump();
    expect([s.cur.b, s.cur.d], [0.9, 0.3]);
    expect(fieldText(t, 'Descente (secondes)'), '0,30');
    expect(find.text('Montée 0,90 s · Descente 0,30 s · Ratio 3,00:1 · Swing 1,20 s'), findsOneWidget);
    // en quittant le champ, la valeur retenue s'affiche
    await t.enterText(field('Descente (secondes)'), '0.25');
    await t.pump();
    expect(fieldText(t, 'Montée (secondes)'), '0,75');
  });

  testWidgets('saisie invalide ignorée', (t) async {
    final s = await pumpApp(t);
    await t.enterText(field('Montée (secondes)'), 'abc');
    await t.pump();
    expect([s.cur.b, s.cur.d], [0.81, 0.27]);
  });

  testWidgets('décocher « Garder le ratio » : seule la valeur saisie change', (t) async {
    final s = await pumpApp(t);
    await t.tap(find.byType(Checkbox));
    await t.pump();
    expect(s.lock, isFalse);
    await t.enterText(field('Montée (secondes)'), '1,2');
    await t.pump();
    expect([s.cur.b, s.cur.d], [1.2, 0.27]);
  });

  testWidgets('curseur de vitesse : à droite plus rapide, ratio gardé', (t) async {
    final s = await pumpApp(t);
    final slider = find.byType(Slider).first;
    final r = t.getRect(slider);
    // 120 % = (120-60)/80 = 3/4 de la piste (piste réduite des marges du curseur)
    await t.tapAt(Offset(r.left + 24 + (r.width - 48) * 0.75, r.center.dy));
    await t.pump();
    expect(s.speed, closeTo(120, 1));
    expect(s.cur.b / s.cur.d, closeTo(3, 0.001));
    expect(s.cur.d, lessThan(0.27));
    expect(find.textContaining('Vitesse du swing : 12'), findsOneWidget);
  });

  testWidgets('« Valeurs par défaut » restaure le mode courant', (t) async {
    final s = await pumpApp(t);
    await t.enterText(field('Montée (secondes)'), '1,5');
    await t.pump();
    await t.tap(find.text('Valeurs par défaut'));
    await t.pump();
    expect([s.cur.b, s.cur.d], [0.81, 0.27]);
    expect(fieldText(t, 'Descente (secondes)'), '0,27');
  });

  testWidgets('pause entre deux swings : de 1 à 8 s', (t) async {
    final s = await pumpApp(t);
    final slider = find.byType(Slider).last;
    final r = t.getRect(slider);
    await t.tapAt(Offset(r.right - 2, r.center.dy));
    await t.pump();
    expect(s.pause, 8);
    expect(find.text('Pause entre deux swings : 8,0 s'), findsOneWidget);
    await t.tapAt(Offset(r.left + 2, r.center.dy));
    await t.pump();
    expect(s.pause, 1);
  });

  testWidgets('Démarrer / Arrêter le métronome, étiquette du temps en cours', (t) async {
    final m = FakeMetronome();
    await pumpApp(t, metronome: m);
    await t.tap(find.text('▶ Démarrer'));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('■ Arrêter'), findsOneWidget);
    expect(m.starts.single, (0.81, 0.27, 3.0));
    expect(find.text('Départ'), findsOneWidget, reason: 'étiquette du bip en cours');
    await t.tap(find.text('■ Arrêter'));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('▶ Démarrer'), findsOneWidget);
    expect(m.stops, 1);
    expect(find.text('Départ'), findsNothing);
  });

  testWidgets('réglages relus au démarrage de l’app', (t) async {
    await pumpApp(t, prefs: {'mode': 'putt', 'putt_b': 0.7, 'putt_d': 0.35, 'pause': 5.0, 'lock': false});
    expect(find.text('Métronome · putting 2:1'), findsOneWidget);
    expect(fieldText(t, 'Montée (secondes)'), '0,70');
    expect(find.text('Pause entre deux swings : 5,0 s'), findsOneWidget);
    expect(t.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value, isFalse);
  });
}

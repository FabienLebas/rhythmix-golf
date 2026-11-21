// Langues (français, anglais, espagnol) : cohérence des fichiers de traduction,
// choix de la langue, formats de nombres / dates / prix, et rendu de l'interface.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rhythmix_golf/format.dart';
import 'package:rhythmix_golf/l10n/app_localizations.dart';
import 'package:rhythmix_golf/main.dart';

import 'helpers.dart';

Map<String, String> arb(String lang) {
  final j = jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final e in j.entries)
      if (!e.key.startsWith('@')) e.key: '${e.value}',
  };
}

/// Noms des {variables} d'un message. Les mots-clés ICU (plural, select) et
/// les textes des branches sont écartés : seules les variables comptent.
Set<String> placeholders(String msg) {
  final names = <String>{};
  for (final m in RegExp(r'\{(\w+)(?:,|\})').allMatches(msg)) {
    names.add(m.group(1)!);
  }
  return names;
}

// Fin des phrases qui incitent à payer (encadré de gratuité).
const enMore = ', and you’ll have the app to analyze as many swings as you want and track your progress over time.';
const esMore = ', y tendrás la app para analizar tantos swings como quieras y así comprobar tus progresos con el tiempo.';

void main() {
  setUpAll(() => initializeDateFormatting());
  setUp(() => installFakeStore());

  group('fichiers de traduction', () {
    final fr = arb('fr'), en = arb('en'), es = arb('es');

    test('les trois langues ont exactement les mêmes clés', () {
      final keys = fr.keys.toSet()..remove('@@locale');
      expect(en.keys.toSet()..remove('@@locale'), keys, reason: 'anglais');
      expect(es.keys.toSet()..remove('@@locale'), keys, reason: 'espagnol');
    });

    test('chaque message garde les mêmes variables dans les trois langues', () {
      for (final k in fr.keys.where((k) => k != '@@locale')) {
        expect(placeholders(en[k]!), placeholders(fr[k]!), reason: 'anglais : $k');
        expect(placeholders(es[k]!), placeholders(fr[k]!), reason: 'espagnol : $k');
      }
    });

    test('aucun message vide ni resté en français dans les autres langues', () {
      for (final k in fr.keys.where((k) => k != '@@locale')) {
        expect(en[k]!.trim(), isNotEmpty, reason: 'anglais : $k');
        expect(es[k]!.trim(), isNotEmpty, reason: 'espagnol : $k');
      }
      // Les textes longs ne doivent pas être identiques au français (oubli de traduction).
      for (final k in ['filmTip', 'stripHelp', 'metroHelp', 'payBody', 'historyEmpty', 'advicePuttSlow']) {
        expect(en[k], isNot(fr[k]), reason: 'anglais : $k');
        expect(es[k], isNot(fr[k]), reason: 'espagnol : $k');
      }
    });
  });

  group('choix de la langue', () {
    const supported = [Locale('en'), Locale('es'), Locale('fr')];
    Locale pick(List<Locale>? l) => resolveAppLocale(l, supported);

    test('la langue de l’appareil, région comprise ou non', () {
      expect(pick(const [Locale('fr')]), const Locale('fr'));
      expect(pick(const [Locale('fr', 'CA')]), const Locale('fr'));
      expect(pick(const [Locale('es', 'MX')]), const Locale('es'));
      expect(pick(const [Locale('en', 'GB')]), const Locale('en'));
    });

    test('première langue préférée que l’app traduit', () {
      expect(pick(const [Locale('de'), Locale('es'), Locale('fr')]), const Locale('es'));
    });

    test('langue non traduite ou inconnue : anglais', () {
      expect(pick(const [Locale('de')]), const Locale('en'));
      expect(pick(const [Locale('ja'), Locale('pt', 'BR')]), const Locale('en'));
      expect(pick(const []), const Locale('en'));
      expect(pick(null), const Locale('en'));
    });

    test('l’application déclare bien les trois langues', () {
      expect(AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet(), {'fr', 'en', 'es'});
    });
  });

  group('formats', () {
    test('nombres : virgule en français et en espagnol, point en anglais', () {
      expect(fmt2(0.81, 'fr'), '0,81');
      expect(fmt2(0.81, 'es'), '0,81');
      expect(fmt2(0.81, 'en'), '0.81');
      expect(fmt1(3.0, 'fr'), '3,0');
      expect(fmt1(3.0, 'en'), '3.0');
      expect(fmt3(0.5, 'es'), '0,500');
      expect(fmt2(1.5, 'fr'), '1,50');
    });

    test('arrondi inchangé (comme toStringAsFixed)', () {
      expect(fmt2(0.225, 'en'), 0.225.toStringAsFixed(2));
      expect(fmt2(1.005, 'en'), 1.005.toStringAsFixed(2));
    });

    test('fmtTrim : sans zéros inutiles', () {
      expect(fmtTrim(60, 'fr'), '60');
      expect(fmtTrim(29.97, 'fr'), '29,97');
      expect(fmtTrim(29.97, 'en'), '29.97');
      expect(fmtTrim(1.42, 'es'), '1,42');
    });

    test('jour et mois courts', () {
      final d = DateTime(2026, 3, 14);
      expect(fmtDay(d, 'fr'), '14 mars');
      expect(fmtDay(d, 'en'), 'Mar 14');
      expect(fmtDay(d, 'es'), '14 mar');
      expect(fmtDay(DateTime(2026, 11, 2), 'fr'), '2 nov.');
    });

    test('prix : devise du store, présentation de la langue de l’app', () {
      String plain(String s) => s.replaceAll(RegExp(r'\s'), ' ');
      expect(plain(fmtMoney(4.99, 'EUR', 'fr')), '4,99 €');
      expect(plain(fmtMoney(4.99, 'EUR', 'es')), '4,99 €');
      expect(fmtMoney(4.99, 'USD', 'en'), r'$4.99');
      expect(fmtMoney(4.99, 'GBP', 'en'), '£4.99');
      expect(fmtMoney(4.99, 'EUR', 'en'), '€4.99');
    });
  });

  group('textes générés', () {
    test('pluriels et sélection grand jeu / putting', () async {
      final fr = await AppLocalizations.delegate.load(const Locale('fr'));
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      final es = await AppLocalizations.delegate.load(const Locale('es'));
      expect(fr.payLeft(1), 'Il te reste 1 analyse gratuite.');
      expect(fr.payLeft(2), 'Il te reste 2 analyses gratuites.');
      expect(en.payLeft(1), 'You have 1 free analysis left.');
      expect(en.payLeft(2), 'You have 2 free analyses left.');
      expect(es.payLeft(1), 'Te queda 1 análisis gratis.');
      expect(es.payLeft(2), 'Te quedan 2 análisis gratis.');
      expect(en.metroTitle('grand'), 'Metronome · full swing 3:1');
      expect(en.metroTitle('putt'), 'Metronome · putting 2:1');
      expect(es.historyClearTitle('putt'), '¿Borrar el historial del putting?');
      expect(en.resultMetroSet('putt', 2, '0.60', '0.30'),
          'The metronome is set to your target putting tempo 2:1: backswing 0.60 s, downswing 0.30 s.');
    });
  });

  group('interface en anglais', () {
    const en = Locale('en');

    testWidgets('écran d’accueil, métronome (point décimal), historique', (t) async {
      final day = DateTime(2026, 3, 14, 10).millisecondsSinceEpoch;
      await pumpApp(t, locale: en, prefs: {
        'history_grand': jsonEncode([
          {'id': 'a-grand', 't': day, 'b': 0.95, 'd': 0.27},
        ]),
      });
      expect(find.text('🏌️ Full swing'), findsOneWidget);
      expect(find.text('3 : 1 tempo'), findsOneWidget);
      expect(find.text('Metronome · full swing 3:1'), findsOneWidget);
      expect(find.text('Analyze a full swing'), findsOneWidget);
      expect(find.text('History · full swing'), findsOneWidget);
      expect(find.text('Backswing 0.81 s · Downswing 0.27 s · Ratio 3.00:1 · Swing 1.08 s'), findsOneWidget);
      expect(find.text('Swing speed: 100%'), findsOneWidget);
      expect(find.text('Pause between swings: 3.0 s'), findsOneWidget);
      expect(find.text('▶ Start'), findsOneWidget);
      expect(find.text('Record'), findsOneWidget);
      expect(find.text('Choose a video'), findsOneWidget);
      expect(find.text('Start —'), findsOneWidget);
      expect(find.text('Mar 14 · 3.5:1'), findsOneWidget);
      expect(find.text('Too slow'), findsOneWidget);
      // les champs de saisie montrent aussi le point décimal
      expect(find.widgetWithText(TextField, '0.81'), findsOneWidget);
      expect(find.widgetWithText(TextField, '0.27'), findsOneWidget);
    });

    testWidgets('mode putting', (t) async {
      await pumpApp(t, locale: en);
      await t.tap(find.text('⛳ Putting'));
      await t.pumpAndSettle();
      expect(find.text('Metronome · putting 2:1'), findsOneWidget);
      expect(find.text('Analyze a putt'), findsOneWidget);
      expect(find.text('History · putting'), findsOneWidget);
      expect(find.text('Backswing 0.60 s · Downswing 0.30 s · Ratio 2.00:1 · Swing 0.90 s'), findsOneWidget);
    });

    testWidgets('métronome en marche : le temps en cours est affiché dans la langue', (t) async {
      await pumpApp(t, locale: en);
      await t.tap(find.text('▶ Start'));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('■ Stop'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget, reason: 'étiquette du bip en cours');
      await t.tap(find.text('■ Stop'));
      await t.pumpAndSettle();
    });

    testWidgets('encadré et fenêtre d’achat en dollars : lancement 2,99, puis 4,99', (t) async {
      installFakeStore(products: [fakeProduct(price: r'$2.99', raw: 2.99, currency: 'USD')]);
      await pumpApp(t, locale: en, prefs: {'free_analyses_used': 3});
      expect(
          find.textContaining('🔒 Your 3 free analyses have been used. To keep analyzing your swings, get unlimited analyses for life '
              'for the price of a bucket of range balls! \$2.99 launch price instead of \$4.99.'),
          findsOneWidget);
      await t.tap(find.text('Unlock'));
      await t.pumpAndSettle();
      expect(find.text('For the price of a bucket of range balls'), findsOneWidget);
      expect(find.text('Your 3 free analyses have been used.'), findsOneWidget);
      expect(find.text('Unlock unlimited video analyses with a single payment: no subscription, no surprises.'),
          findsOneWidget);
      expect(find.text(r'Unlock for $2.99'), findsOneWidget);
      expect(find.text('Restore purchases'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      final rich = t.widgetList<RichText>(find.byType(RichText)).map((r) => r.text.toPlainText());
      expect(rich, contains(r'Launch price  $4.99'));
    });

    testWidgets('en livres : lancement 2,99 £, puis 4,99 £', (t) async {
      installFakeStore(products: [fakeProduct(price: '£2.99', raw: 2.99, currency: 'GBP')]);
      await pumpApp(t, locale: en);
      expect(
          find.text('🎁 The first 3 video analyses are free. After that, a single payment, '
              'for the price of a bucket of range balls: £2.99 launch price, then £4.99$enMore'),
          findsOneWidget);
    });

    testWidgets('prix normal atteint (4,99) : plus aucune mention de lancement', (t) async {
      installFakeStore(products: [fakeProduct(price: r'$4.99', raw: 4.99, currency: 'USD')]);
      await pumpApp(t, locale: en, prefs: {'free_analyses_used': 3});
      expect(find.textContaining('for the price of a bucket of range balls! \$4.99.'), findsOneWidget);
      expect(find.textContaining('launch price'), findsNothing);
      await t.tap(find.text('Unlock'));
      await t.pumpAndSettle();
      expect(find.text(r'Unlock for $4.99'), findsOneWidget);
      final rich = t.widgetList<RichText>(find.byType(RichText)).map((r) => r.text.toPlainText());
      expect(rich.where((s) => s.contains('Launch price')), isEmpty);
    });

    testWidgets('Canada, Japon : lancement puis prix normal dans la devise du store', (t) async {
      installFakeStore(products: [fakeProduct(price: r'CA$3.99', raw: 3.99, currency: 'CAD')]);
      await pumpApp(t, locale: en);
      expect(find.textContaining('a bucket of range balls: CA\$3.99 launch price, then ${fmtMoney(6.99, 'CAD', 'en')}$enMore'),
          findsOneWidget);
      installFakeStore(products: [fakeProduct(price: '¥480', raw: 480, currency: 'JPY')]);
      await pumpApp(t, locale: en);
      expect(find.textContaining('¥480 launch price, then ¥800$enMore'), findsOneWidget);
    });

    testWidgets('devise sans prix normal connu (SEK) : prix du store seul', (t) async {
      installFakeStore(products: [fakeProduct(price: '29 kr', raw: 29, currency: 'SEK')]);
      await pumpApp(t, locale: en);
      expect(find.textContaining('a bucket of range balls: 29 kr$enMore'), findsOneWidget);
      expect(find.textContaining('launch price'), findsNothing);
    });

    testWidgets('store muet : aucun prix annoncé', (t) async {
      installFakeStore(available: false);
      await pumpApp(t, locale: en);
      expect(
          find.text('🎁 The first 3 video analyses are free. After that, a single payment, '
              'for the price of a bucket of range balls$enMore'),
          findsOneWidget);
    });

    testWidgets('message d’erreur d’achat traduit', (t) async {
      final store = installFakeStore(products: [fakeProduct(price: r'$2.99', raw: 2.99, currency: 'USD')]);
      await pumpApp(t, locale: en, prefs: {'free_analyses_used': 3});
      await t.tap(find.text('Unlock'));
      await t.pumpAndSettle();
      await t.tap(find.text(r'Unlock for $2.99'));
      await t.pump();
      store.emit([fakePurchase(PurchaseStatus.error)]);
      await deliver(t);
      expect(find.text('Purchase failed (carte refusée).'), findsOneWidget);
    });

    testWidgets('analyse d’une vidéo : repères, conseil et métronome en anglais', (t) async {
      final v = FakeVideo();
      ImagePickerPlatform.instance = FakeImagePicker();
      v.install(t);
      addTearDown(() =>
          t.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('rhythmix_native'), null));
      installFakeStore();
      final s = await pumpApp(t, locale: en);
      await t.tap(find.text('Choose a video'));
      await pumpUntil(
          t,
          () =>
              find.textContaining('Detection complete').evaluate().isNotEmpty ||
              find.textContaining('Couldn’t analyze').evaluate().isNotEmpty);
      await t.pump();
      expect(find.textContaining('Detection complete (impact found from the sound of the ball, at 1.42 s)'),
          findsOneWidget);
      expect(find.textContaining('Check each marker: drag the frame strip'), findsOneWidget);
      expect(find.textContaining('Your tempo: backswing'), findsOneWidget);
      expect(find.textContaining('The metronome is set to your target full-swing tempo 3:1: backswing'),
          findsOneWidget);
      expect(find.text('Video: 120 × 216 · 60 frames/s · 2.0 s'), findsOneWidget);
      expect(find.textContaining('Frame '), findsWidgets);
      expect(find.textContaining('Free analyses: 2 of 3 left.'), findsOneWidget);
      expect(s.history['grand']!.length, 1);
    });

    testWidgets('vidéo trop courte : message d’erreur en anglais', (t) async {
      final v = FakeVideo(frames: 8);
      ImagePickerPlatform.instance = FakeImagePicker();
      v.install(t);
      addTearDown(() =>
          t.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('rhythmix_native'), null));
      installFakeStore();
      await pumpApp(t, locale: en);
      await t.tap(find.text('Choose a video'));
      await pumpUntil(t, () => find.textContaining('Couldn’t analyze').evaluate().isNotEmpty);
      expect(find.text('Couldn’t analyze this video (video too short).'), findsOneWidget);
    });
  });

  group('interface en espagnol', () {
    const es = Locale('es');

    testWidgets('écran d’accueil et métronome (virgule décimale)', (t) async {
      await pumpApp(t, locale: es);
      expect(find.text('🏌️ Swing completo'), findsOneWidget);
      expect(find.text('Metrónomo · swing completo 3:1'), findsOneWidget);
      expect(find.text('Analizar un swing completo'), findsOneWidget);
      expect(find.text('Historial · swing completo'), findsOneWidget);
      expect(find.text('Subida 0,81 s · Bajada 0,27 s · Proporción 3,00:1 · Swing 1,08 s'), findsOneWidget);
      expect(find.text('Velocidad del swing: 100 %'), findsOneWidget);
      expect(find.text('Pausa entre dos swings: 3,0 s'), findsOneWidget);
      expect(find.text('▶ Iniciar'), findsOneWidget);
      expect(find.text('Grabar'), findsOneWidget);
      expect(find.text('Elegir un video'), findsOneWidget);
      expect(find.text('Inicio —'), findsOneWidget);
      expect(find.text('Cima —'), findsOneWidget);
      expect(find.text('Impacto —'), findsOneWidget);
    });

    testWidgets('prix en euros : lancement 2,99 €, puis 4,99 €', (t) async {
      await pumpApp(t, locale: es);
      expect(
          find.text('🎁 Los primeros 3 análisis de video son gratis. Después, un solo pago, '
              'por el precio de un cubo de bolas: 2,99 € de precio de lanzamiento, luego ${fmtMoney(4.99, 'EUR', 'es')}$esMore'),
          findsOneWidget);
    });

    testWidgets('encadré (il en reste 1) et fenêtre d’achat', (t) async {
      await pumpApp(t, locale: es, prefs: {'free_analyses_used': 2});
      expect(find.textContaining('🎁 Análisis gratis: te quedan 1 de 3.'), findsOneWidget);
    });

    testWidgets('gratuité épuisée : fenêtre d’achat', (t) async {
      await pumpApp(t, locale: es, prefs: {'free_analyses_used': 3});
      expect(find.textContaining('🔒 Ya has usado tus 3 análisis gratis.'), findsOneWidget);
      await t.tap(find.text('Desbloquear'));
      await t.pumpAndSettle();
      expect(find.text('Por el precio de un cubo de bolas'), findsOneWidget);
      expect(find.text('Ya has usado tus 3 análisis gratis.'), findsOneWidget);
      expect(find.text('Desbloquea los análisis de video ilimitados con un solo pago: sin suscripción, sin sorpresas.'),
          findsOneWidget);
      expect(find.text('Desbloquear por 2,99 €'), findsOneWidget);
      expect(find.text('Restaurar mis compras'), findsOneWidget);
      expect(find.text('Cerrar'), findsOneWidget);
    });
  });

  testWidgets('langue non prise en charge : anglais', (t) async {
    await pumpApp(t, locale: const Locale('de'));
    expect(find.text('🏌️ Full swing'), findsOneWidget);
    expect(find.text('Metronome · full swing 3:1'), findsOneWidget);
  });

  testWidgets('le titre de l’application suit la langue', (t) async {
    await pumpApp(t, locale: const Locale('es'));
    final app = t.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.supportedLocales, AppLocalizations.supportedLocales);
    expect(app.localizationsDelegates, AppLocalizations.localizationsDelegates);
  });
}

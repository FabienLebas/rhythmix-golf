// Interface : historique du tempo, encadré de gratuité, fenêtre d'achat.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:rhythmix_golf/history_card.dart';

import 'helpers.dart';

String hist(List<(String, int, double, double)> l) =>
    jsonEncode([for (final e in l) {'id': e.$1, 't': e.$2, 'b': e.$3, 'd': e.$4}]);

final _t = DateTime(2026, 3, 14, 10).millisecondsSinceEpoch;
final _t2 = DateTime(2026, 11, 2, 10).millisecondsSinceEpoch;

void main() {
  late FakeStore store;
  setUp(() => store = installFakeStore());

  group('historique', () {
    testWidgets('vide : message d’explication, pas de bouton Effacer', (t) async {
      await pumpApp(t);
      expect(find.textContaining('Aucune analyse pour l’instant'), findsOneWidget);
      expect(find.text('Effacer cet historique'), findsNothing);
    });

    testWidgets('points, verdicts et dates (plus récent en haut)', (t) async {
      await pumpApp(t, prefs: {
        'history_grand': hist([
          ('a', _t, 1.05, 0.3), // 3,5 : trop lent
          ('b', _t, 0.9, 0.3), // 3,0 : dans la cible
          ('c', _t2, 0.75, 0.3), // 2,5 : trop rapide
        ]),
      });
      final hc = find.byType(HistoryCard);
      expect(find.descendant(of: hc, matching: find.byType(CustomPaint)), findsWidgets);
      expect(find.text('14 mars · 3,5:1'), findsOneWidget);
      expect(find.text('14 mars · 3,0:1'), findsOneWidget);
      expect(find.text('2 nov. · 2,5:1'), findsOneWidget);
      expect(find.text('Trop lent'), findsOneWidget);
      expect(find.text('Dans la cible'), findsOneWidget);
      expect(find.text('Trop rapide'), findsOneWidget);
      expect(t.getTopLeft(find.text('2 nov. · 2,5:1')).dy, lessThan(t.getTopLeft(find.text('14 mars · 3,5:1')).dy));
    });

    testWidgets('8 dernières analyses listées au maximum', (t) async {
      await pumpApp(t, prefs: {
        'history_grand': hist([for (var i = 0; i < 12; i++) ('v$i', _t, 0.9, 0.3)]),
      });
      expect(find.text('Dans la cible'), findsNWidgets(8));
    });

    testWidgets('un historique par mode', (t) async {
      await pumpApp(t, prefs: {
        'history_grand': hist([('a', _t, 0.9, 0.3)]),
        'history_putt': hist([('b', _t, 0.66, 0.3), ('c', _t, 0.6, 0.3)]),
      });
      expect(find.text('14 mars · 3,0:1'), findsOneWidget);
      await t.tap(find.text('⛳ Putting'));
      await t.pump();
      expect(find.text('Historique · putting'), findsOneWidget);
      expect(find.text('14 mars · 2,2:1'), findsOneWidget);
      expect(find.text('Trop lent'), findsOneWidget);
      expect(find.text('14 mars · 3,0:1'), findsNothing);
    });

    testWidgets('effacer : confirmation, Annuler conserve, Effacer vide le mode', (t) async {
      final s = await pumpApp(t, prefs: {
        'history_grand': hist([('a', _t, 0.9, 0.3)]),
        'history_putt': hist([('b', _t, 0.6, 0.3)]),
      });
      await t.tap(find.text('Effacer cet historique'));
      await t.pumpAndSettle();
      expect(find.text('Effacer l’historique du grand jeu ?'), findsOneWidget);
      await t.tap(find.text('Annuler'));
      await t.pumpAndSettle();
      expect(s.history['grand']!.length, 1);
      await t.tap(find.text('Effacer cet historique'));
      await t.pumpAndSettle();
      await t.tap(find.text('Effacer'));
      await t.pumpAndSettle();
      expect(s.history['grand'], isEmpty);
      expect(s.history['putt']!.length, 1);
      expect(find.textContaining('Aucune analyse pour l’instant'), findsOneWidget);
    });
  });

  group('encadré de gratuité', () {
    testWidgets('aucune analyse utilisée', (t) async {
      await pumpApp(t);
      expect(
          find.text('🎁 Les 3 premières analyses vidéo sont gratuites. Ensuite, un seul paiement, '
              'pour le prix d’un seau de balles : 2,99 € en prix de lancement, puis 4,99 €.'),
          findsOneWidget);
      expect(find.text('Débloquer'), findsNothing);
    });

    testWidgets('il en reste 1 sur 3', (t) async {
      await pumpApp(t, prefs: {'free_analyses_used': 2});
      expect(find.textContaining('🎁 Analyses gratuites : il t’en reste 1 sur 3.'), findsOneWidget);
    });

    testWidgets('épuisé : cadenas et bouton Débloquer', (t) async {
      await pumpApp(t, prefs: {'free_analyses_used': 3});
      expect(find.textContaining('🔒 Tes 3 analyses gratuites sont utilisées.'), findsOneWidget);
      expect(find.text('Débloquer'), findsOneWidget);
    });

    testWidgets('acheté : plus d’encadré', (t) async {
      await pumpApp(t, prefs: {'free_analyses_used': 3, 'unlocked': true});
      expect(find.textContaining('🎁'), findsNothing);
      expect(find.textContaining('🔒'), findsNothing);
    });
  });

  group('fenêtre d’achat', () {
    Future<void> open(WidgetTester t) async {
      await pumpApp(t, prefs: {'free_analyses_used': 3});
      await t.tap(find.text('Débloquer'));
      await t.pumpAndSettle();
    }

    testWidgets('contenu : argument, prix barré, achat, restauration', (t) async {
      await open(t);
      expect(find.text('Pour le prix d’un seau de balles'), findsOneWidget);
      expect(find.text('Tes 3 analyses gratuites sont utilisées.'), findsOneWidget);
      expect(find.textContaining('Le métronome et ton historique restent gratuits.'), findsOneWidget);
      expect(find.text('Débloquer pour 2,99 €'), findsOneWidget);
      expect(find.text('Restaurer mes achats'), findsOneWidget);
      expect(find.text('Fermer'), findsOneWidget);
      final rich = t.widgetList<RichText>(find.byType(RichText)).map((r) => r.text.toPlainText());
      expect(rich, contains('Prix de lancement  4,99 €'));
    });

    testWidgets('acheter : le store est appelé, puis écran de remerciement', (t) async {
      await open(t);
      await t.tap(find.text('Débloquer pour 2,99 €'));
      await t.pump();
      expect(store.bought, ['rhythmix_golf_unlock']);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      store.emit([fakePurchase(PurchaseStatus.purchased)]);
      await deliver(t);
      expect(find.text('Merci, c’est débloqué !'), findsOneWidget);
      await t.tap(find.text('Continuer'));
      await t.pumpAndSettle();
      expect(find.text('Pour le prix d’un seau de balles'), findsNothing);
      expect(find.textContaining('🔒'), findsNothing);
    });

    testWidgets('erreur de paiement affichée dans la fenêtre', (t) async {
      await open(t);
      await t.tap(find.text('Débloquer pour 2,99 €'));
      await t.pump();
      store.emit([fakePurchase(PurchaseStatus.error)]);
      await deliver(t);
      expect(find.text('Achat impossible (carte refusée).'), findsOneWidget);
      expect(find.text('Débloquer pour 2,99 €'), findsOneWidget);
    });

    testWidgets('restaurer mes achats', (t) async {
      store = installFakeStore(restoreWith: PurchaseStatus.restored);
      await open(t);
      await t.tap(find.text('Restaurer mes achats'));
      await t.pump();
      await deliver(t);
      expect(store.restores, 1);
      expect(find.text('Merci, c’est débloqué !'), findsOneWidget);
      await t.pump(const Duration(seconds: 7)); // délai de garde de restore()
    });

    testWidgets('Fermer referme la fenêtre', (t) async {
      await open(t);
      await t.tap(find.text('Fermer'));
      await t.pumpAndSettle();
      expect(find.text('Pour le prix d’un seau de balles'), findsNothing);
    });
  });
}

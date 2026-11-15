// Gratuité (3 analyses) et achat intégré unique (lib/purchase.dart),
// avec un faux App Store / Google Play.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:rhythmix_golf/purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<PurchaseService> service(FakeStore store, [Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = PurchaseService();
  await p.init();
  await pumpEventQueue(); // laisse le store répondre (isAvailable, produit)
  addTearDown(p.dispose);
  return p;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('constantes de l’offre inchangées', () {
    expect(kFreeAnalyses, 3);
    expect(kProductId, 'rhythmix_golf_unlock');
    expect(kRegularPrices, {'EUR': 4.99, 'USD': 4.99, 'GBP': 4.99});
  });

  group('gratuité', () {
    test('3 analyses gratuites, puis blocage', () async {
      final p = await service(installFakeStore());
      expect(p.remaining, 3);
      expect(p.canAnalyze, isTrue);
      p.recordAnalysis();
      p.recordAnalysis();
      expect(p.remaining, 1);
      expect(p.canAnalyze, isTrue);
      p.recordAnalysis();
      expect(p.remaining, 0);
      expect(p.canAnalyze, isFalse);
      p.recordAnalysis();
      expect(p.remaining, 0, reason: 'jamais négatif');
    });

    test('compteur enregistré sur l’appareil et relu', () async {
      final p = await service(installFakeStore());
      p.recordAnalysis();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('free_analyses_used'), 1);
      final p2 = await service(installFakeStore(), {'free_analyses_used': 2});
      expect(p2.remaining, 1);
    });

    test('après achat : illimité et le compteur n’avance plus', () async {
      final p = await service(installFakeStore(), {'free_analyses_used': 3, 'unlocked': true});
      expect(p.canAnalyze, isTrue);
      p.recordAnalysis();
      expect(p.used, 3);
    });
  });

  group('prix affiché', () {
    test('prix du store quand il répond', () async {
      final p = await service(installFakeStore(products: [fakeProduct(price: '3,49 €')]));
      expect(p.storeAvailable, isTrue);
      expect(p.price, '3,49 €');
    });

    test('store muet : pas de prix annoncé (on n’invente rien)', () async {
      final p = await service(installFakeStore(available: false));
      expect(p.storeAvailable, isFalse);
      expect(p.product, isNull);
      expect(p.price, isNull);
      expect(p.isLaunchPrice, isFalse);
    });
  });

  group('prix de lancement selon la devise', () {
    Future<PurchaseService> withProduct(double raw, String currency) async =>
        service(installFakeStore(products: [fakeProduct(raw: raw, currency: currency)]));

    test('2,99 en euros, dollars et livres : lancement, prix normal 4,99', () async {
      for (final c in ['EUR', 'USD', 'GBP']) {
        final p = await withProduct(2.99, c);
        expect(p.isLaunchPrice, isTrue, reason: c);
        expect(p.regularPrice, 4.99, reason: c);
      }
    });

    test('4,99 : la mention de lancement disparaît toute seule', () async {
      for (final c in ['EUR', 'USD', 'GBP']) {
        final p = await withProduct(4.99, c);
        expect(p.isLaunchPrice, isFalse, reason: c);
      }
    });

    test('devise sans prix normal connu : prix du store seul, pas de mention', () async {
      final p = await withProduct(3.99, 'CAD');
      expect(p.regularPrice, isNull);
      expect(p.isLaunchPrice, isFalse);
      expect(p.price, '2,99 €', reason: 'le prix affiché reste celui du store');
    });

    test('prix à zéro (donnée absente) : pas de mention de lancement', () async {
      final p = await withProduct(0, 'EUR');
      expect(p.isLaunchPrice, isFalse);
    });
  });

  group('achat', () {
    test('achat réussi : débloqué, enregistré, transaction terminée', () async {
      final store = installFakeStore();
      final p = await service(store, {'free_analyses_used': 3});
      await p.buy();
      expect(store.bought, [kProductId]);
      expect(p.purchasing, isTrue);
      store.emit([fakePurchase(PurchaseStatus.purchased)]);
      await pumpEventQueue();
      expect(p.unlocked, isTrue);
      expect(p.purchasing, isFalse);
      expect(p.canAnalyze, isTrue);
      expect(store.completed.length, 1, reason: 'completePurchase obligatoire, sinon remboursement auto');
      expect((await SharedPreferences.getInstance()).getBool('unlocked'), isTrue);
    });

    test('achat en attente puis validé (validation parentale…)', () async {
      final store = installFakeStore();
      final p = await service(store);
      store.emit([fakePurchase(PurchaseStatus.pending, pending: false)]);
      await pumpEventQueue();
      expect(p.purchasing, isTrue);
      expect(p.unlocked, isFalse);
      store.emit([fakePurchase(PurchaseStatus.purchased)]);
      await pumpEventQueue();
      expect(p.unlocked, isTrue);
    });

    test('achat annulé : rien n’est débloqué, interface libérée', () async {
      final store = installFakeStore();
      final p = await service(store);
      await p.buy();
      store.emit([fakePurchase(PurchaseStatus.canceled)]);
      await pumpEventQueue();
      expect(p.unlocked, isFalse);
      expect(p.purchasing, isFalse);
      expect(p.message, isNull);
    });

    test('erreur de paiement : message affiché', () async {
      final store = installFakeStore();
      final p = await service(store);
      await p.buy();
      store.emit([fakePurchase(PurchaseStatus.error)]);
      await pumpEventQueue();
      expect(p.unlocked, isFalse);
      expect(p.purchasing, isFalse);
      expect(p.message?.issue, PurchaseIssue.buyFailed);
      expect(p.message?.detail, 'carte refusée');
    });

    test('store indisponible : message, pas d’achat lancé', () async {
      final store = installFakeStore(available: false);
      final p = await service(store);
      await p.buy();
      expect(store.bought, isEmpty);
      expect(p.message?.issue, PurchaseIssue.buyUnavailable);
    });

    test('achat d’un autre produit : ignoré mais transaction terminée', () async {
      final store = installFakeStore();
      final p = await service(store);
      store.emit([fakePurchase(PurchaseStatus.purchased, productId: 'autre')]);
      await pumpEventQueue();
      expect(p.unlocked, isFalse);
      expect(store.completed.length, 1);
    });
  });

  group('restauration', () {
    test('achat restauré : débloqué', () async {
      final store = installFakeStore(restoreWith: PurchaseStatus.restored);
      final p = await service(store);
      await p.restore();
      await pumpEventQueue();
      expect(store.restores, 1);
      expect(p.unlocked, isTrue);
      expect(p.purchasing, isFalse);
    });

    test('rien à restaurer : message après 6 s', () {
      fakeAsync((async) {
        final store = installFakeStore();
        SharedPreferences.setMockInitialValues({});
        final p = PurchaseService();
        p.init();
        async.flushMicrotasks();
        expect(p.storeAvailable, isTrue);
        p.restore();
        async.flushMicrotasks();
        expect(p.purchasing, isTrue);
        async.elapse(const Duration(seconds: 6));
        expect(p.purchasing, isFalse);
        expect(p.message?.issue, PurchaseIssue.nothingToRestore);
        expect(store.restores, 1);
        p.dispose();
      });
    });

    test('store indisponible : message', () async {
      final p = await service(installFakeStore(available: false));
      await p.restore();
      expect(p.message?.issue, PurchaseIssue.storeUnavailable);
    });
  });
}

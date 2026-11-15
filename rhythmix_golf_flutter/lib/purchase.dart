import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Nombre d'analyses vidéo gratuites.
const int kFreeAnalyses = 3;

/// Identifiant du produit (achat unique, « non consommable »), à créer à
/// l'identique dans App Store Connect et dans la Google Play Console.
const String kProductId = 'rhythmix_golf_unlock';

/// Prix « normal » (après le lancement), par devise (code ISO 4217).
///
/// Les prix eux-mêmes se règlent dans App Store Connect et la Google Play
/// Console, pays par pays : l'app affiche toujours celui que le store renvoie.
/// Ce tableau sert seulement à écrire « prix de lancement, puis 4,99 € » et à
/// barrer l'ancien prix. Prix de lancement actuels : 2,99 € / 2,99 $ / 2,99 £.
///
/// - Pas de ligne pour une devise : l'app affiche le prix du store tel quel,
///   sans mention de lancement.
/// - Quand le prix du store atteint ce prix normal, la mention disparaît toute
///   seule, y compris dans les versions déjà installées : il n'y a rien à
///   changer dans l'app au passage à 4,99.
const Map<String, double> kRegularPrices = {
  'EUR': 4.99,
  'USD': 4.99,
  'GBP': 4.99,
};

/// Problèmes d'achat à signaler à l'utilisateur. Le texte est choisi par
/// l'interface (paywall.dart), selon la langue.
enum PurchaseIssue { buyUnavailable, buyFailed, restoreFailed, nothingToRestore, storeUnavailable }

class PurchaseMessage {
  const PurchaseMessage(this.issue, [this.detail]);
  final PurchaseIssue issue;

  /// Détail technique éventuel (message du store ou de l'erreur).
  final String? detail;
}

const String _kUsedKey = 'free_analyses_used';
const String _kUnlockedKey = 'unlocked';

/// Gratuité limitée + achat intégré unique (pas d'abonnement, pas de serveur).
///
/// - Les [kFreeAnalyses] premières analyses vidéo sont gratuites.
/// - Ensuite, un achat unique débloque les analyses à vie.
/// - Le métronome et l'historique restent gratuits.
class PurchaseService extends ChangeNotifier {
  int used = 0;
  bool unlocked = false;
  bool storeAvailable = false;
  bool purchasing = false;
  PurchaseMessage? message;
  ProductDetails? product;

  SharedPreferences? _prefs;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  int get remaining => math.max(0, kFreeAnalyses - used);
  bool get canAnalyze => unlocked || remaining > 0;

  /// Prix affiché : celui du store, dans la devise du pays du compte.
  /// Null tant que le store n'a pas répondu (ou s'il est indisponible).
  String? get price => product?.price;

  /// Prix normal dans la devise du store, si on le connaît ([kRegularPrices]).
  double? get regularPrice => kRegularPrices[product?.currencyCode];

  /// Vrai quand le prix du store est inférieur au prix normal : on est en
  /// période de lancement.
  bool get isLaunchPrice {
    final p = product, r = regularPrice;
    return p != null && r != null && p.rawPrice > 0 && p.rawPrice < r - 0.005;
  }

  /// Charge l'état local (rapide), puis interroge le store sans bloquer le démarrage.
  Future<void> init() async {
    try {
      final p = await SharedPreferences.getInstance();
      _prefs = p;
      used = p.getInt(_kUsedKey) ?? 0;
      unlocked = p.getBool(_kUnlockedKey) ?? false;
    } catch (_) {}
    unawaited(_initStore());
  }

  Future<void> _initStore() async {
    if (kIsWeb) return;
    try {
      final iap = InAppPurchase.instance;
      // Écouter le flux dès le démarrage : il livre aussi les achats interrompus
      // (paiement validé après la fermeture de l'app, validation parentale…).
      _sub = iap.purchaseStream.listen(_onPurchases, onError: (_) {});
      storeAvailable = await iap.isAvailable();
      if (storeAvailable) {
        final r = await iap.queryProductDetails({kProductId});
        if (r.productDetails.isNotEmpty) product = r.productDetails.first;
      }
    } catch (_) {
      storeAvailable = false;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// À appeler une fois par vidéo analysée avec succès (pas pour un échec,
  /// ni pour une retouche des repères, ni pour un changement de mode).
  void recordAnalysis() {
    if (unlocked) return;
    used++;
    _prefs?.setInt(_kUsedKey, used);
    notifyListeners();
  }

  Future<void> buy() async {
    final p = product;
    if (purchasing) return;
    if (!storeAvailable || p == null) {
      message = const PurchaseMessage(PurchaseIssue.buyUnavailable);
      notifyListeners();
      return;
    }
    message = null;
    purchasing = true;
    notifyListeners();
    try {
      final started = await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: p),
      );
      if (!started) purchasing = false;
    } catch (e) {
      purchasing = false;
      message = PurchaseMessage(PurchaseIssue.buyFailed, '$e');
    }
    notifyListeners();
  }

  /// Obligatoire pour l'App Store : retrouver un achat fait sur un autre
  /// appareil ou après une réinstallation.
  Future<void> restore() async {
    if (purchasing) return;
    if (!storeAvailable) {
      message = const PurchaseMessage(PurchaseIssue.storeUnavailable);
      notifyListeners();
      return;
    }
    message = null;
    purchasing = true;
    notifyListeners();
    try {
      await InAppPurchase.instance.restorePurchases();
      // Si rien n'est restauré, le flux n'émet rien : on libère l'interface.
      Future.delayed(const Duration(seconds: 6), () {
        if (purchasing && !unlocked) {
          purchasing = false;
          message = const PurchaseMessage(PurchaseIssue.nothingToRestore);
          notifyListeners();
        }
      });
    } catch (e) {
      purchasing = false;
      message = PurchaseMessage(PurchaseIssue.restoreFailed, '$e');
      notifyListeners();
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final d in list) {
      if (d.productID != kProductId) {
        if (d.pendingCompletePurchase) await InAppPurchase.instance.completePurchase(d);
        continue;
      }
      switch (d.status) {
        case PurchaseStatus.pending:
          purchasing = true;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _unlock();
        case PurchaseStatus.error:
          purchasing = false;
          message = PurchaseMessage(PurchaseIssue.buyFailed, d.error?.message);
        case PurchaseStatus.canceled:
          purchasing = false;
      }
      if (d.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(d);
      }
    }
    notifyListeners();
  }

  void _unlock() {
    unlocked = true;
    purchasing = false;
    message = null;
    _prefs?.setBool(_kUnlockedKey, true);
  }
}

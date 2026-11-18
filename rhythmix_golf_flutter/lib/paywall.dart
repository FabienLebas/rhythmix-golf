import 'package:flutter/material.dart';

import 'format.dart';
import 'l10n/app_localizations.dart';
import 'purchase.dart';

/// Prix normal formaté (« 4,99 € »), ou null si on ne le connaît pas.
String? regularPriceText(AppLocalizations l, PurchaseService p) {
  final r = p.regularPrice, c = p.product?.currencyCode;
  return r == null || c == null ? null : fmtMoney(r, c, l.localeName);
}

/// Texte de prix : « 2,99 € en prix de lancement, puis 4,99 € » pendant le
/// lancement, sinon le prix du store seul. Null tant que le store n'a pas
/// répondu : on n'annonce jamais un prix qu'on ne connaît pas.
String? priceLine(AppLocalizations l, PurchaseService p) {
  final price = p.price;
  if (price == null) return null;
  final regular = regularPriceText(l, p);
  return p.isLaunchPrice && regular != null ? l.priceLaunch(price, regular) : price;
}

/// « : 2,99 € … » à placer après « pour le prix d'un seau de balles ».
String _clause(AppLocalizations l, PurchaseService p) {
  final line = priceLine(l, p);
  return line == null ? '' : l.priceClause(line);
}

/// Fin de phrase du message « analyses épuisées » : « 2,99 € prix de lancement
/// au lieu de 4,99 €. » (ou le prix seul hors lancement). Vide si prix inconnu.
String _endClause(AppLocalizations l, PurchaseService p) {
  final price = p.price;
  if (price == null) return '';
  final regular = regularPriceText(l, p);
  return p.isLaunchPrice && regular != null ? l.priceEndLaunch(price, regular) : l.priceEnd(price);
}

/// Texte d'un message d'achat, dans la langue de l'app.
String purchaseMessageText(AppLocalizations l, PurchaseMessage m) {
  final d = m.detail;
  return switch (m.issue) {
    PurchaseIssue.buyUnavailable => l.msgBuyUnavailable,
    PurchaseIssue.buyFailed => d == null ? l.msgBuyFailed : l.msgBuyFailedDetail(d),
    PurchaseIssue.restoreFailed => l.msgRestoreFailed(d ?? ''),
    PurchaseIssue.nothingToRestore => l.msgNothingToRestore,
    PurchaseIssue.storeUnavailable => l.msgStoreUnavailable,
  };
}

/// Encadré permanent de la carte d'analyse : explique la gratuité limitée.
class FreeTrialBanner extends StatelessWidget {
  const FreeTrialBanner({super.key, required this.purchase});
  final PurchaseService purchase;

  @override
  Widget build(BuildContext context) {
    if (purchase.unlocked) return const SizedBox.shrink();
    final t = Theme.of(context);
    final l = AppLocalizations.of(context);
    final left = purchase.remaining;
    final clause = _clause(l, purchase);
    final String text;
    if (left == kFreeAnalyses) {
      text = l.freeIntro(kFreeAnalyses, clause);
    } else if (left > 0) {
      text = l.freeLeft(left, kFreeAnalyses, clause);
    } else {
      text = l.freeUsed(kFreeAnalyses, _endClause(l, purchase));
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: t.colorScheme.tertiaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: TextStyle(fontSize: 14, color: t.colorScheme.onTertiaryContainer)),
          if (left == 0)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => showPaywall(context, purchase),
                child: Text(l.unlock),
              ),
            ),
        ],
      ),
    );
  }
}

/// Fenêtre d'achat, ouverte quand la gratuité est épuisée (ou depuis l'encadré).
Future<void> showPaywall(BuildContext context, PurchaseService purchase) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PaywallSheet(purchase: purchase),
  );
}

class _PaywallSheet extends StatelessWidget {
  const _PaywallSheet({required this.purchase});
  final PurchaseService purchase;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: purchase,
      builder: (context, _) {
        final t = Theme.of(context);
        final l = AppLocalizations.of(context);
        final muted = TextStyle(fontSize: 14, color: t.colorScheme.onSurfaceVariant);
        if (purchase.unlocked) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 44)),
                const SizedBox(height: 8),
                Text(l.payThanks, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(l.payThanksSub, style: muted),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => Navigator.pop(context), child: Text(l.payContinue)),
              ],
            ),
          );
        }
        final busy = purchase.purchasing;
        final price = purchase.price;
        final regular = purchase.isLaunchPrice ? regularPriceText(l, purchase) : null;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: Text('⛳🪣', style: TextStyle(fontSize: 40))),
                const SizedBox(height: 8),
                Text(
                  l.payTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  purchase.remaining > 0 ? l.payLeft(purchase.remaining) : l.payUsed(kFreeAnalyses),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(l.payBody, textAlign: TextAlign.center, style: muted),
                const SizedBox(height: 16),
                if (regular != null)
                  Center(
                    child: Text.rich(
                      TextSpan(
                        style: muted,
                        children: [
                          TextSpan(text: '${l.payLaunchLabel}  '),
                          TextSpan(text: regular, style: const TextStyle(decoration: TextDecoration.lineThrough)),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: busy ? null : purchase.buy,
                  child: busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(price == null ? l.unlock : l.payBuy(price), style: const TextStyle(fontSize: 17)),
                ),
                if (purchase.message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(purchaseMessageText(l, purchase.message!),
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: t.colorScheme.error)),
                  ),
                const SizedBox(height: 4),
                TextButton(onPressed: busy ? null : purchase.restore, child: Text(l.payRestore)),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(purchase.remaining > 0 ? l.payLater : l.payClose),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

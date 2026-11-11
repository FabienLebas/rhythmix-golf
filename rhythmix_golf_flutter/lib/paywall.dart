import 'package:flutter/material.dart';

import 'purchase.dart';

/// Texte de prix : « 2,99 € (prix de lancement), puis 4,99 € ».
String priceLine(PurchaseService p) =>
    kLaunchOffer ? '${p.price} en prix de lancement, puis $kRegularPrice' : p.price;

/// Encadré permanent de la carte d'analyse : explique la gratuité limitée.
class FreeTrialBanner extends StatelessWidget {
  const FreeTrialBanner({super.key, required this.purchase});
  final PurchaseService purchase;

  @override
  Widget build(BuildContext context) {
    if (purchase.unlocked) return const SizedBox.shrink();
    final t = Theme.of(context);
    final left = purchase.remaining;
    final String text;
    if (left == kFreeAnalyses) {
      text = '🎁 Les $kFreeAnalyses premières analyses vidéo sont gratuites. '
          'Ensuite, un seul paiement, pour le prix d’un seau de balles : ${priceLine(purchase)}.';
    } else if (left > 0) {
      text = '🎁 Analyses gratuites : il t’en reste $left sur $kFreeAnalyses. '
          'Ensuite, un seul paiement, pour le prix d’un seau de balles : ${priceLine(purchase)}.';
    } else {
      text = '🔒 Tes $kFreeAnalyses analyses gratuites sont utilisées. '
          'Pour le prix d’un seau de balles : ${priceLine(purchase)}, une seule fois.';
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
                child: const Text('Débloquer'),
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
        final muted = TextStyle(fontSize: 14, color: t.colorScheme.onSurfaceVariant);
        if (purchase.unlocked) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 44)),
                const SizedBox(height: 8),
                const Text('Merci, c’est débloqué !',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('Analyses vidéo illimitées, pour toujours.', style: muted),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Continuer')),
              ],
            ),
          );
        }
        final busy = purchase.purchasing;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: Text('⛳🪣', style: TextStyle(fontSize: 40))),
                const SizedBox(height: 8),
                const Text(
                  'Pour le prix d’un seau de balles',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  purchase.remaining > 0
                      ? 'Il te reste ${purchase.remaining} analyse${purchase.remaining > 1 ? 's' : ''} gratuite'
                          '${purchase.remaining > 1 ? 's' : ''}.'
                      : 'Tes $kFreeAnalyses analyses gratuites sont utilisées.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Débloque les analyses vidéo illimitées avec un seul paiement : '
                  'pas d’abonnement, pas de mauvaise surprise. '
                  'Le métronome et ton historique restent gratuits.',
                  textAlign: TextAlign.center,
                  style: muted,
                ),
                const SizedBox(height: 16),
                if (kLaunchOffer)
                  Center(
                    child: Text.rich(
                      TextSpan(
                        style: muted,
                        children: [
                          const TextSpan(text: 'Prix de lancement  '),
                          TextSpan(
                            text: kRegularPrice,
                            style: const TextStyle(decoration: TextDecoration.lineThrough),
                          ),
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
                      : Text('Débloquer pour ${purchase.price}', style: const TextStyle(fontSize: 17)),
                ),
                if (purchase.message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(purchase.message!,
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: t.colorScheme.error)),
                  ),
                const SizedBox(height: 4),
                TextButton(onPressed: busy ? null : purchase.restore, child: const Text('Restaurer mes achats')),
                if (purchase.remaining > 0)
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Plus tard')),
                if (purchase.remaining == 0)
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Liaison avec l'Apple Watch (iOS uniquement, via WatchConnectivity).
// L'iPhone envoie le tempo ; la montre joue les vibrations avec sa propre
// horloge. En sens inverse, la molette de la montre renvoie un nouveau tempo
// et peut démarrer / arrêter le métronome.
//
// Sur Android, ou sans montre, tous les appels sont sans effet.

import 'dart:io' show Platform;

import 'package:flutter/services.dart';

class WatchLink {
  static const MethodChannel _ch = MethodChannel('rhythmix_watch');

  /// État reçu de la montre : mode, b, d, pause, running.
  void Function(Map<String, dynamic> state)? onState;

  /// La montre redevient joignable : renvoyer l'état courant.
  void Function()? onReachable;

  double _lastSeq = 0;

  void init() {
    if (!Platform.isIOS) return;
    _ch.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onState':
          final raw = call.arguments;
          if (raw is! Map) return;
          final m = raw.map((k, v) => MapEntry(k.toString(), v));
          if (m['origin'] != 'watch') return;
          // Le même état arrive parfois deux fois (message et contexte).
          final seq = (m['seq'] as num?)?.toDouble() ?? 0;
          if (seq <= _lastSeq) return;
          _lastSeq = seq;
          onState?.call(m);
        case 'onReachable':
          onReachable?.call();
      }
    });
  }

  Future<void> send({
    required String mode,
    required double b,
    required double d,
    required double pause,
    required bool running,
  }) async {
    if (!Platform.isIOS) return;
    final now = DateTime.now().millisecondsSinceEpoch.toDouble();
    try {
      await _ch.invokeMethod('send', {
        'origin': 'phone',
        'seq': now,
        'sentAt': now / 1000,
        'mode': mode,
        'b': b,
        'd': d,
        'pause': pause,
        'running': running,
      });
    } catch (_) {
      // pas de montre, app non installée : rien à faire
    }
  }
}

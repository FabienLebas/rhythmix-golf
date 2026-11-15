import 'app_state.dart';
import 'l10n/app_localizations.dart';

/// Nom d'un repère : 0 départ, 1 sommet, 2 impact.
String markerName(AppLocalizations l, int i) => switch (i) {
      0 => l.markerStart,
      1 => l.markerTop,
      _ => l.markerImpact,
    };

String tempoStatusLabel(AppLocalizations l, TempoStatus s) => switch (s) {
      TempoStatus.ok => l.tempoOk,
      TempoStatus.slow => l.tempoSlow,
      TempoStatus.fast => l.tempoFast,
    };

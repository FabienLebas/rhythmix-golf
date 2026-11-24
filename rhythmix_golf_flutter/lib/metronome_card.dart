import 'dart:async';

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'format.dart';
import 'l10n/app_localizations.dart';
import 'texts.dart';
import 'widgets.dart';

class MetronomeCard extends StatefulWidget {
  const MetronomeCard({super.key, required this.state});
  final AppState state;

  @override
  State<MetronomeCard> createState() => _MetronomeCardState();
}

class _MetronomeCardState extends State<MetronomeCard> {
  final _b = TextEditingController();
  final _d = TextEditingController();
  final _bf = FocusNode();
  final _df = FocusNode();
  Timer? _tick;
  int? _beat;
  String _loc = 'en';

  AppState get s => widget.state;

  @override
  void initState() {
    super.initState();
    _sync();
    s.addListener(_onState);
    // En quittant un champ, on affiche la valeur retenue (arrondie, ratio exact).
    // setState : le bouton « OK » n'apparaît que sur le champ en cours d'édition.
    _bf.addListener(_onFocus);
    _df.addListener(_onFocus);
  }

  @override
  void dispose() {
    s.removeListener(_onState);
    _tick?.cancel();
    _b.dispose();
    _d.dispose();
    _bf.dispose();
    _df.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Les champs affichent les nombres avec le séparateur de la langue.
    final loc = Localizations.localeOf(context).languageCode;
    if (loc != _loc) {
      _loc = loc;
      _sync();
    }
  }

  void _sync() {
    if (!_bf.hasFocus) _b.text = fmt2(s.cur.b, _loc);
    if (!_df.hasFocus) _d.text = fmt2(s.cur.d, _loc);
  }

  void _onFocus() {
    _sync();
    if (mounted) setState(() {});
  }

  void _onState() {
    _sync();
    if (s.running && _tick == null) {
      _tick = Timer.periodic(const Duration(milliseconds: 30), (_) {
        final b = s.metronome.beat();
        if (b != _beat && mounted) setState(() => _beat = b);
      });
    } else if (!s.running && _tick != null) {
      _tick!.cancel();
      _tick = null;
      _beat = null;
    }
    if (mounted) setState(() {});
  }

  double? _parse(String v) => double.tryParse(v.trim().replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = s.cur;
    final l = AppLocalizations.of(context);
    final title = l.metroTitle(s.mode);
    final muted = TextStyle(fontSize: 13, color: t.colorScheme.onSurfaceVariant);
    // Le pavé numérique iOS n'a pas de touche « OK » : sans ce bouton (et le
    // tap en dehors du champ), l'utilisateur ne peut plus fermer le clavier.
    InputDecoration deco(String label, FocusNode f) => InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          suffixIcon: f.hasFocus
              ? IconButton(
                  icon: const Icon(Icons.check),
                  tooltip: MaterialLocalizations.of(context).okButtonLabel,
                  onPressed: f.unfocus,
                )
              : null,
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _b,
                    focusNode: _bf,
                    style: const TextStyle(fontSize: 22),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    onTapOutside: (_) => _bf.unfocus(),
                    decoration: deco(l.fieldUp, _bf),
                    onChanged: (v) {
                      final x = _parse(v);
                      if (x != null) s.setB(x);
                    },
                    onEditingComplete: () {
                      _bf.unfocus();
                      _sync();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _d,
                    focusNode: _df,
                    style: const TextStyle(fontSize: 22),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    onTapOutside: (_) => _df.unfocus(),
                    decoration: deco(l.fieldDown, _df),
                    onChanged: (v) {
                      final x = _parse(v);
                      if (x != null) s.setD(x);
                    },
                    onEditingComplete: () {
                      _df.unfocus();
                      _sync();
                    },
                  ),
                ),
              ],
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: s.lock,
              onChanged: (v) => s.setLock(v ?? true),
              title: Text(l.keepRatio, style: muted),
            ),
            Text(l.swingSpeed(s.speed.round()), style: muted),
            Slider(
              min: 60,
              max: 140,
              divisions: 80,
              value: s.speed.clamp(60, 140).toDouble(),
              onChanged: (v) => s.setSpeed(v),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: s.reset,
                icon: const Icon(Icons.restart_alt),
                label: Text(l.resetDefaults),
              ),
            ),
            InfoBox(l.metroSummary(fmt2(p.b, _loc), fmt2(p.d, _loc), fmt2(p.b / p.d, _loc), fmt2(p.b + p.d, _loc))),
            Text(l.pauseBetween(fmt1(s.pause, _loc)), style: muted),
            Slider(
              min: 1,
              max: 8,
              divisions: 14,
              value: s.pause.clamp(1, 8).toDouble(),
              onChanged: (v) => s.setPause(v),
            ),
            SizedBox(
              height: 64,
              child: Center(
                child: Text(
                  _beat == null ? '' : markerName(l, _beat!),
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: t.colorScheme.primary),
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: s.toggleMetronome,
              child: Text(s.running ? l.metroStop : l.metroStart),
            ),
            const SizedBox(height: 8),
            Text(l.metroHelp, style: muted),
          ],
        ),
      ),
    );
  }
}

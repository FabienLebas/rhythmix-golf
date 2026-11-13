import 'dart:async';

import 'package:flutter/material.dart';

import 'app_state.dart';
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
  String? _label;

  AppState get s => widget.state;

  @override
  void initState() {
    super.initState();
    _sync();
    s.addListener(_onState);
    // En quittant un champ, on affiche la valeur retenue (arrondie, ratio exact).
    _bf.addListener(_sync);
    _df.addListener(_sync);
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

  void _sync() {
    if (!_bf.hasFocus) _b.text = fmt2(s.cur.b);
    if (!_df.hasFocus) _d.text = fmt2(s.cur.d);
  }

  void _onState() {
    _sync();
    if (s.running && _tick == null) {
      _tick = Timer.periodic(const Duration(milliseconds: 30), (_) {
        final l = s.metronome.label();
        if (l != _label && mounted) setState(() => _label = l);
      });
    } else if (!s.running && _tick != null) {
      _tick!.cancel();
      _tick = null;
      _label = null;
    }
    if (mounted) setState(() {});
  }

  double? _parse(String v) => double.tryParse(v.trim().replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = s.cur;
    final title = s.mode == 'grand' ? 'Métronome · grand jeu 3:1' : 'Métronome · putting 2:1';
    final muted = TextStyle(fontSize: 13, color: t.colorScheme.onSurfaceVariant);
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                    decoration: deco('Montée (secondes)'),
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
                    decoration: deco('Descente (secondes)'),
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
              title: Text('Garder le ratio quand je modifie un chiffre', style: muted),
            ),
            Text('Vitesse du swing : ${s.speed.round()} %', style: muted),
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
                label: const Text('Valeurs par défaut'),
              ),
            ),
            InfoBox('Montée ${fmt2(p.b)} s · Descente ${fmt2(p.d)} s · '
                'Ratio ${fmt2(p.b / p.d)}:1 · Swing ${fmt2(p.b + p.d)} s'),
            Text('Pause entre deux swings : ${s.pause.toStringAsFixed(1).replaceAll('.', ',')} s', style: muted),
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
                  _label ?? '',
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
              child: Text(s.running ? '■ Arrêter' : '▶ Démarrer'),
            ),
            const SizedBox(height: 8),
            Text(
              'Trois sons par swing : départ (grave), sommet du backswing (moyen), impact (aigu). '
              'Le son continue écran verrouillé et en mode silencieux.',
              style: muted,
            ),
          ],
        ),
      ),
    );
  }
}

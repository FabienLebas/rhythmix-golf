import 'package:flutter/material.dart';

import 'app_state.dart';

const _kOk = Color(0xFF2F9E5A);
const _kSlow = Color(0xFFD6453D);
const _kFast = Color(0xFFE08A1E);

Color _statusColor(TempoStatus s) => switch (s) {
      TempoStatus.ok => _kOk,
      TempoStatus.slow => _kSlow,
      TempoStatus.fast => _kFast,
    };

String _date(DateTime d) {
  const m = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  return '${d.day} ${m[d.month - 1]}';
}

String _ratio(double r) => r.toStringAsFixed(1).replaceAll('.', ',');

/// Historique du tempo du mode courant : graphique + dernières analyses.
class HistoryCard extends StatelessWidget {
  const HistoryCard({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: state, builder: _build);
  }

  Widget _build(BuildContext context, Widget? _) {
    final t = Theme.of(context);
    final muted = TextStyle(fontSize: 13, color: t.colorScheme.onSurfaceVariant);
    final list = state.history[state.mode]!;
    final target = state.ratioTarget;
    final grand = state.mode == 'grand';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(grand ? 'Historique · grand jeu' : 'Historique · putting',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            if (list.isEmpty)
              Text(
                'Aucune analyse pour l’instant. Chaque vidéo analysée ajoute un point '
                '(ratio montée : descente) à ce graphique.',
                style: muted,
              )
            else ...[
              AspectRatio(
                aspectRatio: 320 / 190,
                child: CustomPaint(
                  painter: _ChartPainter(
                    entries: list,
                    target: target,
                    text: t.colorScheme.onSurfaceVariant,
                    grid: t.colorScheme.outlineVariant,
                    line: t.colorScheme.primary,
                    bg: t.colorScheme.surface,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final e in list.reversed.take(8))
                _row(e, target),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('Effacer cet historique'),
                onPressed: () => _confirmClear(context, grand),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(HistoryEntry e, int target) {
    final st = tempoStatus(e.ratio, target);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x22888888)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${_date(e.time)} · ${_ratio(e.ratio)}:1'),
          Text(tempoStatusLabel(st), style: TextStyle(fontWeight: FontWeight.w600, color: _statusColor(st))),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, bool grand) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Effacer l’historique ${grand ? 'du grand jeu' : 'du putting'} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Effacer')),
        ],
      ),
    );
    if (ok == true) state.clearHistory();
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.entries,
    required this.target,
    required this.text,
    required this.grid,
    required this.line,
    required this.bg,
  });

  final List<HistoryEntry> entries;
  final int target;
  final Color text, grid, line, bg;

  void _label(Canvas c, String s, Offset o, {TextAlign align = TextAlign.left, Color? color}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: 10, color: color ?? text)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = align == TextAlign.right ? -tp.width : (align == TextAlign.center ? -tp.width / 2 : 0);
    tp.paint(c, o + Offset(dx.toDouble(), -tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const pl = 30.0, pr = 8.0, pt = 10.0, pb = 24.0;
    final w = size.width, h = size.height;
    final rs = entries.map((e) => e.ratio).toList();
    var lo = rs.fold<double>(target - 0.8, (a, b) => b < a ? b : a);
    var hi = rs.fold<double>(target + 0.8, (a, b) => b > a ? b : a);
    lo = ((lo * 2 - 0.2).floor()) / 2;
    hi = ((hi * 2 + 0.2).ceil()) / 2;
    double y(double v) => pt + (hi - v) / (hi - lo) * (h - pt - pb);
    double x(int i) => entries.length < 2 ? pl + (w - pl - pr) / 2 : pl + i * (w - pl - pr) / (entries.length - 1);

    final y1 = y(target + kRatioTolerance), y2 = y(target - kRatioTolerance);
    canvas.drawRect(Rect.fromLTRB(pl, pt, w - pr, y1), Paint()..color = _kSlow.withValues(alpha: 0.10));
    canvas.drawRect(Rect.fromLTRB(pl, y1, w - pr, y2), Paint()..color = _kOk.withValues(alpha: 0.22));
    canvas.drawRect(Rect.fromLTRB(pl, y2, w - pr, h - pb), Paint()..color = _kFast.withValues(alpha: 0.10));
    _label(canvas, 'Trop lent', Offset(pl + 4, pt + 8));
    _label(canvas, 'Trop rapide', Offset(pl + 4, h - pb - 8));

    final gp = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var v = lo.ceil(); v <= hi; v++) {
      canvas.drawLine(Offset(pl, y(v.toDouble())), Offset(w - pr, y(v.toDouble())), gp);
      _label(canvas, '$v', Offset(pl - 4, y(v.toDouble())), align: TextAlign.right);
    }

    // Ligne de la cible (pointillée)
    final ty = y(target.toDouble());
    final dash = Paint()
      ..color = _kOk
      ..strokeWidth = 1.5;
    for (var dx = pl; dx < w - pr; dx += 8) {
      canvas.drawLine(Offset(dx, ty), Offset((dx + 5).clamp(pl, w - pr), ty), dash);
    }
    _label(canvas, 'cible $target:1', Offset(w - pr - 2, ty - 8), align: TextAlign.right, color: _kOk);

    // Courbe et points
    if (entries.length > 1) {
      final path = Path()..moveTo(x(0), y(rs[0]));
      for (var i = 1; i < rs.length; i++) {
        path.lineTo(x(i), y(rs[i]));
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    for (var i = 0; i < rs.length; i++) {
      final c = Offset(x(i), y(rs[i]));
      canvas.drawCircle(c, 6, Paint()..color = bg);
      canvas.drawCircle(c, 4.5, Paint()..color = _statusColor(tempoStatus(rs[i], target)));
    }

    _label(canvas, _date(entries.first.time), Offset(pl, h - 8));
    if (entries.length > 1) {
      _label(canvas, _date(entries.last.time), Offset(w - pr, h - 8), align: TextAlign.right);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter o) => true;
}

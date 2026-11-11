import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const markerColors = [Color(0xFF2F9E5A), Color(0xFFE08A1E), Color(0xFFD6453D)];
const markerNames = ['Départ', 'Sommet', 'Impact'];

Future<ui.Image> rgbaToImage(Uint8List rgba, int w, int h) {
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, c.complete);
  return c.future;
}

/// Bande d'images façon logiciel de montage : l'image sous le trait blanc
/// central est l'image courante.
class StripPainter extends CustomPainter {
  StripPainter({
    required this.frames,
    required this.count,
    required this.pos,
    required this.markers,
    required this.tw,
    required this.th,
    required this.cw,
  });

  final List<ui.Image> frames;
  final int count;
  final double pos;
  final List<int?> markers;
  final int tw, th;
  final double cw;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, c = w / 2;
    if (count == 0 || frames.isEmpty) return;
    final f0 = (pos - c / cw).floor() - 1, f1 = (pos + c / cw).ceil() + 1;
    final img = Paint()..filterQuality = FilterQuality.low;
    final sep = Paint()..color = const Color(0x59000000);
    final thd = th.toDouble();
    for (var i = f0; i <= f1; i++) {
      if (i < 0 || i >= count || i >= frames.length) continue;
      final x = c + (i - pos) * cw - cw / 2;
      canvas.drawImageRect(
        frames[i],
        Rect.fromLTWH((tw - cw) / 2, 0, cw, thd),
        Rect.fromLTWH(x, 10, cw, thd),
        img,
      );
      canvas.drawRect(Rect.fromLTWH(x, 10, 1, thd), sep);
      for (var k = 0; k < 3; k++) {
        if (markers[k] == i) {
          canvas.drawRect(Rect.fromLTWH(x, 0, cw, 7), Paint()..color = markerColors[k]);
          canvas.drawRect(
            Rect.fromLTWH(x + 1.5, 11.5, cw - 3, thd - 3),
            Paint()
              ..color = markerColors[k]
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3,
          );
        }
      }
    }
    canvas.drawRect(Rect.fromLTWH(c - 2, 0, 4, h), Paint()..color = const Color(0xB3000000));
    canvas.drawRect(Rect.fromLTWH(c - 1, 0, 2, h), Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant StripPainter old) => true;
}

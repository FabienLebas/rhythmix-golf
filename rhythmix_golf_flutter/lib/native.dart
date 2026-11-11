// Accès au décodage vidéo natif (AVFoundation sur iOS, MediaCodec /
// MediaMetadataRetriever sur Android) via le plugin local rhythmix_native.
// Le décodage natif lit le HEVC/H.265 : aucune conversion n'est nécessaire.

import 'package:flutter/services.dart';

class VideoInfo {
  const VideoInfo({
    required this.width,
    required this.height,
    required this.fps,
    required this.durationMs,
    required this.frameCount,
  });

  /// Dimensions telles qu'affichées (rotation appliquée).
  final int width, height;
  final double fps, durationMs;
  final int frameCount;
}

class FrameBatch {
  const FrameBatch(this.gray, this.rgba);

  /// count images en niveaux de gris de aw x ah.
  final Uint8List gray;

  /// count miniatures RGBA de tw x th.
  final Uint8List rgba;
}

class NativeVideo {
  static const MethodChannel _ch = MethodChannel('rhythmix_native');

  static Future<VideoInfo> info(String path) async {
    final m = await _ch.invokeMapMethod<String, dynamic>('info', {'path': path});
    if (m == null) throw Exception('informations vidéo indisponibles');
    num v(String k) => (m[k] as num?) ?? 0;
    return VideoInfo(
      width: v('width').toInt(),
      height: v('height').toInt(),
      fps: v('fps').toDouble(),
      durationMs: v('durationMs').toDouble(),
      frameCount: v('frameCount').toInt(),
    );
  }

  static Future<FrameBatch> frames({
    required String path,
    required int start,
    required int count,
    required int aw,
    required int ah,
    required int tw,
    required int th,
    required double fps,
    required int frameCount,
  }) async {
    final m = await _ch.invokeMapMethod<String, dynamic>('frames', {
      'path': path,
      'start': start,
      'count': count,
      'aw': aw,
      'ah': ah,
      'tw': tw,
      'th': th,
      'fps': fps.toDouble(),
      'frameCount': frameCount,
    });
    if (m == null) throw Exception('images indisponibles');
    return FrameBatch(m['gray'] as Uint8List, m['rgba'] as Uint8List);
  }

  /// Image JPEG de l'image [index], hauteur maximale [maxH].
  static Future<Uint8List?> preview({
    required String path,
    required int index,
    required double fps,
    required int frameCount,
    int maxH = 720,
  }) {
    return _ch.invokeMethod<Uint8List>('preview', {
      'path': path,
      'index': index,
      'fps': fps.toDouble(),
      'frameCount': frameCount,
      'maxH': maxH,
    });
  }

  /// Enveloppe sonore : amplitude maximale par fenêtre de 10 ms.
  static Future<List<double>?> audioEnvelope(String path) async {
    final m = await _ch.invokeMapMethod<String, dynamic>('audioEnvelope', {'path': path});
    final e = m?['env'];
    if (e is List) return e.map((x) => (x as num).toDouble()).toList();
    return null;
  }
}

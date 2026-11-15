// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Rhythmix Golf';

  @override
  String get modeGrand => '🏌️ Swing completo';

  @override
  String get modeGrandSub => 'tempo 3 : 1';

  @override
  String get modePutt => '⛳ Putting';

  @override
  String get modePuttSub => 'tempo 2 : 1';

  @override
  String get markerStart => 'Inicio';

  @override
  String get markerTop => 'Cima';

  @override
  String get markerImpact => 'Impacto';

  @override
  String metroTitle(String mode) {
    String _temp0 = intl.Intl.selectLogic(
      mode,
      {
        'grand': 'Metrónomo · swing completo 3:1',
        'other': 'Metrónomo · putting 2:1',
      },
    );
    return '$_temp0';
  }

  @override
  String get fieldUp => 'Subida (segundos)';

  @override
  String get fieldDown => 'Bajada (segundos)';

  @override
  String get keepRatio => 'Mantener la proporción al cambiar un número';

  @override
  String swingSpeed(int percent) {
    return 'Velocidad del swing: $percent %';
  }

  @override
  String get resetDefaults => 'Valores predeterminados';

  @override
  String metroSummary(String up, String down, String ratio, String total) {
    return 'Subida $up s · Bajada $down s · Proporción $ratio:1 · Swing $total s';
  }

  @override
  String pauseBetween(String seconds) {
    return 'Pausa entre dos swings: $seconds s';
  }

  @override
  String get metroStart => '▶ Iniciar';

  @override
  String get metroStop => '■ Detener';

  @override
  String get metroHelp =>
      'Tres sonidos por swing: inicio (grave), cima del backswing (medio), impacto (agudo). El sonido sigue con la pantalla bloqueada y en modo silencio.';

  @override
  String analyzeTitle(String mode) {
    String _temp0 = intl.Intl.selectLogic(
      mode,
      {
        'grand': 'Analizar un swing completo',
        'other': 'Analizar un putt',
      },
    );
    return '$_temp0';
  }

  @override
  String get filmTip =>
      '📱 Grábate de frente (mirando a la cámara), con el móvil quieto y el golfista entero en la imagen, y con sonido: el ruido de la bola sirve para detectar el impacto. Para mayor precisión, graba a 60 fotogramas/s con la cámara del móvil y luego elige el video.';

  @override
  String get btnFilm => 'Grabar';

  @override
  String get btnPick => 'Elegir un video';

  @override
  String get videoIntro =>
      'Graba o elige un video: la app lee la velocidad de fotogramas, analiza cada fotograma y coloca los tres marcadores sola.';

  @override
  String get videoCheck =>
      'Revisa cada marcador: desliza la tira de fotogramas para encontrar el fotograma correcto.';

  @override
  String get stripHelp =>
      'Desliza la tira de fotogramas como en un editor de video. Toca Inicio, Cima o Impacto para seleccionarlo: al deslizar, el marcador sigue el fotograma que aparece bajo la línea blanca. Vuelve a tocar el mismo botón para deseleccionarlo.';

  @override
  String frameLabel(int index, int last, String time) {
    return 'Fotograma $index / $last · $time s';
  }

  @override
  String videoInfo(int width, int height, String fps, String seconds) {
    return 'Video: $width × $height · $fps fotogramas/s · $seconds s';
  }

  @override
  String get statusLoading => 'Cargando…';

  @override
  String statusAnalyzing(int percent, int done, int total, int seconds) {
    return 'Analizando… $percent % (fotograma $done / $total, $seconds s)';
  }

  @override
  String hintFps(String fps) {
    return 'Velocidad leída del archivo: $fps fotogramas/s.';
  }

  @override
  String get hintPutt =>
      'Detección terminada (putt: marcadores detectados por el movimiento, sin el sonido).';

  @override
  String hintGrandBall(String time) {
    return 'Detección terminada (impacto detectado por el ruido de la bola, a los $time s).';
  }

  @override
  String hintGrandBallHip(String time) {
    return 'Detección terminada (impacto detectado por el ruido de la bola, a los $time s), cima detectada cuando las caderas empiezan a moverse.';
  }

  @override
  String get hintGrandMotion =>
      'Detección terminada (sonido no utilizable: impacto estimado por el movimiento, menos preciso).';

  @override
  String get hintGrandMotionHip =>
      'Detección terminada (sonido no utilizable: impacto estimado por el movimiento, menos preciso), cima detectada cuando las caderas empiezan a moverse.';

  @override
  String errOpenCamera(String detail) {
    return 'No se pudo abrir la cámara ($detail).';
  }

  @override
  String errOpenGallery(String detail) {
    return 'No se pudo abrir la galería ($detail).';
  }

  @override
  String errAnalyze(String detail) {
    return 'No se pudo analizar este video ($detail).';
  }

  @override
  String get failUnreadable => 'video ilegible';

  @override
  String get failTooShort => 'video demasiado corto';

  @override
  String get failNoMotion => 'no se detectó movimiento';

  @override
  String get resultOrder => 'El orden debe ser: inicio, cima, impacto.';

  @override
  String resultRhythm(String up, String down, String ratio, String total) {
    return 'Tu ritmo: subida $up s, bajada $down s, proporción $ratio:1 (swing $total s).';
  }

  @override
  String resultMetroSet(String mode, int ratio, String up, String down) {
    String _temp0 = intl.Intl.selectLogic(
      mode,
      {
        'grand':
            'El metrónomo está ajustado a tu tempo objetivo de swing completo $ratio:1: subida $up s, bajada $down s.',
        'other':
            'El metrónomo está ajustado a tu tempo objetivo de putting $ratio:1: subida $up s, bajada $down s.',
      },
    );
    return '$_temp0';
  }

  @override
  String adviceClose(int ratio) {
    return 'Tu ritmo ya está cerca del $ratio:1, sigue así.';
  }

  @override
  String adviceGrandSlow(String delta, String from, String to) {
    return 'Tu subida es demasiado lenta: acelérala unos $delta s (de $from s a $to s) y mantén la misma bajada.';
  }

  @override
  String adviceGrandFast(String delta, String from, String to) {
    return 'Tu subida es demasiado rápida: frénala unos $delta s (de $from s a $to s) y mantén la misma bajada.';
  }

  @override
  String advicePuttSlow(String from, String to) {
    return 'Tu subida es demasiado larga en comparación con tu bajada. Sube el putter con algo más de decisión (unos $to s en lugar de $from s), o deja que baje con más calma, sin empujarlo hacia la bola.';
  }

  @override
  String advicePuttFast(String from, String to) {
    return 'Subes el putter demasiado rápido en comparación con tu bajada. Tómate tu tiempo al subir (unos $to s en lugar de $from s), o acelera con algo más de decisión a través de la bola.';
  }

  @override
  String historyTitle(String mode) {
    String _temp0 = intl.Intl.selectLogic(
      mode,
      {
        'grand': 'Historial · swing completo',
        'other': 'Historial · putting',
      },
    );
    return '$_temp0';
  }

  @override
  String get historyEmpty =>
      'Todavía no hay ningún análisis. Cada video analizado añade un punto (proporción subida : bajada) a este gráfico.';

  @override
  String get historyClear => 'Borrar este historial';

  @override
  String historyClearTitle(String mode) {
    String _temp0 = intl.Intl.selectLogic(
      mode,
      {
        'grand': '¿Borrar el historial del swing completo?',
        'other': '¿Borrar el historial del putting?',
      },
    );
    return '$_temp0';
  }

  @override
  String get cancel => 'Cancelar';

  @override
  String get erase => 'Borrar';

  @override
  String get tempoOk => 'En el objetivo';

  @override
  String get tempoSlow => 'Demasiado lento';

  @override
  String get tempoFast => 'Demasiado rápido';

  @override
  String chartTarget(int target) {
    return 'objetivo $target:1';
  }

  @override
  String priceClause(String price) {
    return ': $price';
  }

  @override
  String priceLaunch(String price, String regular) {
    return '$price de precio de lanzamiento, luego $regular';
  }

  @override
  String freeIntro(int count, String priceClause) {
    return '🎁 Los primeros $count análisis de video son gratis. Después, un solo pago, por el precio de un cubo de bolas$priceClause.';
  }

  @override
  String freeLeft(int left, int count, String priceClause) {
    return '🎁 Análisis gratis: te quedan $left de $count. Después, un solo pago, por el precio de un cubo de bolas$priceClause.';
  }

  @override
  String freeUsed(int count, String priceClause) {
    return '🔒 Ya has usado tus $count análisis gratis. Por el precio de un cubo de bolas$priceClause, una sola vez.';
  }

  @override
  String get unlock => 'Desbloquear';

  @override
  String get payTitle => 'Por el precio de un cubo de bolas';

  @override
  String payLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Te quedan $count análisis gratis.',
      one: 'Te queda 1 análisis gratis.',
    );
    return '$_temp0';
  }

  @override
  String payUsed(int count) {
    return 'Ya has usado tus $count análisis gratis.';
  }

  @override
  String get payBody =>
      'Desbloquea los análisis de video ilimitados con un solo pago: sin suscripción, sin sorpresas. El metrónomo y tu historial siguen siendo gratis.';

  @override
  String get payLaunchLabel => 'Precio de lanzamiento';

  @override
  String payBuy(String price) {
    return 'Desbloquear por $price';
  }

  @override
  String get payRestore => 'Restaurar mis compras';

  @override
  String get payLater => 'Más tarde';

  @override
  String get payClose => 'Cerrar';

  @override
  String get payThanks => '¡Gracias, ya está desbloqueado!';

  @override
  String get payThanksSub => 'Análisis de video ilimitados, para siempre.';

  @override
  String get payContinue => 'Continuar';

  @override
  String get msgBuyUnavailable =>
      'Compra no disponible por el momento. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get msgBuyFailed => 'No se pudo completar la compra.';

  @override
  String msgBuyFailedDetail(String detail) {
    return 'No se pudo completar la compra ($detail).';
  }

  @override
  String msgRestoreFailed(String detail) {
    return 'No se pudieron restaurar las compras ($detail).';
  }

  @override
  String get msgNothingToRestore =>
      'No hay ninguna compra que restaurar en esta cuenta.';

  @override
  String get msgStoreUnavailable => 'Tienda no disponible por el momento.';
}

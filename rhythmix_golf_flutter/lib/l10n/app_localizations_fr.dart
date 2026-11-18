// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Rhythmix Golf';

  @override
  String get modeGrand => '🏌️ Grand jeu';

  @override
  String get modeGrandSub => 'tempo 3 : 1';

  @override
  String get modePutt => '⛳ Putting';

  @override
  String get modePuttSub => 'tempo 2 : 1';

  @override
  String get markerStart => 'Départ';

  @override
  String get markerTop => 'Sommet';

  @override
  String get markerImpact => 'Impact';

  @override
  String metroTitle(String mode) {
    String _temp0 = intl.Intl.selectLogic(
      mode,
      {
        'grand': 'Métronome · grand jeu 3:1',
        'other': 'Métronome · putting 2:1',
      },
    );
    return '$_temp0';
  }

  @override
  String get fieldUp => 'Montée (secondes)';

  @override
  String get fieldDown => 'Descente (secondes)';

  @override
  String get keepRatio => 'Garder le ratio quand je modifie un chiffre';

  @override
  String swingSpeed(int percent) {
    return 'Vitesse du swing : $percent %';
  }

  @override
  String get resetDefaults => 'Valeurs par défaut';

  @override
  String metroSummary(String up, String down, String ratio, String total) {
    return 'Montée $up s · Descente $down s · Ratio $ratio:1 · Swing $total s';
  }

  @override
  String pauseBetween(String seconds) {
    return 'Pause entre deux swings : $seconds s';
  }

  @override
  String get metroStart => '▶ Démarrer';

  @override
  String get metroStop => '■ Arrêter';

  @override
  String get metroHelp =>
      'Trois sons par swing : départ (grave), sommet du backswing (moyen), impact (aigu). Le son continue écran verrouillé et en mode silencieux.';

  @override
  String analyzeTitle(String mode) {
    String _temp0 = intl.Intl.selectLogic(
      mode,
      {
        'grand': 'Analyser un grand jeu',
        'other': 'Analyser un putt',
      },
    );
    return '$_temp0';
  }

  @override
  String get filmTip =>
      '📱 Filme-toi de face (face à la caméra), téléphone immobile, golfeur entier dans l’image, avec le son : le bruit de la balle sert à repérer l’impact. Pour plus de précision, filme à 60 images/s avec l’appareil photo puis choisis la vidéo.';

  @override
  String get btnFilm => 'Filmer';

  @override
  String get btnPick => 'Choisir une vidéo';

  @override
  String get videoIntro =>
      'Filme ou choisis une vidéo : l’app lit la cadence, analyse chaque image et place les trois repères toute seule.';

  @override
  String get videoCheck =>
      'Vérifie chaque repère : fais glisser la bande d’images pour trouver la bonne image.';

  @override
  String get stripHelp =>
      'Fais glisser la bande d’images comme dans un logiciel de montage. Touche Départ, Sommet ou Impact pour le sélectionner : en faisant glisser, le repère suit l’image affichée sous le trait blanc. Retouche le même bouton pour le désélectionner.';

  @override
  String frameLabel(int index, int last, String time) {
    return 'Image $index / $last · $time s';
  }

  @override
  String videoInfo(int width, int height, String fps, String seconds) {
    return 'Vidéo : $width × $height · $fps images/s · $seconds s';
  }

  @override
  String get statusLoading => 'Chargement…';

  @override
  String statusAnalyzing(int percent, int done, int total, int seconds) {
    return 'Analyse… $percent % (image $done / $total, $seconds s)';
  }

  @override
  String hintFps(String fps) {
    return 'Cadence lue dans le fichier : $fps images/s.';
  }

  @override
  String get hintPutt =>
      'Détection terminée (putt : repérage par le mouvement, sans le son).';

  @override
  String hintGrandBall(String time) {
    return 'Détection terminée (impact repéré grâce au bruit de la balle, à $time s).';
  }

  @override
  String hintGrandBallHip(String time) {
    return 'Détection terminée (impact repéré grâce au bruit de la balle, à $time s), sommet repéré au départ des hanches.';
  }

  @override
  String get hintGrandMotion =>
      'Détection terminée (son non exploitable : impact estimé d’après le mouvement, moins précis).';

  @override
  String get hintGrandMotionHip =>
      'Détection terminée (son non exploitable : impact estimé d’après le mouvement, moins précis), sommet repéré au départ des hanches.';

  @override
  String errOpenCamera(String detail) {
    return 'Impossible d’ouvrir la caméra ($detail).';
  }

  @override
  String errOpenGallery(String detail) {
    return 'Impossible d’ouvrir la galerie ($detail).';
  }

  @override
  String errAnalyze(String detail) {
    return 'Impossible d’analyser cette vidéo ($detail).';
  }

  @override
  String get failUnreadable => 'vidéo illisible';

  @override
  String get failTooShort => 'vidéo trop courte';

  @override
  String get failNoMotion => 'aucun mouvement détecté';

  @override
  String get resultOrder => 'L’ordre doit être : départ, sommet, impact.';

  @override
  String resultRhythm(String up, String down, String ratio, String total) {
    return 'Ton rythme : montée $up s, descente $down s, ratio $ratio:1 (swing $total s).';
  }

  @override
  String resultMetroSet(String mode, int ratio, String up, String down) {
    String _temp0 = intl.Intl.selectLogic(
      mode,
      {
        'grand':
            'Le métronome est réglé sur ton tempo cible grand jeu $ratio:1 : montée $up s, descente $down s.',
        'other':
            'Le métronome est réglé sur ton tempo cible putting $ratio:1 : montée $up s, descente $down s.',
      },
    );
    return '$_temp0';
  }

  @override
  String adviceClose(int ratio) {
    return 'Ton rythme est déjà proche du $ratio:1, continue comme ça.';
  }

  @override
  String adviceGrandSlow(String delta, String from, String to) {
    return 'Ta montée est trop lente : accélère-la d’environ $delta s (de $from s à $to s) et garde la même descente.';
  }

  @override
  String adviceGrandFast(String delta, String from, String to) {
    return 'Ta montée est trop rapide : ralentis-la d’environ $delta s (de $from s à $to s) et garde la même descente.';
  }

  @override
  String advicePuttSlow(String from, String to) {
    return 'Ta montée est trop longue par rapport à ta descente. Monte un peu plus franchement (environ $to s au lieu de $from s), ou laisse le putter redescendre plus tranquillement, sans le pousser vers la balle.';
  }

  @override
  String advicePuttFast(String from, String to) {
    return 'Tu montes trop vite par rapport à ta descente. Prends ton temps en montant (environ $to s au lieu de $from s), ou accélère un peu plus franchement à travers la balle.';
  }

  @override
  String historyTitle(String mode) {
    String _temp0 = intl.Intl.selectLogic(
      mode,
      {
        'grand': 'Historique · grand jeu',
        'other': 'Historique · putting',
      },
    );
    return '$_temp0';
  }

  @override
  String get historyEmpty =>
      'Aucune analyse pour l’instant. Chaque vidéo analysée ajoute un point (ratio montée : descente) à ce graphique.';

  @override
  String get historyClear => 'Effacer cet historique';

  @override
  String historyClearTitle(String mode) {
    String _temp0 = intl.Intl.selectLogic(
      mode,
      {
        'grand': 'Effacer l’historique du grand jeu ?',
        'other': 'Effacer l’historique du putting ?',
      },
    );
    return '$_temp0';
  }

  @override
  String get cancel => 'Annuler';

  @override
  String get erase => 'Effacer';

  @override
  String get tempoOk => 'Dans la cible';

  @override
  String get tempoSlow => 'Trop lent';

  @override
  String get tempoFast => 'Trop rapide';

  @override
  String chartTarget(int target) {
    return 'cible $target:1';
  }

  @override
  String priceClause(String price) {
    return ' : $price';
  }

  @override
  String priceLaunch(String price, String regular) {
    return '$price en prix de lancement, puis $regular';
  }

  @override
  String freeIntro(int count, String priceClause) {
    return '🎁 Les $count premières analyses vidéo sont gratuites. Ensuite, un seul paiement, pour le prix d’un seau de balles$priceClause, et tu auras l’app pour analyser autant de swings que tu veux et ainsi vérifier tes progrès dans le temps.';
  }

  @override
  String freeLeft(int left, int count, String priceClause) {
    return '🎁 Analyses gratuites : il t’en reste $left sur $count. Ensuite, un seul paiement, pour le prix d’un seau de balles$priceClause, et tu auras l’app pour analyser autant de swings que tu veux et ainsi vérifier tes progrès dans le temps.';
  }

  @override
  String freeUsed(int count, String priceClause) {
    return '🔒 Tes $count analyses gratuites sont utilisées. Pour continuer à analyser tes swings, offre-toi l’analyse illimitée à vie pour le prix d’un seau de balles !$priceClause';
  }

  @override
  String priceEndLaunch(String price, String regular) {
    return ' $price prix de lancement au lieu de $regular.';
  }

  @override
  String priceEnd(String price) {
    return ' $price.';
  }

  @override
  String get unlock => 'Débloquer';

  @override
  String get payTitle => 'Pour le prix d’un seau de balles';

  @override
  String payLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il te reste $count analyses gratuites.',
      one: 'Il te reste 1 analyse gratuite.',
    );
    return '$_temp0';
  }

  @override
  String payUsed(int count) {
    return 'Tes $count analyses gratuites sont utilisées.';
  }

  @override
  String get payBody =>
      'Débloque les analyses vidéo illimitées avec un seul paiement : pas d’abonnement, pas de mauvaise surprise.';

  @override
  String get payLaunchLabel => 'Prix de lancement';

  @override
  String payBuy(String price) {
    return 'Débloquer pour $price';
  }

  @override
  String get payRestore => 'Restaurer mes achats';

  @override
  String get payLater => 'Plus tard';

  @override
  String get payClose => 'Fermer';

  @override
  String get payThanks => 'Merci, c’est débloqué !';

  @override
  String get payThanksSub => 'Analyses vidéo illimitées, pour toujours.';

  @override
  String get payContinue => 'Continuer';

  @override
  String get msgBuyUnavailable =>
      'Achat indisponible pour le moment. Vérifie ta connexion et réessaie.';

  @override
  String get msgBuyFailed => 'Achat impossible.';

  @override
  String msgBuyFailedDetail(String detail) {
    return 'Achat impossible ($detail).';
  }

  @override
  String msgRestoreFailed(String detail) {
    return 'Restauration impossible ($detail).';
  }

  @override
  String get msgNothingToRestore => 'Aucun achat à restaurer sur ce compte.';

  @override
  String get msgStoreUnavailable => 'Store indisponible pour le moment.';
}

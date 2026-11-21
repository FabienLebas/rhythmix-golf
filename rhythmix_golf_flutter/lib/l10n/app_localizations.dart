import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rhythmix Golf'**
  String get appTitle;

  /// No description provided for @modeGrand.
  ///
  /// In fr, this message translates to:
  /// **'🏌️ Grand jeu'**
  String get modeGrand;

  /// No description provided for @modeGrandSub.
  ///
  /// In fr, this message translates to:
  /// **'tempo 3 : 1'**
  String get modeGrandSub;

  /// No description provided for @modePutt.
  ///
  /// In fr, this message translates to:
  /// **'⛳ Putting'**
  String get modePutt;

  /// No description provided for @modePuttSub.
  ///
  /// In fr, this message translates to:
  /// **'tempo 2 : 1'**
  String get modePuttSub;

  /// No description provided for @markerStart.
  ///
  /// In fr, this message translates to:
  /// **'Départ'**
  String get markerStart;

  /// No description provided for @markerTop.
  ///
  /// In fr, this message translates to:
  /// **'Sommet'**
  String get markerTop;

  /// No description provided for @markerImpact.
  ///
  /// In fr, this message translates to:
  /// **'Impact'**
  String get markerImpact;

  /// No description provided for @metroTitle.
  ///
  /// In fr, this message translates to:
  /// **'{mode, select, grand{Métronome · grand jeu 3:1} other{Métronome · putting 2:1}}'**
  String metroTitle(String mode);

  /// No description provided for @fieldUp.
  ///
  /// In fr, this message translates to:
  /// **'Montée (secondes)'**
  String get fieldUp;

  /// No description provided for @fieldDown.
  ///
  /// In fr, this message translates to:
  /// **'Descente (secondes)'**
  String get fieldDown;

  /// No description provided for @keepRatio.
  ///
  /// In fr, this message translates to:
  /// **'Garder le ratio quand je modifie un chiffre'**
  String get keepRatio;

  /// No description provided for @swingSpeed.
  ///
  /// In fr, this message translates to:
  /// **'Vitesse du swing : {percent} %'**
  String swingSpeed(int percent);

  /// No description provided for @resetDefaults.
  ///
  /// In fr, this message translates to:
  /// **'Valeurs par défaut'**
  String get resetDefaults;

  /// No description provided for @metroSummary.
  ///
  /// In fr, this message translates to:
  /// **'Montée {up} s · Descente {down} s · Ratio {ratio}:1 · Swing {total} s'**
  String metroSummary(String up, String down, String ratio, String total);

  /// No description provided for @pauseBetween.
  ///
  /// In fr, this message translates to:
  /// **'Pause entre deux swings : {seconds} s'**
  String pauseBetween(String seconds);

  /// No description provided for @metroStart.
  ///
  /// In fr, this message translates to:
  /// **'▶ Démarrer'**
  String get metroStart;

  /// No description provided for @metroStop.
  ///
  /// In fr, this message translates to:
  /// **'■ Arrêter'**
  String get metroStop;

  /// No description provided for @metroHelp.
  ///
  /// In fr, this message translates to:
  /// **'Trois sons par swing : départ (grave), sommet du backswing (moyen), impact (aigu). Le son continue écran verrouillé et en mode silencieux.'**
  String get metroHelp;

  /// No description provided for @analyzeTitle.
  ///
  /// In fr, this message translates to:
  /// **'{mode, select, grand{Analyser un grand jeu} other{Analyser un putt}}'**
  String analyzeTitle(String mode);

  /// No description provided for @filmTip.
  ///
  /// In fr, this message translates to:
  /// **'📱 Filme-toi de face (face à la caméra), téléphone immobile, golfeur entier dans l’image, avec le son : le bruit de la balle sert à repérer l’impact. Pour plus de précision, filme à 60 images/s avec l’appareil photo puis choisis la vidéo.'**
  String get filmTip;

  /// No description provided for @btnFilm.
  ///
  /// In fr, this message translates to:
  /// **'Filmer'**
  String get btnFilm;

  /// No description provided for @btnPick.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une vidéo'**
  String get btnPick;

  /// No description provided for @videoIntro.
  ///
  /// In fr, this message translates to:
  /// **'Filme ou choisis une vidéo : l’app lit la cadence, analyse chaque image et place les trois repères toute seule.'**
  String get videoIntro;

  /// No description provided for @videoCheck.
  ///
  /// In fr, this message translates to:
  /// **'Vérifie chaque repère : fais glisser la bande d’images pour trouver la bonne image.'**
  String get videoCheck;

  /// No description provided for @stripHelp.
  ///
  /// In fr, this message translates to:
  /// **'Fais glisser la bande d’images comme dans un logiciel de montage. Touche Départ, Sommet ou Impact pour le sélectionner : en faisant glisser, le repère suit l’image affichée sous le trait blanc. Retouche le même bouton pour le désélectionner.'**
  String get stripHelp;

  /// No description provided for @frameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Image {index} / {last} · {time} s'**
  String frameLabel(int index, int last, String time);

  /// No description provided for @videoInfo.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo : {width} × {height} · {fps} images/s · {seconds} s'**
  String videoInfo(int width, int height, String fps, String seconds);

  /// No description provided for @statusLoading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement…'**
  String get statusLoading;

  /// No description provided for @statusAnalyzing.
  ///
  /// In fr, this message translates to:
  /// **'Analyse… {percent} % (image {done} / {total}, {seconds} s)'**
  String statusAnalyzing(int percent, int done, int total, int seconds);

  /// No description provided for @hintFps.
  ///
  /// In fr, this message translates to:
  /// **'Cadence lue dans le fichier : {fps} images/s.'**
  String hintFps(String fps);

  /// No description provided for @hintPutt.
  ///
  /// In fr, this message translates to:
  /// **'Détection terminée (putt : repérage par le mouvement, sans le son).'**
  String get hintPutt;

  /// No description provided for @hintGrandBall.
  ///
  /// In fr, this message translates to:
  /// **'Détection terminée (impact repéré grâce au bruit de la balle, à {time} s).'**
  String hintGrandBall(String time);

  /// No description provided for @hintGrandBallHip.
  ///
  /// In fr, this message translates to:
  /// **'Détection terminée (impact repéré grâce au bruit de la balle, à {time} s), sommet repéré au départ des hanches.'**
  String hintGrandBallHip(String time);

  /// No description provided for @hintGrandMotion.
  ///
  /// In fr, this message translates to:
  /// **'Détection terminée (son non exploitable : impact estimé d’après le mouvement, moins précis).'**
  String get hintGrandMotion;

  /// No description provided for @hintGrandMotionHip.
  ///
  /// In fr, this message translates to:
  /// **'Détection terminée (son non exploitable : impact estimé d’après le mouvement, moins précis), sommet repéré au départ des hanches.'**
  String get hintGrandMotionHip;

  /// No description provided for @errOpenCamera.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d’ouvrir la caméra ({detail}).'**
  String errOpenCamera(String detail);

  /// No description provided for @errOpenGallery.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d’ouvrir la galerie ({detail}).'**
  String errOpenGallery(String detail);

  /// No description provided for @errAnalyze.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d’analyser cette vidéo ({detail}).'**
  String errAnalyze(String detail);

  /// No description provided for @failUnreadable.
  ///
  /// In fr, this message translates to:
  /// **'vidéo illisible'**
  String get failUnreadable;

  /// No description provided for @failTooShort.
  ///
  /// In fr, this message translates to:
  /// **'vidéo trop courte'**
  String get failTooShort;

  /// No description provided for @failNoMotion.
  ///
  /// In fr, this message translates to:
  /// **'aucun mouvement détecté'**
  String get failNoMotion;

  /// No description provided for @resultOrder.
  ///
  /// In fr, this message translates to:
  /// **'L’ordre doit être : départ, sommet, impact.'**
  String get resultOrder;

  /// No description provided for @resultRhythm.
  ///
  /// In fr, this message translates to:
  /// **'Ton rythme : montée {up} s, descente {down} s, ratio {ratio}:1 (swing {total} s).'**
  String resultRhythm(String up, String down, String ratio, String total);

  /// No description provided for @resultMetroSet.
  ///
  /// In fr, this message translates to:
  /// **'{mode, select, grand{Le métronome est réglé sur ton tempo cible grand jeu {ratio}:1 : montée {up} s, descente {down} s.} other{Le métronome est réglé sur ton tempo cible putting {ratio}:1 : montée {up} s, descente {down} s.}}'**
  String resultMetroSet(String mode, int ratio, String up, String down);

  /// No description provided for @adviceClose.
  ///
  /// In fr, this message translates to:
  /// **'Ton rythme est déjà proche du {ratio}:1, continue comme ça.'**
  String adviceClose(int ratio);

  /// No description provided for @adviceGrandSlow.
  ///
  /// In fr, this message translates to:
  /// **'Ta montée est trop lente : accélère-la d’environ {delta} s (de {from} s à {to} s) et garde la même descente.'**
  String adviceGrandSlow(String delta, String from, String to);

  /// No description provided for @adviceGrandFast.
  ///
  /// In fr, this message translates to:
  /// **'Ta montée est trop rapide : ralentis-la d’environ {delta} s (de {from} s à {to} s) et garde la même descente.'**
  String adviceGrandFast(String delta, String from, String to);

  /// No description provided for @advicePuttSlow.
  ///
  /// In fr, this message translates to:
  /// **'Ta montée est trop longue par rapport à ta descente. Monte un peu plus franchement (environ {to} s au lieu de {from} s), ou laisse le putter redescendre plus tranquillement, sans le pousser vers la balle.'**
  String advicePuttSlow(String from, String to);

  /// No description provided for @advicePuttFast.
  ///
  /// In fr, this message translates to:
  /// **'Tu montes trop vite par rapport à ta descente. Prends ton temps en montant (environ {to} s au lieu de {from} s), ou accélère un peu plus franchement à travers la balle.'**
  String advicePuttFast(String from, String to);

  /// No description provided for @historyTitle.
  ///
  /// In fr, this message translates to:
  /// **'{mode, select, grand{Historique · grand jeu} other{Historique · putting}}'**
  String historyTitle(String mode);

  /// No description provided for @historyEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune analyse pour l’instant. Chaque vidéo analysée ajoute un point (ratio montée : descente) à ce graphique.'**
  String get historyEmpty;

  /// No description provided for @historyClear.
  ///
  /// In fr, this message translates to:
  /// **'Effacer cet historique'**
  String get historyClear;

  /// No description provided for @historyClearTitle.
  ///
  /// In fr, this message translates to:
  /// **'{mode, select, grand{Effacer l’historique du grand jeu ?} other{Effacer l’historique du putting ?}}'**
  String historyClearTitle(String mode);

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @erase.
  ///
  /// In fr, this message translates to:
  /// **'Effacer'**
  String get erase;

  /// No description provided for @tempoOk.
  ///
  /// In fr, this message translates to:
  /// **'Dans la cible'**
  String get tempoOk;

  /// No description provided for @tempoSlow.
  ///
  /// In fr, this message translates to:
  /// **'Trop lent'**
  String get tempoSlow;

  /// No description provided for @tempoFast.
  ///
  /// In fr, this message translates to:
  /// **'Trop rapide'**
  String get tempoFast;

  /// No description provided for @chartTarget.
  ///
  /// In fr, this message translates to:
  /// **'cible {target}:1'**
  String chartTarget(int target);

  /// No description provided for @priceClause.
  ///
  /// In fr, this message translates to:
  /// **' : {price}'**
  String priceClause(String price);

  /// No description provided for @priceLaunch.
  ///
  /// In fr, this message translates to:
  /// **'{price} en prix de lancement, puis {regular}'**
  String priceLaunch(String price, String regular);

  /// No description provided for @freeIntro.
  ///
  /// In fr, this message translates to:
  /// **'🎁 Les {count} premières analyses vidéo sont gratuites. Ensuite, un seul paiement, pour le prix d’un seau de balles{priceClause}, et tu auras l’app pour analyser autant de swings que tu veux et ainsi vérifier tes progrès dans le temps.'**
  String freeIntro(int count, String priceClause);

  /// No description provided for @freeLeft.
  ///
  /// In fr, this message translates to:
  /// **'🎁 Analyses gratuites : il t’en reste {left} sur {count}. Ensuite, un seul paiement, pour le prix d’un seau de balles{priceClause}, et tu auras l’app pour analyser autant de swings que tu veux et ainsi vérifier tes progrès dans le temps.'**
  String freeLeft(int left, int count, String priceClause);

  /// No description provided for @freeUsed.
  ///
  /// In fr, this message translates to:
  /// **'🔒 Tes {count} analyses gratuites sont utilisées. Pour continuer à analyser tes swings, offre-toi l’analyse illimitée à vie pour le prix d’un seau de balles !{priceClause}'**
  String freeUsed(int count, String priceClause);

  /// No description provided for @priceEndLaunch.
  ///
  /// In fr, this message translates to:
  /// **' {price} prix de lancement au lieu de {regular}.'**
  String priceEndLaunch(String price, String regular);

  /// No description provided for @priceEnd.
  ///
  /// In fr, this message translates to:
  /// **' {price}.'**
  String priceEnd(String price);

  /// No description provided for @unlock.
  ///
  /// In fr, this message translates to:
  /// **'Débloquer'**
  String get unlock;

  /// No description provided for @payTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pour le prix d’un seau de balles'**
  String get payTitle;

  /// No description provided for @payLeft.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Il te reste 1 analyse gratuite.} other{Il te reste {count} analyses gratuites.}}'**
  String payLeft(int count);

  /// No description provided for @payUsed.
  ///
  /// In fr, this message translates to:
  /// **'Tes {count} analyses gratuites sont utilisées.'**
  String payUsed(int count);

  /// No description provided for @payBody.
  ///
  /// In fr, this message translates to:
  /// **'Débloque les analyses vidéo illimitées avec un seul paiement : pas d’abonnement, pas de mauvaise surprise.'**
  String get payBody;

  /// No description provided for @payLaunchLabel.
  ///
  /// In fr, this message translates to:
  /// **'Prix de lancement'**
  String get payLaunchLabel;

  /// No description provided for @payBuy.
  ///
  /// In fr, this message translates to:
  /// **'Débloquer pour {price}'**
  String payBuy(String price);

  /// No description provided for @payRestore.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer mes achats'**
  String get payRestore;

  /// No description provided for @payLater.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get payLater;

  /// No description provided for @payClose.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get payClose;

  /// No description provided for @payThanks.
  ///
  /// In fr, this message translates to:
  /// **'Merci, c’est débloqué !'**
  String get payThanks;

  /// No description provided for @payThanksSub.
  ///
  /// In fr, this message translates to:
  /// **'Analyses vidéo illimitées, pour toujours.'**
  String get payThanksSub;

  /// No description provided for @payContinue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get payContinue;

  /// No description provided for @msgBuyUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Achat indisponible pour le moment. Vérifie ta connexion et réessaie.'**
  String get msgBuyUnavailable;

  /// No description provided for @msgBuyFailed.
  ///
  /// In fr, this message translates to:
  /// **'Achat impossible.'**
  String get msgBuyFailed;

  /// No description provided for @msgBuyFailedDetail.
  ///
  /// In fr, this message translates to:
  /// **'Achat impossible ({detail}).'**
  String msgBuyFailedDetail(String detail);

  /// No description provided for @msgRestoreFailed.
  ///
  /// In fr, this message translates to:
  /// **'Restauration impossible ({detail}).'**
  String msgRestoreFailed(String detail);

  /// No description provided for @msgNothingToRestore.
  ///
  /// In fr, this message translates to:
  /// **'Aucun achat à restaurer sur ce compte.'**
  String get msgNothingToRestore;

  /// No description provided for @msgStoreUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Store indisponible pour le moment.'**
  String get msgStoreUnavailable;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

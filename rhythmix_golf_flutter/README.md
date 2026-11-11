# Rhythmix Golf · application Flutter (iOS + Android)

Version mobile de Rhythmix Golf :

- un **métronome** de tempo de swing : 3 : 1 au grand jeu, 2 : 1 au putting ;
- une **analyse vidéo automatique** (Départ, Sommet, Impact). Elle mesure ton tempo et règle le métronome sur le **tempo cible**.

C'est le portage de la version web, avec les mêmes algorithmes de détection. Ce qui change par rapport au web :

| | Web | Flutter |
|---|---|---|
| Décodage vidéo | navigateur (HEVC parfois illisible) | **natif** : AVFoundation (iOS), MediaCodec (Android). Le HEVC/H.265 et la 4K sont lus. |
| Conversion vidéo | aucune | **aucune** : le décodage natif suffit, il n'y a rien à convertir |
| Son du métronome | Web Audio | cycle calculé en WAV et lu en boucle. Le temps entre les bips est exact. Le son continue écran verrouillé et en mode silencieux. |
| Vidéo | fichier | **Filmer** directement ou **Choisir une vidéo** dans la galerie |

---

## Fonctionnement

### Métronome
- Trois bips par swing : départ (grave, 660 Hz), sommet (moyen, 880 Hz), impact (aigu, 1320 Hz).
- Valeurs par défaut : grand jeu 0,81 s / 0,27 s ; putting 0,60 s / 0,30 s.
- Réglages : montée / descente en secondes (avec « garder le ratio »), vitesse 60–140 % (à droite = plus rapide), pause entre deux swings 1–8 s, retour aux valeurs par défaut.
- Les réglages sont mémorisés (`shared_preferences`).

### Analyse vidéo
1. **Filmer** (caméra de l'app) ou **Choisir une vidéo**. Le golfeur doit être filmé **de face**, téléphone fixe, avec le son. Pour plus de précision, filme à 60 images/s avec l'appareil photo puis choisis la vidéo.
2. Le code natif lit la cadence réelle (nombre d'images / durée de la piste) et décode **chaque image exactement**.
3. Détection, identique à la version web (`lib/detection.dart`) :
   - **Impact** : pic sonore du bruit de la balle, sinon pic de mouvement ;
   - **Sommet** : départ latéral des hanches, sinon le mouvement ;
   - **Départ** : sortie du calme avant le sommet ;
   - **Putting** : uniquement le mouvement.
4. Tu peux corriger les repères à la main : bande d'images à faire glisser, boutons ±1 / ±5, boutons Départ / Sommet / Impact.
5. Résultat : ton tempo, un conseil (« accélère ta montée de 0,27 s… ») et **le métronome réglé sur le tempo cible**. La descente est gardée, la montée est ajustée pour obtenir 3 : 1 ou 2 : 1.

---

## Structure

```
lib/
  main.dart            application, thème (vert grand jeu / bleu putting)
  app_state.dart       réglages, persistance, pilotage du métronome
  metronome.dart       génération du WAV d'un cycle + lecture en boucle (just_audio)
  metronome_card.dart  interface du métronome
  video_card.dart      interface d'analyse : aperçu, bande d'images, repères, résultat
  strip.dart           dessin de la bande d'images
  detection.dart       algorithmes de détection (Dart pur)
  native.dart          appels au code natif
  widgets.dart         petits composants
native/
  android/RhythmixNativePlugin.kt   décodage Android
  ios/RhythmixNativePlugin.swift    décodage iOS
tool/bootstrap.sh      prépare le projet (dossiers android/ios + plugin natif)
.github/workflows/build.yml  compilation automatique APK + iOS
```

Le code natif est dans un **plugin local** (`packages/rhythmix_native`), généré par `tool/bootstrap.sh`, qui y copie les fichiers de `native/`. Le plugin s'enregistre tout seul : il n'y a pas de code à modifier dans `AppDelegate` ni dans `MainActivity`.

---

## Compiler

### Option 1 : GitHub Actions (sans rien installer)
1. Crée un dépôt GitHub et pousse ce dossier sur la branche `main`.
2. L'onglet **Actions** lance « Compilation Android et iOS ».
3. À la fin, télécharge les **artefacts** :
   - `rhythmix-golf-android` → `app-release.apk`, à installer directement sur un téléphone Android (autoriser les sources inconnues) ;
   - `rhythmix-golf-ios` → `.ipa` **non signé** : il doit être signé pour s'installer sur un iPhone (voir plus bas).

### Option 2 : sur ton ordinateur
Prérequis : Flutter stable. Pour iOS, il faut en plus un Mac avec Xcode et CocoaPods.

```bash
bash tool/bootstrap.sh          # une seule fois
flutter run --release           # téléphone branché (Android, ou iPhone depuis un Mac)
flutter build apk --release     # APK Android
flutter build ipa               # iOS signé (compte Apple Developer configuré dans Xcode)
```

### Installer sur iPhone
Apple impose une signature :
- **depuis un Mac** : ouvre `ios/Runner.xcworkspace` dans Xcode, choisis ton équipe (*Signing & Capabilities*), branche l'iPhone, puis `flutter run --release` ;
- **pour des testeurs** : TestFlight, avec un compte Apple Developer à 99 $/an.

---

## À savoir

- Le dépôt ne contient pas les dossiers `android/`, `ios/` ni `packages/rhythmix_native/` : `tool/bootstrap.sh` les régénère, et le CI le fait à chaque compilation. Pour personnaliser l'icône ou la signature, lance le script une fois, retire ces dossiers du `.gitignore` et commite-les.
- `bootstrap.sh` règle aussi le nom affiché « Rhythmix Golf », les autorisations caméra / micro / photos (iOS) et le son en arrière-plan (`UIBackgroundModes: audio`).
- Android : extraction rapide par index d'image à partir d'Android 9 ; méthode plus lente au-delà sur les versions plus anciennes.
- La détection a été vérifiée en simulant ce décodage sur la vidéo de référence de grand jeu : images 78 / 138 / 153, comme la version web. Le décalage du son d'impact peut varier un peu selon l'appareil. Si l'impact tombe 1–2 images à côté sur iPhone, ajuster `off` dans `kParams` (`lib/detection.dart`).
- Ce code n'a pas pu être compilé dans l'environnement où il a été écrit. La première compilation peut demander quelques corrections mineures.

## Prochaines étapes possibles
- Icône et écran de démarrage (`flutter_launcher_icons`, `flutter_native_splash`).
- Achat intégré unique (3–5 €) après quelques analyses gratuites, et codes promo pour les enseignants (`in_app_purchase`).
- Mode voiture : musique calée sur le tempo.

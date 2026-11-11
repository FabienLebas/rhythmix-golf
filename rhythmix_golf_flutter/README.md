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

### Apple Watch (vibrations au poignet)
Une app watchOS joue le tempo en vibrations. L'iPhone envoie le tempo (celui de l'analyse vidéo ou des réglages), la montre cadence elle-même les vibrations, et la **Digital Crown** ajuste la vitesse en renvoyant le tempo à l'iPhone. Code dans `native/watchos/`, mise en place Xcode et points à tester : `native/watchos/README.md`. iOS uniquement.

### Historique du tempo
Chaque vidéo analysée ajoute un point (ratio montée : descente) à l'historique du mode en cours, grand jeu ou putting (`lib/history_card.dart`). Le graphique montre la cible (3 ou 2) et les zones « Trop lent » (au-dessus), « Dans la cible » (± 0,15) et « Trop rapide » (en dessous). Retoucher les repères met à jour le point de la même vidéo. Les données sont stockées sur l'appareil avec `shared_preferences` (pas de base de données), 200 points maximum par mode, avec un bouton pour effacer.

### Gratuité et achat intégré
- Les **3 premières analyses vidéo sont gratuites**. Une analyse compte quand une vidéo est analysée avec succès : un échec, une retouche des repères ou un changement de mode (grand jeu ↔ putting) sur la même vidéo ne comptent pas.
- Ensuite, un **achat unique** (pas d'abonnement) débloque les analyses à vie. Argument : « Pour le prix d'un seau de balles ». Le métronome et l'historique restent gratuits.
- Un encadré dans la carte d'analyse explique la règle et le nombre d'analyses restantes ; une fenêtre d'achat s'ouvre quand la gratuité est épuisée, avec « Restaurer mes achats » (obligatoire pour l'App Store).
- Code : `lib/purchase.dart` (compteur, achat, restauration, plugin officiel `in_app_purchase`) et `lib/paywall.dart` (encadré et fenêtre d'achat). Aucun serveur : le compteur est dans `shared_preferences`, donc il repart à zéro si l'app est désinstallée (l'achat, lui, se restaure via le store).

**Mise en place dans les stores (à faire une fois)**
1. Créer un produit **non consommable** d'identifiant `rhythmix_golf_unlock` (`kProductId`) dans App Store Connect (*Achats intégrés*) et dans la Google Play Console (*Produits intégrés à l'application*).
2. Prix de lancement : **2,99 €**. Pour passer à **4,99 €** plus tard : changer le prix dans les deux stores, puis mettre `kLaunchOffer = false` dans `lib/purchase.dart` (retire la mention « prix de lancement » et le prix barré). Le prix affiché dans l'app est toujours celui renvoyé par le store.
3. iOS : ajouter la capacité **In-App Purchase** dans Xcode (*Signing & Capabilities*). Android : l'app doit être publiée au moins en test interne pour que les achats fonctionnent (les achats sont impossibles avec l'APK installé à la main).
4. Tester avec un compte *Sandbox* (Apple) ou un testeur de licence (Google).

---

## Structure

```
lib/
  main.dart            application, thème (vert grand jeu / bleu putting)
  app_state.dart       réglages, persistance, pilotage du métronome
  metronome.dart       génération du WAV d'un cycle + lecture en boucle (just_audio)
  metronome_card.dart  interface du métronome
  video_card.dart      interface d'analyse : aperçu, bande d'images, repères, résultat
  purchase.dart        3 analyses gratuites + achat intégré unique
  paywall.dart         encadré « analyses gratuites » et fenêtre d'achat
  strip.dart           dessin de la bande d'images
  detection.dart       algorithmes de détection (Dart pur)
  native.dart          appels au code natif
  widgets.dart         petits composants
assets/
  icon.png             icône de l'app 1024×1024 (App Store / Play Store)
  icon_foreground.png  premier plan de l'icône adaptative Android
  logo_mark.png        logo sans texte, fond transparent (barre d'en-tête)
  logo_full.png        logo complet avec « Rhythmix Golf » (écran de démarrage)
native/
  android/RhythmixNativePlugin.kt   décodage Android
  ios/RhythmixNativePlugin.swift    décodage iOS
tool/bootstrap.sh      prépare le projet (dossiers android/ios + plugin natif)
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
- Codes promo pour les enseignants (codes d'offre App Store / Google Play).
- Mode voiture : musique calée sur le tempo.

> La compilation automatique (APK + iOS) est définie à la racine du dépôt : `.github/workflows/build.yml`. GitHub ne lit les workflows qu'à cet endroit.

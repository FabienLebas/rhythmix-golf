# App Apple Watch (watchOS)

La montre joue le tempo du swing en **vibrations** : une par temps (départ, sommet, impact).

```
iPhone  ── tempo (mode, montée, descente, pause, marche/arrêt) ──▶  montre
iPhone  ◀── nouveau tempo (molette) et marche/arrêt ───────────────  montre
```

- L'iPhone décide du tempo (analyse vidéo, réglages). Il l'envoie à la montre avec WatchConnectivity.
- La montre **cadence elle-même** les trois vibrations avec sa propre horloge. Le Bluetooth ne transporte que le tempo : sa latence variable ne déforme donc pas le rythme.
- **Molette (Digital Crown)** : 60 à 140 %, à droite = plus rapide, comme le curseur de l'iPhone. La montre renvoie le nouveau tempo à l'iPhone, qui l'applique (et redémarre son propre son s'il tourne).
- Un changement de vitesse prend effet au swing suivant.
- Le mode (grand jeu / putting) se choisit sur l'iPhone.
- La montre ne se met jamais à vibrer à l'ouverture : un ordre de démarrage ancien est ignoré.

## Fichiers

| Fichier | Rôle |
|---|---|
| `RhythmixWatchApp.swift` | point d'entrée |
| `ContentView.swift` | écran : mode, durées, vitesse, démarrer/arrêter, molette |
| `TempoModel.swift` | cadencement des vibrations, session prolongée, échanges avec l'iPhone |
| `../ios/WatchBridge.swift` | côté iPhone, copié dans le plugin par `tool/bootstrap.sh` |
| `../../lib/watch.dart` | côté Flutter |

## Créer la cible dans Xcode (une fois, sur un Mac)

`tool/bootstrap.sh` ne sait pas créer de cible watchOS : on l'ajoute à la main.

1. `bash tool/bootstrap.sh`, puis ouvrir `ios/Runner.xcworkspace` dans Xcode.
2. *File ▸ New ▸ Target… ▸ watchOS ▸ App*. Nom : `Rhythmix Watch`. Choisir *Watch App for Existing iOS App* avec **Runner** comme app compagnon. Langage Swift, interface SwiftUI.
3. Supprimer les fichiers générés (`…App.swift`, `ContentView.swift`) et ajouter à la cible les trois `.swift` de ce dossier.
4. Version minimale : **watchOS 10** (la molette et `onChange` à deux paramètres en dépendent).
5. *Signing & Capabilities* de la cible montre : choisir ton équipe. Ajouter **Background Modes** et cocher **Physical Therapy** (clé `WKBackgroundModes`), pour que les vibrations continuent poignet baissé.
6. Cible **Runner** ▸ *Build Phases* : faire glisser **Embed Watch Content** juste sous *Copy Bundle Resources*, au-dessus de *[CP] Embed Pods Frameworks* et *Thin Binary*. Sinon : erreur « Cycle inside Runner ».
7. Identifiants pour un compte gratuit : Runner `com.fabienlebas.rhythmixGolf`, montre `com.fabienlebas.rhythmixGolf.watchkitapp`, et dans les *Build Settings* de la montre, `WKCompanionAppBundleIdentifier` = identifiant de Runner.
8. Brancher l'iPhone, appairé à la montre, choisir le schéma de la cible montre et lancer. Ouvrir l'app sur la montre une première fois.

## À vérifier à l'essai

- **Ressenti** : les trois motifs sont-ils distincts, surtout départ / impact, à 0,27 s d'écart et poignet en mouvement ? Les motifs sont réglés au début de `TempoModel.swift` (`Beat.haptic`). watchOS n'offre que des motifs prédéfinis, sans durée ni intensité réglables.
- **Régularité** : écart réel entre les vibrations (à mesurer en tapotant au rythme).
- **Poignet baissé** : le type de session `physical-therapy` est celui qui autorise les vibrations en arrière-plan, mais il est prévu pour la rééducation. À valider pour une soumission à l'App Store ; sinon, une session d'entraînement (HealthKit, activité *golf*) est l'alternative.
- **Décalage son / vibration** : la montre et l'iPhone démarrent chacun de leur côté, sans alignement de phase. Si tu écoutes le son en même temps, tu peux entendre un décalage.

## Limites actuelles

- Le dossier `ios/` est généré et ignoré par git : la cible montre n'est pas dans le dépôt et le CI iOS ne la compile pas. Pour publier, compiler en local sur le Mac.
- Rien n'a été compilé ni lancé : ce code est écrit sans Xcode, il faut le tester.

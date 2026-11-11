# Rhythmix Golf

Application web à fichier unique (`index.html`, sans dépendance) pour travailler son **tempo de swing** au golf :

- un **métronome** réglé sur le bon rapport montée / descente ;
- une **analyse vidéo automatique** qui mesure ton tempo réel et règle le métronome sur le tempo à viser.

Le tempo, c'est le rapport entre la durée de la montée (backswing) et celle de la descente (downswing) :

| Mode | Ratio cible | Valeurs par défaut |
|---|---|---|
| Grand jeu | 3 : 1 | montée 0,81 s · descente 0,27 s |
| Putting | 2 : 1 | montée 0,60 s · descente 0,30 s |

Toutes les durées sont exprimées en **secondes**.

---

## Utilisation

### 1. Le métronome

1. Choisis **Grand jeu** ou **Putting**.
2. Appuie sur **Démarrer**. Trois bips se succèdent par swing :
   - bip grave : **départ** de la montée ;
   - bip moyen : **sommet** de la montée ;
   - bip aigu : **impact**.
   L'intervalle entre les bips est exactement la durée de montée, puis de descente. Une pause (réglable de 1 à 8 s) sépare deux swings.
3. Réglages :
   - **Montée / Descente** : durées en secondes. Avec la case « Garder le ratio », modifier l'une change l'autre pour conserver le ratio.
   - **Vitesse** (60 à 140 %) : à droite, le swing est plus rapide ; à gauche, plus lent. Le ratio ne change pas.
   - **Réinitialiser** : revient aux valeurs par défaut du mode.

Le son continue de fonctionner même quand l'iPhone est en **mode silencieux** (l'application ouvre une session audio de lecture).
Les réglages sont mémorisés dans le navigateur (`localStorage`).

### 2. L'analyse vidéo

1. Filme ton swing **de face** (caméra face à toi, club visible), en gardant le téléphone fixe.
2. Charge la vidéo dans la carte « Analyser ». La cadence (images par seconde) est lue automatiquement dans le fichier.
3. L'application analyse la vidéo image par image et place trois repères :
   - **Départ** : le club commence à bouger sur la montée ;
   - **Sommet** : haut de la montée, le club repart vers la balle ;
   - **Impact** : le club touche la balle.
4. Elle affiche ton tempo mesuré (montée, descente, ratio, durée du swing) et un conseil, par exemple :
   *« Ta montée est trop lente : accélère-la d'environ 0,27 s et garde la même descente. »*
5. **Le métronome est réglé automatiquement sur le tempo cible** : ta descente est conservée et la montée est ajustée pour obtenir 3 : 1 (grand jeu) ou 2 : 1 (putting). Il te suffit d'appuyer sur Démarrer et de swinguer en suivant les bips.

Une petite ligne d'information indique le format de la vidéo chargée (taille, images/s, durée).

#### Corriger les repères à la main

Si un repère est mal placé, ajuste-le sur la bande d'images :

- fais glisser la bande (comme dans un logiciel de montage) ;
- boutons **±1 / ±5 images** ;
- touche **Départ / Sommet / Impact** pour sélectionner un repère, puis fais glisser : il suit l'image sous le trait blanc ;
- sur ordinateur : flèches ← / → (Maj = 5 images), touches 1 / 2 / 3, molette.

Le tempo et le métronome se recalculent à chaque correction.

### 3. L'historique du tempo

Chaque vidéo analysée ajoute un point à l'**historique** du mode en cours (un historique pour le grand jeu, un autre pour le putting). La carte « Historique », en bas de page, affiche :

- un **graphique** du ratio montée : descente au fil des analyses (par exemple une vidéo à 3,5 : 1 donne un point à 3,5) ;
- la **cible** (3 au grand jeu, 2 au putting) et trois zones : au-dessus de la cible → **« Trop lent »**, autour de la cible (± 0,15) → **« Dans la cible »**, en dessous → **« Trop rapide »** ;
- la liste des dernières analyses, avec leur verdict.

Si tu corriges les repères à la main, le point de cette vidéo est mis à jour (il n'est pas ajouté en double). Les données restent **sur l'appareil** (`localStorage`, aucune base de données ni serveur) ; 200 points au maximum par mode. Un bouton permet d'effacer l'historique du mode.

**Gratuité** : les 3 premières analyses vidéo sont gratuites (compteur dans `localStorage`, `FREE_MAX` dans `index.html`). Ensuite, le site invite à prendre l'app mobile (achat unique, « pour le prix d'un seau de balles »). Le métronome reste gratuit. Pas de paiement sur le web.

---

## Comment fonctionne la détection

Tout se passe **dans le navigateur** : aucune vidéo n'est envoyée sur un serveur.

1. **Lecture de la cadence** : analyse du conteneur MP4/MOV (tables `moov` / `stts`) ; à défaut, mesure via `requestVideoFrameCallback`.
2. **Extraction** : la vidéo est parcourue image par image (positionnement exact sur chaque image). Chaque image est réduite en plusieurs étapes puis convertie en niveaux de gris (miniature de 36 × 64 px environ), ce qui réduit le bruit.
3. **Courbe de mouvement** : différence moyenne entre images successives, lissée sur 3 points.
4. **Grand jeu**
   - *Impact* : pic sonore du claquement de la balle dans la piste audio (avec une petite correction sur iOS) ; à défaut, pic de mouvement.
   - *Sommet* : décalage latéral de la bande des hanches (suivi des hanches vu de face), à défaut le mouvement.
   - *Départ* : premier instant où le mouvement sort du calme (seuil adapté à la vidéo, plusieurs images calmes consécutives avant).
5. **Putting** : détection par le mouvement seul, sans le son (le bruit d'un putt est trop faible).
6. **Calcul** : montée = (sommet − départ) / cadence ; descente = (impact − sommet) / cadence ; ratio = montée / descente. Cible : descente × 3 (ou × 2) pour la montée.

Vérifié sur une vidéo de grand jeu en H.264 (images 78 / 138 / 153) et sur une vidéo de putt.

---

## Formats vidéo et limites

- Les vidéos **H.264** fonctionnent partout. Les vidéos iPhone en **HEVC / H.265** (surtout en 4K) ne sont pas lisibles par certains navigateurs de bureau.
- Dans ce cas, un message le signale. Solutions :
  - ouvrir la page dans **Safari** ;
  - sur iPhone : Réglages › Appareil photo › Formats › **« Le plus compatible »** ;
  - ou convertir : `ffmpeg -i IMG.mov -c:v libx264 -crf 20 sortie.mp4`.
- Plus la vidéo est nette, de face et stable, plus la détection est fiable. Les repères restent toujours ajustables à la main.
- L'analyse est limitée à 900 images par vidéo.

---

## Installation / hébergement

L'application est un seul fichier HTML :

1. Renomme `rhythmix-golf.html` en `index.html`.
2. Dépose-le sur un hébergement statique (GitHub Pages, Netlify, Vercel, serveur perso).
3. Accède-y en **https** (nécessaire pour le son et la vidéo sur iPhone).
4. Sur iPhone, « Partager › Sur l'écran d'accueil » donne une icône d'application.

Aucune compilation, aucun serveur applicatif.

---

## Pistes d'évolution

- Version **Flutter** (iOS / Android) : caméra native, son en arrière-plan et écran verrouillé, mode voiture avec musique calée sur le tempo.
- Le décodage de secours des vidéos HEVC a été **volontairement retiré** : il ne doit **pas** être porté dans la version Flutter (le décodage natif gère le HEVC).
- Modèle économique envisagé : métronome gratuit, quelques analyses vidéo gratuites, puis achat unique (3 à 5 €) ; gratuité pour les enseignants via codes promo.
- Étalonner la détection du putting avec davantage de vidéos réelles.

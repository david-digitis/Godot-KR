# Godot-KR

Le moteur de KNIFE-RIDER : **Godot officiel, compilé en double précision**
(`precision=double`). Rien d'autre n'est changé : les sources viennent de
[godotengine/godot](https://github.com/godotengine/godot), à l'étiquette indiquée dans
chaque Release.

**Pourquoi ?** Le jeu veut des cartes où l'on vole jusqu'à 50 km du centre. En simple
précision, l'image tremble loin du centre (12 px à 50 km) ; en double, elle ne bouge plus
(0,18 px, le plancher de la mesure), pour quelques pour cent d'image en plus côté
processeur. Le raisonnement et les mesures : `CONCEPTION/GRANDES-CARTES.md` du dépôt du jeu
([lien](https://github.com/david-digitis/KNIFE-RIDER/blob/dev/CONCEPTION/GRANDES-CARTES.md),
réservé à l'équipe).

**Qui en a besoin ?** Le jeu publié et le serveur sont fabriqués avec ce moteur. **Pour
développer, l'équipe garde le Godot officiel** : le projet s'ouvre avec les deux. Ce dépôt
sert à voir le jeu « comme publié » et à fabriquer les versions.

## Récupérer l'éditeur

1. Page [Releases](../../releases) : prendre la version que le jeu utilise (par exemple
   `4.7.2-stable`).
2. Télécharger `godot-kr-<version>-windows-editor.zip` et le décompresser dans un dossier à
   lui, **à côté** de votre Godot officiel (pas à sa place).
3. Lancer `godot.windows.editor.double.x86_64.exe`, puis « Importer » ou « Ouvrir » le
   dossier `game` du jeu, comme avec l'officiel.

> ⚠️ **À l'ouverture, cet éditeur ajoute `"Double Precision"` dans `config/features` de
> `project.godot`. Ne commitez jamais cette ligne** : elle ne doit pas entrer dans le dépôt du
> jeu (un contrôle la refusera), sinon le Godot officiel de toute l'équipe se plaindra à
> chaque ouverture. Avant un commit, `git diff game/project.godot` : si la ligne y est,
> `git checkout -- game/project.godot`.

## Fabriquer une version

Tout se fait sur GitHub, aucune machine à préparer.

1. Onglet **Actions** → **Godot double precision** → **Run workflow**.
2. Les champs :
   - **ref** : l'étiquette de Godot à compiler (`4.7.2-stable`), ou un commit pour une
     pré-version.
   - **version_status** : vide pour une version stable ; `dev7`, `beta1`… pour une
     pré-version compilée depuis un commit.
   - **publish** : coché = une Release est créée à la fin avec les binaires. Décoché = les
     binaires restent 30 jours dans les artefacts du lancement (pour un essai).
   - **release_tag** : le nom de la Release. Vide = la valeur de `ref`. Pour un commit,
     donner un nom lisible (`4.8-dev7`).
3. Quatre machines compilent en parallèle (éditeur Windows, modèle d'export Windows release,
   Windows debug, Linux release pour le serveur). Compter **une à deux heures** en tout.
4. Les binaires arrivent dans la Release (ou dans les artefacts du lancement).

## Changer de version de Godot

- **Une version stable** : son étiquette dans [godotengine/godot](https://github.com/godotengine/godot/tags)
  (`4.7.3-stable`…), dans `ref`.
- **Une pré-version** (`4.8-dev7`, `beta1`…) : ses étiquettes ne sont pas dans le dépôt des
  sources mais dans [godotengine/godot-builds](https://github.com/godotengine/godot-builds/releases).
  La page de la pré-version y donne son commit : le mettre dans `ref`, le statut (`dev7`) dans
  `version_status`, et un nom dans `release_tag`.

## Ce que contient une Release

| Fichier | Quoi |
|---|---|
| `godot-kr-<version>-windows-editor.zip` | l'éditeur Windows et sa console, avec les licences |
| `godot.windows.template_release.double.x86_64.exe` (et `.console.exe`) | modèle d'export Windows, version joueurs |
| `godot.windows.template_debug.double.x86_64.exe` (et `.console.exe`) | modèle d'export Windows, version de débogage |
| `godot.linuxbsd.template_release.double.x86_64` | modèle d'export Linux, celui du serveur de jeu |
| `BUILD-INFO-<cible>.txt` | commit de Godot, options, durée, taille, empreinte de chaque binaire |
| `SHA256SUMS.txt` | les empreintes de tous les fichiers de la Release |
| `LICENSE.txt`, `COPYRIGHT.txt` | la licence de Godot (MIT) et celles de ses bibliothèques tierces |

Les modèles d'export se donnent à Godot par `custom_template` dans `export_presets.cfg`.

Options de compilation : `precision=double production=yes lto=none d3d12=no accesskit=no`.
Deux écarts avec un build officiel : pas d'optimisation à l'édition de liens (`lto=none`,
l'officielle demande jusqu'à 30 Go de mémoire, trop pour les machines de GitHub) et pas de
lecteur d'écran (`accesskit=no`). Le jeu est en Vulkan : Direct3D 12 n'est pas compilé.

## Durées mesurées

| Cible | 32 cœurs | Machine GitHub (4 cœurs) |
|---|---|---|
| Éditeur Windows | 6 min 34 | à mesurer |
| Modèle Windows (chacun) | 4 min 27 | à mesurer |
| Modèle Linux | 3 min 36 | à mesurer |

## Compiler sans GitHub

Sur une Ubuntu 24.04 (ou WSL), avec `sudo` :

```bash
./build_godot_double.sh 4.7.2-stable out/4.7.2-stable
```

Les réglages (cibles, précision, dossier de travail…) sont décrits en tête du script. Il est
né dans le dépôt du jeu (`tools/build_godot_double.sh`, 2026-10-04) et vit ici depuis le
2026-10-05.

## Licence

Le script et le workflow : MIT, Digitis (`LICENSE`). Les binaires sont Godot tel quel, sous
la licence de Godot (MIT) et celles de ses tiers (`COPYRIGHT.txt`, joint à chaque Release).

# Migration PC — checklist de réinstallation

Checklist HTML pour réinstaller un PC Windows sans rien oublier : un script inventorie
les logiciels de l'ancienne machine, la page les affiche en liste à cocher.

Fichier unique, aucune dépendance, aucun serveur. Fonctionne depuis une clé USB sur un
PC fraîchement installé, sans réseau.

---

## Sommaire

- [À quoi ça sert](#à-quoi-ça-sert)
- [Démarrage rapide](#démarrage-rapide)
- [Le scanner](#le-scanner)
- [La checklist](#la-checklist)
- [Formats de fichiers](#formats-de-fichiers)
- [Écrire son propre profil](#écrire-son-propre-profil)
- [Vie privée](#vie-privée)
- [Tests](#tests)
- [Déploiement](#déploiement)
- [Limites connues](#limites-connues)

## À quoi ça sert

Réinstaller un PC, c'est trois problèmes : se souvenir de ce qui était installé, le
réinstaller dans le bon ordre, et ne pas oublier de sauvegarder ce qui n'existe qu'en
local. Ce projet couvre les trois.

```
Ancien PC                          Nouveau PC
─────────                          ──────────
scan-pc.ps1                        index.html
    │                                  │
    └──► inventaire-pc.json ───────────┘
         (clé USB)                 liste à cocher
                                   + script winget
```

Le scan n'est pas obligatoire : la page s'ouvre sur un profil d'exemple utilisable tel
quel, et vous pouvez écrire le vôtre.

## Démarrage rapide

**Avec un inventaire de l'ancien PC** — sur l'ancienne machine :

```powershell
powershell -ExecutionPolicy Bypass -File .\scan-pc.ps1
```

Copiez `inventaire-pc.json` et `index.html` sur une clé USB. Sur le nouveau PC, ouvrez
`index.html`, cliquez sur **📥 Importer**, choisissez le JSON.

**Sans scan** : ouvrez `index.html` et cochez. Le profil d'exemple couvre les étapes
communes à toute réinstallation Windows.

## Le scanner

`scan-pc.ps1` interroge quatre sources et fusionne les résultats :

| Source | Ce qu'elle apporte |
|---|---|
| `winget list` | Les identifiants d'installation officiels |
| Registre `Uninstall` | Les logiciels installés classiquement (32 et 64 bits, machine et utilisateur) |
| Paquets APPX | Les applications du Microsoft Store |
| Manifestes Steam | Les jeux installés, sur tous les disques |

Une entrée vue par plusieurs sources est fusionnée : le nom vient du registre,
l'identifiant winget de winget, et rien n'apparaît deux fois. Chaque application est
classée par catégorie selon des mots-clés, avec une priorité et une durée estimée —
tout cela reste modifiable à la main dans le JSON.

Les redistribuables Visual C++, les mises à jour et les composants système sont écartés
par défaut, sinon la liste dépasse largement ce qu'on réinstalle vraiment.

| Option | Effet |
|---|---|
| `-Sortie <chemin>` | Change le fichier produit (défaut : `inventaire-pc.json`) |
| `-ToutInclure` | Désactive le filtrage, garde tout |
| `-SansStore` | Ignore les applications du Microsoft Store |
| `-SansJeux` | Ignore les bibliothèques Steam |

Le script n'a pas besoin des droits administrateur, mais sans eux les logiciels
installés par d'autres comptes utilisateurs peuvent manquer. Il n'écrit qu'un fichier
local et n'envoie rien sur le réseau.

## La checklist

Quatre onglets : **Nouveau PC** (drivers et vérifications), **Apps**, **Données** à
sauvegarder, **PWA** (raccourcis web).

La progression est enregistrée dans le navigateur au fur et à mesure et peut être
exportée en JSON pour passer d'une machine à l'autre.

**Navigation** — mode normal ou compact, thème clair/sombre suivant les préférences
système, recherche sur les quatre onglets à la fois, tri des apps par catégorie,
priorité, durée ou ordre conseillé, filtre sur les apps sans winget.

**Installation** — le badge winget copie la commande d'installation en un clic, un
bouton par catégorie copie le script de toute la section. Deux exports pour réinstaller :
**⬇️ Script restant** produit un `.ps1` limité aux apps non cochées, et
**⬇️ winget .json** le format officiel de `winget import`, à préférer — il saute ce qui
est déjà installé et reprend proprement après une interruption.

```powershell
winget import -i winget-restant.json --accept-package-agreements --accept-source-agreements
```

**Suivi** — barre de progression globale et par onglet, estimation du temps restant
calculée depuis les durées, chronomètre de session, historique des dernières actions,
notes libres sur chaque élément, champs dédiés aux clés de licence et aux variables
d'environnement.

**Sortie** — export de la progression, du profil, du script winget complet ou partiel,
de la checklist en texte, et impression globale ou par onglet.

**En cas de problème** — chaque onglet est rendu séparément. Si l'un échoue, les autres
s'affichent quand même et un bandeau nomme l'onglet fautif et l'erreur, au lieu de
laisser une page à moitié vide sans explication.

## Formats de fichiers

Le bouton **Importer** accepte quatre formats et les reconnaît tout seul.

**Export winget** — le fichier produit par `winget export -o apps.json` sur n'importe
quel PC, sans rien installer de ce projet. Il ne contient que des identifiants, donc les
noms affichés sont déduits : `Mozilla.Firefox` devient Firefox, édité par Mozilla. Les
catégories sont attribuées par mots-clés.

**Inventaire** — produit par `scan-pc.ps1`, reconnu à son champ `type`. Plus riche
qu'un export winget : il couvre aussi le Microsoft Store, Steam et les logiciels absents
du dépôt winget.

```json
{
  "type": "inventaire-migration-pc",
  "version": 1,
  "genere": "2026-09-24T10:00:00.000+02:00",
  "machine": { "os": "Windows 11 Pro", "nom": "PC-BUREAU" },
  "apps": [
    { "nom": "7-Zip", "editeur": "Igor Pavlov", "version": "24.08",
      "source": "registre, winget", "winget": "7zip.7zip",
      "cat": "system", "priorite": "med", "duree": 5 }
  ]
}
```

**Profil** — les listes des quatre onglets. C'est le format de `presets/exemple.json`,
et celui que produit le bouton 🧩.

**Progression** — les cases cochées, les notes et les dates, sans les listes. C'est ce
que produit le bouton 💾.

Importer un export winget, un inventaire ou un profil remplace les listes mais conserve
la progression. Importer une progression fait l'inverse.

## Écrire son propre profil

Copiez `presets/exemple.json` et modifiez-le. Les identifiants doivent être uniques
dans tout le fichier : ce sont eux qui portent les cases cochées.

```javascript
meta   // { nom, soustitre } — affichés dans l'en-tête
cats   // { clé: libellé } — les catégories de l'onglet Apps
npc    // { id, o, n, src, p, t, d, post?, dep?, warn? }
apps   // { id, n, c, src, w?, p, t, d, dep?, warn? }
data   // { id, n, p, note, pr, lic?, env? }
pwa    // { id, n, u, d }
ordre  // [ id, ... ] — l'ordre d'installation conseillé
requetes // { "Nom de l'app": "requête de recherche" }
```

`p` et `pr` valent `high`, `med` ou `ok` · `t` est une durée en minutes · `o` est le
numéro d'étape · `post: true` classe l'étape dans les vérifications d'après-installation
· `w` est l'identifiant winget · `dep` affiche un badge de dépendance · `warn` affiche
un avertissement.

Les liens de téléchargement sont volontairement des requêtes de recherche restreintes
au domaine officiel (`site:7-zip.org download`) plutôt que des URL directes : une URL
de téléchargement est périmée en quelques mois, une requête reste valable et évite les
faux sites de drivers.

## Vie privée

Tout reste sur votre machine. La page est un fichier statique sans serveur ni appel
réseau : la progression et le profil importé vivent dans le stockage local du
navigateur, les exports sont des téléchargements ordinaires.

L'inventaire produit par le scan décrit précisément votre machine. Ne le publiez pas,
et faites attention à ce que vous écrivez dans les notes et les champs de licence — ils
partent dans le fichier de progression exporté.

Le stockage local est lié au navigateur **et** au chemin du fichier. Si la lettre de
lecteur de la clé USB change d'un PC à l'autre, la progression ne suit pas : l'export
JSON est le seul transfert fiable.

## Tests

```bash
npm install                       # une seule fois
npm test                          # profil + checklist, sans navigateur ni Windows
npm run test:scan                 # scanner (nécessite PowerShell)
npm run test:navigateur           # rendu réel dans Chromium
```

Quatre suites, dans l'ordre où la CI les lance.

`tests/test-profil-sync.js` garantit que le profil embarqué dans `index.html` et
`presets/exemple.json` ne divergent pas, et vérifie les invariants du profil :
identifiants uniques sur les quatre onglets, priorités valides, catégories déclarées,
ordre conseillé ne citant que des éléments existants.

`tests/test-checklist.js` extrait le JS de `index.html` et l'exécute dans un DOM simulé.
Il rejoue l'import d'un inventaire réellement produit par le scanner
(`tests/inventaire-exemple.json`), ce qui couvre la chaîne de bout en bout.

`tests/test-scan.ps1` couvre le classement, la fusion entre sources et le parsing de la
sortie winget, sans toucher à la machine.

`tests/test-navigateur.js` charge la page dans un vrai Chromium et vérifie ce qu'un DOM
simulé ne voit pas : que les quatre panneaux sont bien frères et non imbriqués, que les
éléments ont une taille non nulle, que la saisie des clés de licence survit à un
rechargement, et qu'une exception pendant un rendu s'affiche au lieu de disparaître.
Deux variables d'environnement facultatives : `CHROME` pour pointer un binaire Chromium
existant, `PROFIL` pour tester votre propre profil à la place de l'exemple (par défaut
il cherche `profil-local.json` à la racine).

### Intégration continue

`.github/workflows/ci.yml` lance les quatre suites à chaque push et sur chaque pull
request. La publication sur GitHub Pages dépend de ce job : un test rouge, et rien n'est
mis en ligne.

Pour que ce garde-fou serve, le dépôt doit être réglé sur **Settings → Pages → Source :
GitHub Actions**. Sur « Deploy from a branch », GitHub publierait la branche en parallèle
et court-circuiterait les tests.

## Déploiement

```
Migration-PC/
├── index.html                    # la checklist (tout est dedans)
├── scan-pc.ps1                   # le scanner Windows
├── presets/exemple.json          # profil d'exemple, aussi embarqué dans index.html
├── tests/                        # suites Node, PowerShell et navigateur
└── .github/workflows/ci.yml      # tests, puis publication si tout est vert
```

`package.json` ne sert qu'aux tests : `index.html` n'a aucune dépendance et n'a jamais
besoin d'être construit.

Les fichiers personnels (`profil-*.json`, `inventaire-*.json`, `progression-*.json`)
sont exclus par `.gitignore` : gardez le vôtre en local, hors du dépôt.

Le dépôt est publiable tel quel sur GitHub Pages : **Settings → Pages → Deploy from a
branch → `main` → `/ (root)`**.

```bash
git clone https://github.com/antoniman31/Migration-PC.git
```

URL publiée : `https://antoniman31.github.io/Migration-PC`

## Limites connues

Le scanner est **Windows uniquement** et demande PowerShell 5.1 ou supérieur. S'il
refuse de démarrer, lancez-le avec `-ExecutionPolicy Bypass`.

**Tous les logiciels n'ont pas d'identifiant winget.** Ceux détectés par le registre
seul sortent sans commande d'installation : la checklist les affiche avec un lien de
recherche à la place. Le filtre « Sans winget » permet de les isoler, et ils
n'apparaissent pas dans l'export `winget .json`, qui ne peut contenir que des paquets
connus de winget.

**Un export winget importé perd les noms d'origine.** Le format ne stocke que les
identifiants ; `7zip.7zip` donne « 7zip » et non « 7-Zip ». Passer par `scan-pc.ps1`
donne des noms corrects, puisqu'il lit le registre.

**La déduplication est approximative.** Elle compare les noms en ignorant la version et
les mentions entre parenthèses, ce qui rapproche correctement `Mozilla Firefox (x64 fr)`
du registre et `Mozilla Firefox` de winget, mais fusionne aussi deux versions majeures
d'un même logiciel — Python 3.12 et 3.13 donnent une seule ligne.

**Le classement par catégorie est indicatif**, fondé sur des mots-clés. Un logiciel peu
connu atterrit dans « Utilitaires Système ». Les catégories se corrigent dans le JSON.

**Les étapes « Nouveau PC », « Données » et « PWA » ne sont pas scannées** : un
inventaire importé reprend celles du profil d'exemple, à adapter à votre matériel. Un
scan ne peut pas deviner qu'il faut activer le profil XMP dans le BIOS.

**Epic Games, GOG et les autres lanceurs ne sont pas parcourus** — seul Steam l'est. Les
jeux des autres plateformes apparaissent uniquement si leur lanceur est détecté.

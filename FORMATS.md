# Les fichiers que la page lit et écrit

Pour fabriquer un profil à la main, ou comprendre ce que le bouton **Importer**
accepte. Rien ici n'est nécessaire pour se servir du programme — voir
[README.md](README.md) pour ça.

## Formats de fichiers

Le bouton **Importer** accepte quatre formats et les reconnaît tout seul, sans que vous
ayez à dire lequel.

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
      "cat": "system", "priorite": "med", "duree": 5, "tailleGo": 0.02 }
  ],
  "materiel": { "cm": "ASUSTeK ROG STRIX B850-A", "cpu": "AMD Ryzen 7 9800X3D",
                "gpu": "NVIDIA GeForce RTX 5070 Ti", "ram": "32 Go DDR5 6000 MT/s",
                "ssd": "Samsung SSD 9100 PRO 2TB" },
  "pilotesTiers": [
    { "classe": "Net", "fournisseur": "Realtek", "appareils": ["Realtek Gaming GbE"] }
  ],
  "pilotes": []
}
```

`materiel` remplit le bloc « Ma configuration », `pilotesTiers` les pilotes non-Microsoft
relevés, `pilotes` — sur un instantané de cible seulement — les périphériques que Windows
signale comme mal installés.

Tous ces champs sont facultatifs : un inventaire qui n'en porte aucun reste valide, et la
page ne montre que ce qu'elle a reçu.

**Profil** — les listes des deux onglets à cocher. C'est le format de `presets/exemple.json`,
et celui que produit le bouton 🧩.

**Progression** — les cases cochées, les notes et les dates, sans les listes. C'est ce
que produit le bouton 💾.

Importer un export winget, un inventaire ou un profil remplace les listes mais conserve
la progression. Importer une progression fait l'inverse.

## Écrire son propre profil

Copiez `presets/exemple.json` et modifiez-le. Les identifiants doivent être uniques
dans tout le fichier : ce sont eux qui portent les cases cochées.

Le profil d'exemple existe en double : dans ce fichier, et embarqué dans `index.html`
pour que la page fonctionne sans serveur. Après avoir modifié le fichier, lancez
`npm run sync` pour recopier l'un dans l'autre — `npm test` échoue s'ils divergent.

`npm run sync` met aussi à jour le nom de cache du service worker, qu'il dérive d'une
empreinte d'`index.html`. Sans cela un appareil qui a installé la checklist garderait
l'ancienne version hors ligne ; `npm run test:pwa` échoue si on a oublié de le lancer.

```javascript
meta   // { nom, soustitre } — affichés dans l'en-tête
cats   // { clé: libellé } — les catégories de l'onglet Logiciels
quitter // { id, n, p, note, pr, warn? } — facultatif, sur l'ancien PC
npc    // { id, o, n, src, p, t, d, post?, dep?, warn? }
apps   // { id, n, c, src, w?, p, t, d, dep?, warn? }
pwa    // { id, n, u, d }
ordre  // [ id, ... ] — l'ordre d'installation conseillé
requetes // { "Nom de l'app": "requête de recherche" }
materiel // { cm, cpu, gpu, ram, ssd, eth, wifi, audio, bios } — le bloc « Ma configuration »
```

`p` vaut `high`, `med` ou `ok` · `t` est une durée en minutes · `w` est l'identifiant
winget · `warn` affiche un avertissement.

Les champs `cas`, `alt`, `o`, `post` et `pilote` ont existé : ils servaient aux onglets
« Avant de quitter » et « Nouveau PC » et aux quatre cas qui les filtraient. Ils ne sont
plus lus. Un profil qui les porte encore reste valide, ils sont simplement ignorés.

`dep` accepte deux formes. Une **chaîne** est un libellé affiché tel quel, sans
vérification possible — c'est le format d'origine, toujours accepté. Un **tableau
d'identifiants** décrit un vrai lien et débloque trois choses : le badge nomme les
prérequis et se met en évidence tant qu'ils ne sont pas cochés, un avertissement
apparaît si vous cochez dans le désordre — sans jamais bloquer —, et l'ordre
d'installation est calculé par tri topologique au lieu d'être maintenu à la main dans
`ordre`. Les scripts winget, `.ps1` comme `.json`, sortent dans cet ordre. Les cycles
sont rompus plutôt que de figer la page.

```json
{ "id": "a10", "n": "Visual Studio Code", "dep": ["a7"] }
```

Les liens de téléchargement sont volontairement des requêtes de recherche restreintes
au domaine officiel (`site:7-zip.org download`) plutôt que des URL directes : une URL
de téléchargement est périmée en quelques mois, une requête reste valable et évite les
faux sites de drivers.


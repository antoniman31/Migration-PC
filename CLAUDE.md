# Règles pour travailler sur ce dépôt

Une checklist de réinstallation Windows, dans **un seul `index.html` autonome** : pas d'étape
de build, pas de CDN, elle doit marcher depuis une clé USB en `file://` et se lire dans le
Bloc-notes. Des scripts PowerShell scannent le PC. Le détail des tests et de la publication
est dans [CONTRIBUER.md](CONTRIBUER.md) ; ce qui reste à faire, et pourquoi, dans
[RESTE-A-FAIRE.md](RESTE-A-FAIRE.md). Ce fichier ne dit que ce qui a déjà coûté cher.

**Rien de ce projet n'a jamais tourné sur un Windows réel.** Tout est validé par des tests
sur données écrites à la main et par le job Windows de la CI. Ne jamais écrire « ça marche »
sur un comportement Windows ; écrire ce qui a été vérifié, et par quoi.

## Avant de pousser

- Après toute modification d'`index.html` : `npm run sync`. Sans lui `test-pwa.js` échoue
  (le nom du cache du service worker dérive de la page).
- Rejouer la CI Linux : `./verifier-comme-ci.sh`. Il vise un Chromium précis ; s'il est
  absent, toutes les étapes navigateur échouent en bloc, sans rapport avec le code. Donner le bon :
  `CHROME=$(ls -d /opt/pw-browsers/chromium-*/chrome-linux*/chrome | tail -1) ./verifier-comme-ci.sh`.
  Les suites `.ps1` demandent `pwsh`.
- Un nouveau fichier de test s'enregistre à **trois** endroits : `package.json`,
  `.github/workflows/ci.yml` et `verifier-comme-ci.sh`. Rien ne le vérifie encore : un test
  absent de ces listes ne garde rien.
- Ne jamais lancer `git stash` ni `git checkout` pendant qu'un test tourne en arrière-plan :
  il lit les fichiers vivants et mesure un état qui n'existe pas.

## Un test ne compte qu'après l'avoir vu échouer

Écrire le test, le voir rouge sur le code d'avant, corriger, le voir vert. Un test qui passe
du premier coup est suspect : ce projet a déjà eu des assertions qui ne regardaient rien.
Ne jamais affaiblir une garde pour obtenir du vert — pas de test sauté ou supprimé, pas de
seuil abaissé, pas d'exception ajoutée sans la raison écrite à côté.

## Tout texte visible passe par `tr()`

- La clé est le **texte français lui-même** : `tr('Configuration effacée.')`. Toute clé
  ajoutée a son entrée dans `TRADUCTIONS`, sans quoi la page anglaise retombe sur le français.
- **Des phrases entières, une par cas** : `tr('{0} cases cochées…', n)` et son singulier.
  Jamais `n+' case'+(n>1?'s':'')` : les accords ne se transposent pas d'une langue à l'autre.
- Ça vaut pour tout ce que la page *dit* — `informer`, `memoriserAnnulation`, `dire`,
  `signalerPanne`, un `.textContent` — pas seulement pour ce qu'elle affiche. `test-langue.js`
  lit le code et refuse un texte brut ; `test-anglais.js` déclenche les messages pour de vrai.
- Le contenu d'un profil (noms, descriptions) n'est **pas** de l'interface. `libelleDe` /
  `descDe` rendent le texte d'origine (exports, URL de recherche) ; `libelleAff` / `descAff`
  servent à l'affichage seul. Un export n'est jamais traduit.

## PowerShell et `.bat`

- Tout `.ps1` en UTF-8 **avec BOM** : Windows PowerShell 5.1 lit sinon les accents en page
  de code locale. **`Migration PC.bat` sans BOM** : cmd.exe le lit comme un nom de commande.
  Deux règles opposées, chacune gardée par un test.
- La fonction de traduction s'appelle `Texte`, jamais `Tr` : sous Windows les noms sont
  insensibles à la casse et `tr` est un exécutable Unix, ce que seul le job Windows voit.
- `$x = if (…) {…}` est valide, mais `(if …)` dans une parenthèse ne l'est pas : écrire
  `$(if …)`. `@(0)` est **faux** : tester `$null -ne $x -and $x.Count -gt 0`. Un `+` en
  début de ligne ne continue pas l'expression. `-Include` est ignoré par 5.1 avec
  `-LiteralPath`. `Write-Host` écrit sur le flux 6 : capturer avec `6>&1`.

## Secrets : le nom dans l'inventaire, le secret ailleurs

Un inventaire voyage sur une clé USB. Ne lire que les cinq derniers caractères d'une clé de
produit (`PartialProductKey`), jamais la clé OEM complète. Ne jamais collecter la clé de
récupération BitLocker, les clés Wi-Fi ni les mots de passe de Windows ; la politique est
dans `COUVERTURE.md`. Un profil reçu est une **entrée non fiable**, jamais du code.

## Documentation

Un fait s'écrit à **un seul endroit**. Ne pas écrire de comptes (« vingt-six suites ») : ils
dérivent, et plusieurs l'avaient fait. Quand un lot de `RESTE-A-FAIRE.md` se ferme, le marquer
fait dans la même pull request, avec ce qu'il a révélé de plus que prévu.

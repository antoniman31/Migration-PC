# Règles pour travailler sur ce dépôt

## Règles communes (le même bloc dans tous les dépôts d'Antoni, existants et futurs : le modifier ici, c'est le modifier partout)

Décidées par Antoni le 16/11/2026, mises à jour le 21/11/2026. Les règles propres à ce dépôt suivent ce bloc ; en cas de conflit, ce bloc l'emporte.

- **Avec Antoni** : français, tutoiement, réponses courtes, franches, sans flatterie. Il est seul utilisateur (Galaxy S26 Ultra, PC Windows).
- **Proposer d'abord** : présenter un plan détaillé (étapes, fichiers touchés, approche) et ses propres suggestions d'amélioration, attendre un « ok » explicite avant de toucher quoi que ce soit, ne jamais régénérer un fichier de son propre chef. « Pose des questions » veut dire `AskUserQuestion`, avec des choix concrets et un recommandé. Pour une nouvelle fonctionnalité ou une modification de fonctionnalité ou de design : proposer sans coder, poser des questions si besoin et proposer des visuels (maquette HTML simple sans canvas, ou schéma ASCII).
- **Fusion** : PR en brouillon, fusion par squash **seulement sur le « go » d'Antoni**, CI verte. Jamais de fusion de sa propre initiative, même verte.
- **Branche** : celle que la session impose. Aucun nom de branche n'est écrit dans ce dépôt : l'environnement le change à chaque session.
- **Identité de commit** : `AntoniMan31 <268696974+antoniman31@users.noreply.github.com>`. Jamais l'adresse personnelle d'Antoni : GitHub refuse le push qui l'expose.
- **Noms de modèle** : autorisés (ligne de co-auteur des commits comprise).
- **Secrets** : jamais de clé, de jeton ni de mot de passe dans le dépôt ou la conversation ; ils se saisissent dans l'application ou dans les secrets GitHub/Cloudflare. Jamais d'export de données personnelles ni de `.env` commité.
- **Tests** : le lint et les tests du dépôt passent avant chaque commit. Un test ne compte qu'après l'avoir **vu échouer** sur le code d'avant. Jamais affaiblir un contrôle pour obtenir du vert (test sauté, seuil baissé, exception sans raison écrite).
- **CI, trois niveaux** : *rapide* (lint, tests unitaires, données) à chaque PR ; *lourd* (navigateur, e2e, Windows, compilation Android) seulement si la PR touche autre chose que des `.md`, sinon le job est marqué « sauté », jamais retiré ; *appareil réel* : une PR qui touche l'interface finit par une courte liste « à vérifier sur le S26 ou le PC ». Sur `main`, tout tourne toujours. Une seule CI par PR. Un test qui échoue au hasard a droit à une relance, puis on en cherche la cause.
- **Interface** : de vrais boutons (jamais un `div` cliquable) ; dans une appli utilisée au doigt, **zones tactiles d'au moins 48 px** (48 dp sous Android) ; contraste et focus vérifiés par l'outil du dépôt.
- **Robustesse** : une écriture qui peut échouer (stockage, réseau) se voit à l'écran ; toute donnée venue d'un fichier, du stockage ou du réseau est une entrée non fiable. Exporter les données avant toute opération destructive.
- **Versions et API** : vérifier dans la doc officielle les versions à jour avant d'utiliser une librairie ou une API ; jamais de code déprécié sans le signaler.
- **Contradiction** : si une demande contredit une règle de ce fichier, le signaler avant d'appliquer.
- **Écrit** : commentaires en français qui disent **pourquoi** ; aucun chiffre écrit sans l'avoir mesuré ; ne jamais écrire « ça marche » pour ce qui n'a pas tourné sur l'appareil réel.
- **Suivi, trois fichiers à la racine** : `README.md` dit l'**état actuel** ; `JOURNAL.md` garde l'**histoire** (chaque lot s'y ajoute en fin de fichier, sous `### Titre — jj/mm/aaaa`) ; `RESTE-A-FAIRE.md` dit **ce qui reste**, mis à jour à chaque lot. Un fichier de suivi retiré part en entier dans `JOURNAL.md`, sous « Ancien X.md ».

## Règles propres à ce dépôt

Une checklist de réinstallation Windows, dans **un seul `index.html` autonome** : pas d'étape
de build, pas de CDN, elle doit marcher depuis une clé USB en `file://` et se lire dans le
Bloc-notes. Des scripts PowerShell scannent le PC. Le détail des tests et de la publication
est dans [CONTRIBUER.md](CONTRIBUER.md) ; ce qui reste à faire, et pourquoi, dans
[RESTE-A-FAIRE.md](RESTE-A-FAIRE.md) ; ce qui a été fait, dans [JOURNAL.md](JOURNAL.md). Ce fichier ne dit que ce qui a déjà coûté cher.

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
fait dans la même pull request et déplacer son détail, avec ce qu'il a révélé de plus que prévu,
dans `JOURNAL.md` (même titre).

## Mobile

Le mobile n'est pas un usage de ce projet (`RESTE-A-FAIRE.md`, section 3) : la règle commune des
48 px vaut pour les applis utilisées au doigt, pas pour celle-ci. `test-mobile.js` garde 44 × 24.

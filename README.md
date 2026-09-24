# Migration PC — checklist de réinstallation

Checklist HTML pour réinstaller un PC Windows sans rien oublier. Des scripts PowerShell
inventorient l'ancienne machine, constatent ce qui est déjà en place sur la nouvelle et
vérifient que les sauvegardes ont bien été copiées ; la page orchestre le tout en liste
à cocher, avec un mode guidé pour le jour de l'installation.

`index.html` se suffit à lui-même : aucune dépendance, aucun serveur, aucune étape de
construction. Il s'ouvre depuis une clé USB sur un PC fraîchement installé, sans réseau.
Les scripts sont facultatifs.

![La checklist, onglet Apps](captures/checklist.png)

---

## Sommaire

- [À quoi ça sert](#à-quoi-ça-sert)
- [Le parcours en deux double-clics](#le-parcours-en-deux-double-clics)
- [Démarrage rapide](#démarrage-rapide)
- **Les trois scripts**
  - [Inventorier l'ancien PC](#inventorier-lancien-pc)
  - [Vérifier le nouveau PC](#vérifier-le-nouveau-pc)
  - [Vérifier les sauvegardes](#vérifier-les-sauvegardes)
- [Migration, réinstallation, ou juste ses affaires](#migration-réinstallation-ou-juste-ses-affaires)
  - [Installer Windows sans rester devant](#installer-windows-sans-rester-devant)
- [La checklist](#la-checklist)
  - [La barre du haut](#la-barre-du-haut)
  - [Repartir de zéro](#repartir-de-zéro)
  - [Mode guidé](#mode-guidé)
  - [Accessibilité](#accessibilité)
- [Formats de fichiers](#formats-de-fichiers)
- [Écrire son propre profil](#écrire-son-propre-profil)
- [Vie privée](#vie-privée)
- [Tests](#tests)
  - [Intégration continue](#intégration-continue)
- [Déploiement](#déploiement)
- [Limites connues](#limites-connues)

## À quoi ça sert

Réinstaller un PC, c'est trois problèmes : se souvenir de ce qui était installé, le
réinstaller dans le bon ordre, et ne pas oublier de sauvegarder ce qui n'existe qu'en
local. Ce projet couvre les trois, dans **deux situations** : passer sur une autre
machine, ou repartir propre sur celle qu'on a déjà.

```
Ancien PC                              Nouveau PC
─────────                              ──────────
scan-pc.ps1 ──► inventaire-pc.json ──► index.html ◄── verifier-pc.ps1
                                           ▲              (constate ce qui
verifier-sauvegardes.ps1 ──────────────────┘               est déjà installé)
  (compare les dossiers copiés)
```

Trois scripts, une page. `scan-pc.ps1` inventorie la machine qu'on quitte,
`verifier-pc.ps1` constate ce qui est déjà en place sur celle qu'on installe, et
`verifier-sauvegardes.ps1` vérifie que les dossiers ont bien été copiés. Tous les trois
partagent leur logique de détection, qui vit une seule fois dans `lib-detection.ps1`.

Le scan n'est pas obligatoire : la page s'ouvre sur un profil d'exemple utilisable tel
quel, et vous pouvez écrire le vôtre.

## Le parcours en deux double-clics

Posez le dossier entier sur une clé USB et double-cliquez **`Migration PC.bat`**. Une
fenêtre demande sur quelle machine vous êtes — la seule question à laquelle personne ne
peut répondre à votre place — et lance le bon script. Elle n'ajoute aucune capacité :
elle appelle les mêmes scripts, qu'on peut toujours lancer à la main. Une action dont il
manque un fichier reste affichée, grisée, avec la raison : plus utile qu'une action
absente dont on ignore pourquoi.

Après chaque action, elle dit quoi faire ensuite sur le site — quel onglet, quel bouton.
Et une entrée **Par où commencer ?** décrit le parcours complet des trois situations :
changer de PC, réinstaller sur place, garder les deux machines.

Sans interface graphique — PowerShell 7 sans Windows Desktop, session distante — elle
bascule sur un menu texte qui propose exactement les mêmes choix. `-Console` le force.

Si vous préférez sauter la fenêtre : sur l'ancien PC, double-cliquez
**`1-scanner-ce-pc.bat`** : il inventorie la machine, écrit son résultat à côté de la
page et l'ouvre. La checklist s'affiche **déjà remplie de vos logiciels** — rien à
importer. Vous ajustez, vous exportez votre profil sur la clé.

Sur le nouveau PC, double-cliquez **`2-verifier-ce-pc.bat`** : il regarde ce qui est
déjà installé et rouvre la page, qui vous propose de cocher ce qu'elle a reconnu. La clé
a fait le transport.

Le `.bat` existe pour une seule raison : Windows refuse d'exécuter un `.ps1` par
double-clic. Il appelle le script en contournant ce blocage pour ce seul lancement, et
reste lisible dans le Bloc-notes — contrairement à un `.exe`, qu'il faudrait croire sur
parole pour un outil qui lit tout votre PC.

**Comment la page se remplit toute seule.** Ouverte depuis une clé, elle n'a pas le droit
d'aller lire un fichier : le navigateur refuse. Mais elle peut charger un fichier
JavaScript posé à côté d'elle. Les scripts écrivent donc `resultat-scan.js` en plus du
`.json`, et ouvrir `index.html` suffit. Sans ce fichier, la page s'ouvre normalement.

Ce fichier étant chargé, il est exécuté : sur votre propre clé c'est sans objet, sur une
clé prêtée c'est du code qui tourne. Ce qu'il dépose est traité comme n'importe quel
import — des données, jamais des instructions — et la page annonce d'où ça vient au lieu
d'apparaître pleine sans explication. **⋯ Plus → Les scripts pour Windows** propose les
fichiers au téléchargement, et `-PasDOuverture` empêche les scripts d'ouvrir le
navigateur.

## Démarrage rapide

**Le plus court** : ouvrez `index.html` et cochez. Le profil d'exemple couvre les étapes
communes à toute réinstallation Windows, aucun script n'est nécessaire.

**Le parcours complet**, dans l'ordre :

1. Sur l'**ancien PC**, inventoriez ce qui est installé.

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scan-pc.ps1
   ```

2. Faites vos sauvegardes, puis vérifiez-les.

   ```powershell
   .\verifier-sauvegardes.ps1 -Destination D:\sauvegarde-migration
   ```

3. Copiez le dossier du projet et les deux JSON produits sur une clé USB.

4. Sur le **nouveau PC**, ouvrez `index.html` et importez `inventaire-pc.json`. Passez en
   **🎯 Mode guidé** et suivez les tâches une par une.

5. Après une série d'installations, constatez ce qui est déjà en place plutôt que de
   cocher à la main.

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\verifier-pc.ps1
   ```

   Importez `verification-pc.json` : la page propose, vous validez.

## Inventorier l'ancien PC

`scan-pc.ps1` interroge plusieurs sources et fusionne les résultats :

| Source | Ce qu'elle apporte |
|---|---|
| `winget list` | Les identifiants d'installation officiels |
| Registre `Uninstall` | Les logiciels installés classiquement (32 et 64 bits, machine et utilisateur) |
| Paquets APPX | Les applications du Microsoft Store |
| Steam, Epic, GOG, Xbox | Les jeux installés, sur tous les disques |
| Variables d'environnement | Les variables personnalisées de l'utilisateur |

Une entrée vue par plusieurs sources est fusionnée : le nom vient du registre,
l'identifiant winget de winget, la taille sur disque de celle qui la connaît, et rien
n'apparaît deux fois. Chaque application est classée par catégorie selon des mots-clés,
avec une priorité et une durée estimée — tout cela reste modifiable à la main dans le
JSON.

Les variables d'environnement personnalisées sont relevées et remplissent directement
les champs prévus par la checklist, sans recopie manuelle. Une valeur déjà saisie n'est
jamais écrasée. Seules les variables de l'utilisateur sont lues : celles du système sont
recréées par Windows et les installateurs.

Les redistribuables Visual C++, les mises à jour et les composants système sont écartés
par défaut, sinon la liste dépasse largement ce qu'on réinstalle vraiment.

| Option | Effet |
|---|---|
| `-Sortie <chemin>` | Change le fichier produit (défaut : `inventaire-pc.json`) |
| `-ToutInclure` | Désactive le filtrage, garde tout |
| `-SansStore` | Ignore les applications du Microsoft Store |
| `-SansJeux` | Ignore les bibliothèques de jeux (Steam, Epic, GOG, Xbox) |
| `-SansVariables` | Ne relève pas les variables d'environnement |

Le script n'a pas besoin des droits administrateur, mais sans eux les logiciels
installés par d'autres comptes utilisateurs peuvent manquer. Il n'écrit qu'un fichier
local et n'envoie rien sur le réseau.

## Vérifier le nouveau PC

Installer dix applications puis cocher dix cases à la main est du travail inutile. Sur
la machine fraîchement installée :

```powershell
powershell -ExecutionPolicy Bypass -File .\verifier-pc.ps1
```

Le script détecte ce qui est déjà présent, le rapproche des éléments du profil et écrit
`verification-pc.json`. À l'import, la page affiche la liste avec la raison de chaque
correspondance — identifiant winget, ou nom seul — et **rien n'est coché sans votre
validation** : un rapprochement par nom peut confondre deux logiciels voisins, et une
case cochée à tort fait sauter une installation.

Par défaut, seuls les identifiants winget sont retenus : moins de correspondances,
aucune fausse.

| Option | Effet |
|---|---|
| `-Profil <chemin>` | Le profil à vérifier (par défaut `profil-local.json`, puis l'exemple) |
| `-Sortie <chemin>` | Change le fichier produit (défaut : `verification-pc.json`) |
| `-NomsApproximatifs` | Élargit la recherche aux noms, avec un risque de faux positif |
| `-SansJeux` | Ignore les bibliothèques de jeux |

## Vérifier les sauvegardes

L'onglet Données liste des chemins et on coche en confiance. Ce script compare les deux
côtés :

```powershell
.\verifier-sauvegardes.ps1 -Destination D:\sauvegarde-migration
```

Pour chaque élément qui désigne un vrai dossier, il compte les fichiers et mesure la
taille à la source et dans la copie, puis classe : conforme, écart de taille, incomplet,
copie absente. Un élément qui ne désigne aucun dossier — « Courriels et espaces
clients » — est rapporté comme non vérifiable plutôt que passé sous silence. Un champ
peut porter plusieurs chemins séparés par une virgule ou par « et » : ils sont traités
un par un.

Le rapport produit est aussi une progression : l'importer coche les éléments vérifiés
conformes. `-ToleranceParCent` règle l'écart de taille toléré, 2 % par défaut.

| Option | Effet |
|---|---|
| `-Destination <chemin>` | Le dossier de sauvegarde à comparer (obligatoire) |
| `-Profil <chemin>` | Le profil à vérifier (par défaut `profil-local.json`, puis l'exemple) |
| `-ToleranceParCent <n>` | Écart de taille toléré avant signalement |

## Quatre cas, deux questions

À la première ouverture, la page pose deux questions : ce que vous installez, et ce que
devient l'ancienne machine. Elle règle le cas toute seule et se referme. C'est un
bandeau, pas une porte : la checklist reste lisible derrière, « Passer » l'écarte, et
**⋯ Plus → Adapter à mon cas** le rappelle plus tard. Une page déjà entamée n'est jamais
interrogée.

Quatre cas, un sélecteur en haut de page pour en changer à tout moment. Les deux premiers partagent l'essentiel —
pilotes, applications, sauvegardes — et un élément sans mention vaut pour les deux, ce
qui est la majorité.

Ce qui change en **migration** : le montage est neuf, donc on vérifie le sens des
ventilateurs, et on peut effacer le disque de l'ancienne machine puisqu'on s'en sépare.

Ce qui change en **réinstallation** : le BIOS est déjà réglé, donc ses étapes se lisent
« vérifier que » au lieu d'« activer » — un réglage saute parfois après une mise à jour
du BIOS. Surtout, deux étapes apparaissent, qui n'ont de sens que là. D'abord
**télécharger les pilotes sur une clé USB avant de formater** : si Windows ne reconnaît
pas la carte réseau au premier démarrage, il n'y a pas d'autre machine sous la main pour
aller les chercher. Ensuite un **point de non-retour**, juste avant de lancer
l'installation, qui récapitule ce qui doit être fait *et vérifié* — parce qu'une fois le
disque effacé, cette machine n'est plus une source.

Le filtre vaut partout, pas seulement dans les listes : les compteurs, les boutons
« Tout cocher », la recherche, le mode guidé, la réinitialisation d'une section et
l'export texte s'y tiennent. Cocher en masse n'atteint jamais un élément qu'on n'a pas
sous les yeux, et un intitulé alternatif s'affiche sur les cinq onglets, pas seulement
dans « Nouveau PC ».

**Deux PC** est le cas qu'on oublie : le nouveau PC arrive, mais l'ancien reste en
service — un fixe et un portable. La checklist ne savait que transférer, donc elle
faisait désautoriser Steam, délier les licences et fermer les sessions d'une machine
qu'on rallume le lendemain. Dans ce cas ces quatre étapes disparaissent, trois se
retournent — on ne délie plus ses licences Adobe, on compte combien de postes elles
autorisent — et cinq apparaissent, qui n'existaient nulle part : répartir les dossiers
entre les deux machines avant de synchroniser quoi que ce soit, mettre la
synchronisation en place, vérifier qu'elle marche **dans les deux sens**, se donner une
règle contre les versions divergentes, et harmoniser les réglages. L'onglet lui-même
change de nom : « Sur l'ancien PC » plutôt que « Avant de quitter ».

**Juste mes affaires** fonctionne à l'envers des deux autres. Eux partent de tout et
retirent le peu qui ne les concerne pas ; celui-ci part de rien et ne garde que ce qu'on
lui nomme : les onglets Apps, Données et PWA en entier, plus les étapes marquées
`pilote` dans le profil. Ni BIOS, ni installation de Windows, ni vérifications
matérielles. C'est la vue des soirs où l'on réinstalle ses logiciels et rapatrie ses
dossiers sur une machine déjà en route. Sans cette inversion, les réglages BIOS — qui ne
portent aucune mention, justement parce qu'ils valent pour les deux premiers cas — s'y
retrouveraient aussi.

Un onglet que le cas choisi vide entièrement ne reste pas muet : il dit dans quel cas on
est, et combien d'éléments il compte dans les autres.

Le choix est mémorisé, et une case cochée dans un mode reste cochée dans l'autre : le
filtre change ce que vous regardez, pas ce que vous avez fait. Le total affiché suit le
mode, donc il bouge quand vous basculez.

### Installer Windows sans rester devant

L'étape « Préparer la clé d'installation Windows » renvoie vers le générateur de
[Christoph Schneegans](https://schneegans.de/windows/unattend-generator/). On y coche ce
qu'on veut — langue, fuseau, partitionnement, compte local plutôt qu'un compte
Microsoft, réglages de confidentialité, applications préinstallées à retirer — et il
produit un `autounattend.xml`. Déposé à la racine de la clé, ce fichier répond à votre
place aux questions de l'installation.

Le projet ne génère pas ce fichier lui-même : il contient des réponses propres à une
machine et parfois un mot de passe, il n'a rien à faire dans un dépôt public, et le
générateur en amont est maintenu et couvre bien plus de cas que ce qu'on écrirait ici.
C'est une suggestion, pas une étape obligatoire — une installation cliquée à la main
marche tout aussi bien, elle demande juste d'être présent.

## La checklist

Cinq onglets : **Avant de quitter** l'ancien PC, **Nouveau PC**, **Apps**, **Données** à
sauvegarder, **PWA** (raccourcis web).

Le premier onglet regroupe ce qui se fait sur la machine qu'on abandonne et qui ne se
rattrape pas ensuite : désactiver les licences Adobe et les autres activations liées au
matériel — désinstaller ou formater ne désactive rien —, transférer l'application
d'authentification et sortir les codes de récupération, noter la clé BitLocker, vérifier
que les sauvegardes sont restaurables, désautoriser Steam et iTunes, et effacer le
disque en sécurité si la machine est cédée. Les trois groupes sont classés par ce qu'on
risque : irréversible, pénible à rattraper, confort.

L'onglet Nouveau PC suit l'ordre réel d'une installation, et commence avant Windows :
les réglages du BIOS — TPM 2.0 et Secure Boot, qui conditionnent l'installation de
Windows 11, désactivation du CSM, profil XMP/EXPO, Resizable BAR, virtualisation — puis
l'installation elle-même, le système, les pilotes, et enfin les vérifications
matérielles. Chaque étape dit pourquoi elle existe et ce qu'on risque à l'oublier.

L'onglet Données couvre aussi ce qu'on découvre trop tard : les codes de récupération
2FA, la clé BitLocker, les profils Wi-Fi exportables avec
`netsh wlan export profile key=clear`, le Gestionnaire d'identification Windows et les
archives mail locales.

La progression est enregistrée dans le navigateur au fur et à mesure et peut être
exportée en JSON pour passer d'une machine à l'autre.

**Navigation** — mode normal ou compact, thème clair/sombre suivant les préférences
système, recherche sur les quatre onglets à la fois, tri des apps par catégorie,
priorité, durée ou ordre conseillé, filtre sur les apps sans winget. La mise en page
s'adapte aux écrans étroits : cibles tactiles agrandies, textes relevés, champs à 16 px
pour éviter le zoom automatique d'iOS.

**S'installer comme une application** — depuis la version en ligne, la page s'installe
et s'ouvre ensuite sans réseau. Le service worker ne met en cache que le
squelette ; la progression vit dans le stockage local et n'est jamais affectée. Ouverte
en `file://` depuis une clé USB, la page ignore simplement cette partie : elle est déjà
autonome.

**Réinstaller** — le badge winget copie la commande d'installation en un clic, un
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

**Sortie** — export de la progression, du profil, de la checklist en texte, du script
winget restant ou du fichier `winget import`, et impression globale ou par onglet. Tout
ce qui sort suit le scénario choisi et ses intitulés : un fichier qui dirait autre chose
que l'écran serait pire que pas de fichier.

### Ma configuration

Les scripts relèvent le matériel et remplissent ces champs tout seuls : Windows connaît
la machine, il n'y a pas de raison de recopier une étiquette de carton. Une valeur déjà
saisie n'est jamais écrasée — elle est peut-être plus précise que ce que Windows
rapporte, et c'est la personne qui a raison.

**⋯ Plus → Ma configuration** ouvre les mêmes cinq champs à remplir à la main : carte
mère, processeur, carte graphique, mémoire, SSD. Ce qu'on y écrit fait deux choses. Les intitulés des pilotes
portent le modèle — « Pilote chipset — ASUS B850-A » — là où ils disaient « de la carte
mère », et seulement ceux-là : « Désactiver le CSM » n'a que faire d'un numéro de
modèle. Et les boutons « Rechercher » visent le support du constructeur au lieu des mots
génériques de l'intitulé.

**Les périphériques sans pilote** sont listés à part, après une vérification du nouveau
PC. Ce n'est pas une déduction : c'est ce que le gestionnaire de périphériques affiche
avec un point d'exclamation, repris tel quel. Chaque ligne porte un bouton de recherche
qui cite le modèle de votre carte mère, puisque c'est elle qui porte le réseau, l'audio
et les contrôleurs.

Ce que ce bloc ne fait pas, volontairement : deviner quel pilote va avec quel modèle.
Il faudrait une table de correspondances que personne ne tient à jour, et on servirait
des liens faux qui ont l'air vrais. La page amène au bon endroit ; c'est vous qui lisez
la page du constructeur.

Tout est facultatif, reste dans ce navigateur, et le champ `comp` du profil décide à
quel composant une étape se rattache.

**Si l'enregistrement échoue** — le stockage du navigateur a un quota, et il peut
être refusé en navigation privée ou sur un site bloqué. La barre « Récent » porte à
droite l'état de la sauvegarde : l'heure du dernier enregistrement, ou un avertissement.
Quand le navigateur refuse, un panneau le dit et renvoie vers « Sauvegarder », plutôt
que de laisser croire que le travail est gardé — il resterait à l'écran et partirait au
rechargement.

**En cas de problème** — chaque onglet est rendu séparément. Si l'un échoue, les autres
s'affichent quand même et un bandeau nomme l'onglet fautif et l'erreur, au lieu de
laisser une page à moitié vide sans explication.

**Revenir en arrière** — réinitialiser une section ou importer un fichier remplace du
travail. Ces actions ne demandent pas de confirmation — on clique « oui » par réflexe —
mais s'annulent après coup depuis un bandeau, qui restaure aussi bien les cases que le
profil remplacé et le scénario choisi.

### La barre du haut

Sept boutons, pas dix. Les actions fréquentes restent visibles — vue normale ou compacte,
importer, sauvegarder, mode guidé, thème — et les cinq rares (commencer une session,
exporter le profil, réinitialiser, exporter en texte, imprimer) vivent dans un menu
**⋯ Plus**. Elles y
portent un vrai libellé au lieu d'un emoji qu'il fallait survoler pour comprendre. Le
menu se referme après une action, au clic ailleurs, et à Échap.

### Repartir de zéro

**⋯ Plus → Réinitialiser…** ouvre un panneau avec deux portées distinctes, décrites
avant d'être offertes :

- **Tout décocher** remet la progression à zéro sur les cinq onglets. Les notes, les clés
  de licence, les variables d'environnement et le profil chargé restent en place. C'est
  ce qu'on veut pour recommencer la même migration sur une autre machine.
- **Tout effacer** vide tout ce que le navigateur a mémorisé — progression, notes, clés,
  variables, profil importé — et revient au profil d'exemple. Les fichiers déjà exportés
  ne sont pas touchés : ils sont sur le disque, pas dans la page.

Les deux passent par le même bandeau d'annulation que le reste du site plutôt que par une
boîte de confirmation. Une seconde chance après coup vaut mieux qu'un « oui » réflexe
avant. Échap referme le panneau et rend le focus au bouton qui l'a ouvert.

### Mode guidé

Pour le moment où l'on est debout devant la machine. Une tâche à la fois, dans l'ordre
des dépendances, avec seulement ce qui sert alors : la commande winget prête à copier et
l'avertissement s'il y en a un. Filtres, badges, durées et recherche disparaissent — ils
appartiennent à la préparation.

« C'est fait » coche et avance. « Passer » remet la tâche en fin de file sans la cocher.
Un bouton fait l'aller et le retour avec la vue liste, qui reste le défaut ; la
progression est la même des deux côtés.

![Le mode guidé](captures/mode-guide.png)

### Accessibilité

Tout se fait au clavier : les lignes sont des cases à cocher, atteintes par tabulation
et activées par Entrée ou Espace, et le focus reste sur la ligne après la coche. L'anneau
de focus est visible partout (`:focus-visible`), les lignes portent `role="checkbox"` et
`aria-checked`, les onglets `role="tab"`, et la page a des repères `header` et `main`.

Les contrastes respectent le seuil WCAG de 4,5:1 dans les deux thèmes, mesurés sur le
fond réellement peint. Le bleu de l'interface est décliné en trois rôles : `--acc` pour
les aplats et bordures, `--acc-fort` pour le texte et le focus, `--acc-fond` pour les
fonds bleus portant du texte blanc — `#5493FF` seul n'atteint que 3,00:1 et ne peut pas
porter de texte.

Le réglage système « réduire les animations » est respecté : transitions et animations
sont coupées, confettis compris.

## Formats de fichiers

Le bouton **Importer** accepte cinq formats et les reconnaît tout seul, sans que vous
ayez à dire lequel.

**Vérification de PC** — produite par `verifier-pc.ps1`, reconnue à son champ `type`.
Seul format qui ne s'applique pas directement : la page affiche la liste et attend
confirmation.

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
  "variables": { "JAVA_HOME": "C:\\Program Files\\Java\\jdk-21" }
}
```

**Profil** — les listes des quatre onglets. C'est le format de `presets/exemple.json`,
et celui que produit le bouton 🧩.

**Progression** — les cases cochées, les notes et les dates, sans les listes. C'est ce
que produit le bouton 💾, et aussi le rapport de `verifier-sauvegardes.ps1`, qui est une
progression enrichie du détail de la comparaison : importé, il coche les éléments
vérifiés conformes.

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
cats   // { clé: libellé } — les catégories de l'onglet Apps
quitter // { id, n, p, note, pr, warn? } — facultatif, sur l'ancien PC
npc    // { id, o, n, src, p, t, d, post?, dep?, warn? }
apps   // { id, n, c, src, w?, p, t, d, dep?, warn? }
data   // { id, n, p, note, pr, lic?, env? }
pwa    // { id, n, u, d }
ordre  // [ id, ... ] — l'ordre d'installation conseillé
requetes // { "Nom de l'app": "requête de recherche" }
```

`p` et `pr` valent `high`, `med` ou `ok` · `t` est une durée en minutes · `o` est le
numéro d'étape · `post: true` classe l'étape dans les vérifications d'après-installation
· `w` est l'identifiant winget · `warn` affiche un avertissement.

La section `quitter` est facultative : un profil qui ne la déclare pas affiche quatre
onglets, comme avant.

`cas` limite un élément à une situation : `["migration"]` ou `["reinstall"]`. Sans ce
champ, il vaut pour les deux. `pilote: true` marque une étape de l'onglet Nouveau PC
comme relevant des pilotes : c'est la seule chose que le cas « juste mes affaires »
garde de cet onglet. Un profil qui n'en marque aucune y verra l'onglet vide, avec un
message qui le dit. `alt` fournit un libellé et une description de
remplacement en réinstallation — `{ "n": "Vérifier que...", "d": "..." }` — ce qui évite
de dupliquer une étape et ses dépendances pour changer un verbe.

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

### Un profil reçu est une entrée non fiable

Le projet est fait pour qu'on s'échange des profils, donc un profil vient souvent d'un
fichier qu'on n'a pas écrit. La page le traite comme une saisie quelconque : tout ce
qu'il contient est échappé avant d'atteindre la page, et l'adresse d'un raccourci n'est
ouverte que si c'est du `http`, `https` ou `mailto` — un `javascript:` devient un bouton
visiblement inerte plutôt qu'un lien qui exécute du code. Ce qui est en jeu n'est pas
théorique : le stockage local contient les clés de licence saisies dans l'onglet
Données. `tests/test-profil-hostile.js` rejoue un profil piégé à chaque publication.

## Tests

```bash
npm install                       # une seule fois
npm test                          # les cinq suites sans navigateur, en 2 s
npm run test:scan                 # les cinq suites PowerShell
npm run test:navigateur           # rendu réel dans Chromium
npm run test:verification         # import d'une vérification de PC
npm run test:pwa                  # installabilité et fonctionnement hors ligne
npm run test:mobile               # ergonomie tactile
npm run test:a11y                 # accessibilité et réversibilité
npm run test:guide                # mode guidé
npm run test:quitter              # onglet « Avant de quitter »
npm run test:scenarios            # migration ou réinstallation
npm run test:reinit               # remises à zéro et leur annulation
npm run test:menu                 # menu « Plus » de la barre du haut
npm run test:hostile              # profil piégé : aucune injection
npm run test:sauvegarde           # aucun échec d'enregistrement silencieux
npm run test:debut                # deux questions d'ouverture et second PC
npm run test:config               # bloc configuration et affichage grand écran
npm run test:outils               # scripts proposés et chargement automatique
```

`npm test` ne lance que ce qui tourne partout sans rien installer. Les suites
navigateur demandent Chromium (`npm install` le fournit via Playwright), les suites
PowerShell demandent `pwsh`.

Vingt-cinq suites, dans l'ordre où la CI les lance.

`tests/test-profil-sync.js` garantit que le profil embarqué dans `index.html` et
`presets/exemple.json` ne divergent pas, et vérifie les invariants du profil :
identifiants uniques sur les quatre onglets, priorités valides, catégories déclarées,
ordre conseillé ne citant que des éléments existants. Il contrôle aussi que les fichiers
dont les tests dépendent sont bien versionnés, et qu'aucune fonction n'est définie deux
fois dans `index.html` — une redéfinition écrase silencieusement la première et ce piège
a coûté trois bugs au projet.

`tests/test-checklist.js` extrait le JS de `index.html` et l'exécute dans un DOM simulé.
Il rejoue l'import d'un inventaire réellement produit par le scanner
(`tests/inventaire-exemple.json`), ce qui couvre la chaîne de bout en bout.

`tests/test-scan.ps1` et `tests/test-verification.ps1` couvrent le classement, la fusion
entre sources, le parsing de la sortie winget et le rapprochement avec le profil, sans
toucher à la machine.

`tests/test-sauvegardes.ps1` **exécute réellement** `verifier-sauvegardes.ps1` sur une
arborescence construite pour l'occasion — copie fidèle, copie tronquée, copie vide,
source absente, chemins multiples — et constate son verdict. C'est le seul script
PowerShell du projet qui tourne hors Windows, puisqu'il ne lit que des fichiers.

`tests/test-navigateur.js` charge la page dans un vrai Chromium et vérifie ce qu'un DOM
simulé ne voit pas : que les quatre panneaux sont bien frères et non imbriqués, que les
éléments ont une taille non nulle, que la saisie des clés de licence survit à un
rechargement, et qu'une exception pendant un rendu s'affiche au lieu de disparaître.
Deux variables d'environnement facultatives : `CHROME` pour pointer un binaire Chromium
existant, `PROFIL` pour tester votre propre profil à la place de l'exemple (par défaut
il cherche `profil-local.json` à la racine).

`tests/test-pwa.js` sert le dépôt en HTTP local — un service worker ne s'enregistre pas
en `file://` — et vérifie que la page s'installe, se met en cache et s'ouvre réseau
coupé, tout en restant fonctionnelle en `file://`.

`tests/test-mobile.js` ouvre la page à la largeur de deux téléphones, dans les deux
thèmes, et mesure les cibles tactiles, les écarts entre elles, les tailles de texte et
les débordements horizontaux. Par défaut il rapporte ; `STRICT=1` le fait échouer, ce
que la CI utilise.

`tests/test-accessibilite.js` calcule le contraste de chaque texte sur le fond
réellement peint dans les deux thèmes, parcourt la page au clavier jusqu'à cocher une
tâche, vérifie les rôles et états annoncés, l'annulation des actions destructrices et le
respect du mouvement réduit.

`tests/test-guide.js` couvre le mode guidé : ce qui doit rester visible, ce qui doit
disparaître, le parcours d'une tâche à l'autre, la copie de la commande dans le
presse-papier, et le fait que ce mode tient les mêmes exigences de contraste, de cible
tactile et de clavier que la vue liste.

`tests/test-reinit.js` couvre les deux remises à zéro : que « Tout décocher » ne touche
ni aux notes, ni aux clés, ni au profil, que « Tout effacer » vide bien les trois clés du
navigateur et que rien ne revient après un rechargement, et que l'annulation rend dans
les deux cas ce qui avait été effacé — profil importé et scénario compris. Il mesure
aussi le panneau à 360 px de large, dans les deux thèmes.

`tests/test-menu.js` compte les boutons restés dans la barre, vérifie qu'aucun n'y est
réduit à une icône muette, que les cinq actions du menu agissent réellement (la session
démarre, le profil se télécharge, l'export texte porte les intitulés du scénario courant
et rien de l'autre), que le menu se referme par les trois chemins attendus et qu'il reste
utilisable au clavier comme au doigt.

`tests/test-profil-hostile.js` charge un profil piégé sur quinze champs — nom de
catégorie, identifiant winget, adresse de raccourci, intitulés, descriptions, chemins —
puis clique tout ce qui est cliquable dans les deux cas et en mode guidé. Il échoue si
une seule charge s'exécute.

`tests/test-sauvegarde.js` fait refuser l'écriture par le stockage et vérifie que la
page le dit : l'indicateur passe à « non enregistré », un panneau explique quoi faire,
l'alarme ne se répète pas à chaque case, et tout revient à la normale quand
l'enregistrement remarche.

`tests/test-debut.js` couvre les deux questions et le cas qu'elles servent surtout à
faire connaître : que le bandeau se propose sans barrer la page, ne revient pas une fois
répondu, se rappelle depuis le menu, et qu'en mode « deux PC » on ne désautorise plus
rien sur une machine encore en service — tout en revérifiant qu'en migration les étapes
d'origine reviennent intactes.

`tests/test-config.js` vérifie que les composants saisis précisent les intitulés des
pilotes — et seulement ceux-là, pas « Désactiver le CSM » —, que les recherches visent
le support du constructeur, qu'un profil ne déclarant aucun composant s'affiche
normalement, et que l'élargissement sur grand écran ne change rien au téléphone ni à la
tablette.

`tests/test-outils.js` reconstitue une clé USB — la page plus le fichier qu'un scanner y
dépose — et vérifie que la page s'ouvre déjà remplie, qu'elle dit d'où viennent les
données, qu'un rechargement n'écrase pas le travail fait depuis, et qu'une clé sans ce
fichier ou avec un fichier abîmé s'ouvre normalement. Il contrôle aussi que chaque
fichier proposé au téléchargement existe réellement dans le dépôt.

`tests/test-lanceur.ps1` couvre ce que le lanceur propose et ce qu'il vérifie avant : que
chaque action mène à un fichier qui existe, qu'un dossier incomplet grise les actions
concernées en nommant ce qui manque, et que les `.bat` portent bien des fins de ligne
Windows — en fins de ligne Unix, ils ne s'exécutent pas. L'interface graphique elle-même
n'est pas testée ici : `System.Windows.Forms` n'existe pas hors de Windows Desktop. C'est
pourquoi la liste des actions vit dans `lanceur-actions.ps1`, séparée de l'affichage :
c'est elle qui décide de tout, et elle se teste partout.

`tests/test-powershell-compatibility.ps1` garde un piège fermé : Windows PowerShell 5.1 —
celui livré avec Windows, et celui qu'on obtient par double-clic — lit un `.ps1` sans
marqueur d'encodage comme de l'ANSI et non de l'UTF-8. « Clés SSH » y devient
« ClÃ©s SSH », et ce texte part dans le JSON de l'inventaire, donc dans la page. Le test
vérifie que chaque script porte le marqueur, que tous parsent, et que les noms accentués
de la table des configurations arrivent intacts.

### Intégration continue

`.github/workflows/ci.yml` lance les vingt-cinq suites à chaque push et sur chaque pull
request. La publication sur GitHub Pages dépend de ce job : un test rouge, et rien n'est
mis en ligne.

Ce garde-fou suppose que Pages publie par le workflow et non par la branche — voir
[Déploiement](#déploiement).

## Déploiement

```
Migration-PC/
├── index.html                    # la checklist (tout est dedans)
├── lib-detection.ps1             # détection partagée par les trois scripts
├── scan-pc.ps1                   # inventorie l'ancien PC
├── verifier-pc.ps1               # constate ce qui est déjà sur le nouveau
├── verifier-sauvegardes.ps1      # compare les dossiers copiés
├── manifest.json, sw.js, icons/  # installation et fonctionnement hors ligne
├── presets/exemple.json          # profil d'exemple, aussi embarqué dans index.html
├── scripts-sync.js               # recopie le profil d'exemple dans index.html
├── captures/                     # images du README
├── tests/                        # suites Node, PowerShell et navigateur
├── package.json                  # scripts de test uniquement
└── .github/workflows/ci.yml      # tests, puis publication si tout est vert
```

Les trois scripts PowerShell ont besoin de `lib-detection.ps1` à côté d'eux : copiez le
dossier, pas un fichier isolé.

`package.json` ne sert qu'aux tests : `index.html` n'a aucune dépendance et n'a jamais
besoin d'être construit.

Les fichiers personnels sont exclus par `.gitignore`, à la racine seulement :
`profil-*.json`, `inventaire-*.json`, `progression-*.json`, `winget-*.json` et
`winget-*.ps1`. Gardez les vôtres en local, hors du dépôt — les fichiers d'exemple de
`tests/` et `presets/` ne sont pas concernés.

Le dépôt se publie sur GitHub Pages par le workflow, pas par la branche : réglez
**Settings → Pages → Source : GitHub Actions**. Sur « Deploy from a branch », GitHub
publierait la branche en parallèle et un push dont les tests échouent partirait quand
même en ligne.

```bash
git clone https://github.com/antoniman31/Migration-PC.git
cd Migration-PC
npm install && npm test
```

URL publiée : `https://antoniman31.github.io/Migration-PC`

## Limites connues

Les trois scripts sont **Windows uniquement** et demandent PowerShell 5.1 ou supérieur.
S'ils refusent de démarrer, lancez-les avec `-ExecutionPolicy Bypass`. Ils ont besoin de
`lib-detection.ps1` à côté d'eux.

**La détection n'a pas encore été exécutée sur une machine Windows réelle.** Le
classement, la fusion entre sources, le parsing de la sortie winget et le rapprochement
avec le profil sont couverts par des tests sur données simulées, et
`verifier-sauvegardes.ps1` est réellement exécuté par sa suite. Mais la lecture du
registre, des paquets du Store et des bibliothèques de jeux demande Windows : ce code
est relu, pas éprouvé. Si un résultat vous paraît faux, c'est probablement là.

**Tous les logiciels n'ont pas d'identifiant winget.** Ceux détectés par le registre
seul sortent sans commande d'installation : la checklist les affiche avec un lien de
recherche à la place. Le filtre « Sans winget » permet de les isoler, et ils
n'apparaissent pas dans l'export `winget .json`, qui ne peut contenir que des paquets
connus de winget.

**Un export winget importé perd les noms d'origine.** Le format ne stocke que les
identifiants ; `7zip.7zip` donne « 7zip » et non « 7-Zip ». Passer par `scan-pc.ps1`
donne des noms corrects, puisqu'il lit le registre.

**Ce que le projet ne fera pas : déménager vos applications.** Les outils commerciaux
comme PCmover copient les fichiers de programme *et* les clés de registre *et* les
composants partagés, en réécrivant au passage des milliers de références qui changent
d'une machine à l'autre. Windows n'a jamais été conçu pour ça, les applications du Store
ne se copient pas, les licences liées au matériel se désactivent, et on déménagerait
aussi les restes accumulés depuis cinq ans. Une réinstallation propre par winget, plus
les réglages repérés par le scan, couvre l'essentiel sans rien greffer qu'on ne comprenne.

**La déduplication est approximative.** Elle compare les noms en ignorant la version,
les numéros de mise à jour et les mentions entre parenthèses, ce qui rapproche
correctement `Mozilla Firefox (x64 fr)` du registre et `Mozilla Firefox` de winget, ou
`Java 8 Update 401` et `Java 8 Update 411`. Elle fusionne en revanche deux versions
majeures d'un même logiciel — Python 3.12 et 3.13 donnent une seule ligne. La
ponctuation qui porte le nom est transcrite plutôt qu'effacée, sinon `Notepad++` et
`Notepad` donneraient la même clé et l'un des deux disparaîtrait de l'inventaire.

**Le classement par catégorie est indicatif**, fondé sur des mots-clés. Un logiciel peu
connu atterrit dans « Utilitaires Système ». Les catégories se corrigent dans le JSON.

**Les dossiers de configuration sont repérés, pas devinés.** Le scanner connaît une
table d'emplacements — celui de VS Code, de Notepad++, de Firefox, d'OBS, d'une trentaine
de logiciels courants — et ne retient que ceux qui existent réellement, pour un logiciel
réellement installé. Le dossier d'un logiciel désinstallé n'est pas proposé : ce sont des
restes, pas une configuration à emporter. La table est forcément incomplète et s'allonge
d'une ligne ; ce qu'elle ignore reste à lister à la main, comme avant.

**Les étapes « Nouveau PC », « Données » et « PWA » ne sont pas scannées** : un
inventaire importé reprend celles du profil d'exemple, à adapter à votre matériel. Un
scan ne peut pas deviner qu'il faut activer le profil XMP dans le BIOS. Les variables
d'environnement font exception : elles sont relevées et reportées automatiquement.

**Les tailles sur disque sont partielles.** Steam et Epic les donnent exactement, le
registre les estime — et se trompe parfois largement —, le Microsoft Store, GOG et Xbox
ne les donnent pas du tout. Le total affiché est donc un minimum, utile pour dimensionner
un disque, pas un inventaire comptable.

**L'installation sur l'appareil demande HTTPS.** Un service worker ne s'enregistre pas
depuis un fichier ouvert directement : depuis une clé USB, la page fonctionne mais ne
s'installe pas et n'a pas de cache. Elle n'en a pas besoin, tout est dans le fichier.

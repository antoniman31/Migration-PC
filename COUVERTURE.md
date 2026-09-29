# Ce que le scan sait détecter, et ce qu'il ne sait pas

Ce fichier a servi longtemps à suivre l'écart entre ce que la checklist
promettait et ce que les scripts savaient réellement aller chercher. Il sert
maintenant surtout à tenir une frontière : le projet répond à deux questions,
et à deux seulement.

1. Quels logiciels sont installés sur le PC source, et lesquels manquent
   encore sur le PC cible ?
2. Quels pilotes sont en place, lesquels manquent, et où les chercher ?

Les noms de famille utilisés ici sont ceux de `$CouverturesScan`, dans
`lib-detection.ps1`, et `tests/test-profil-sync.js` refuse toute ligne qui
déclare une couverture inconnue.

## Couvert

| Famille | Détecteur | Réserve |
|---|---|---|
| `apps` | `Read-Registre`, `Read-Winget`, `Read-Store` | — |
| `jeux` | `Read-Steam`, `Read-Epic`, `Read-GOG`, `Read-Xbox`, `Read-Ubisoft`, `Read-Ea` | — |
| `materiel` | `Read-Materiel` | Carte mère, processeur, cartes, barrettes, disques |
| `machine` | `Read-Machine` | Fabricant, modèle, n° de série, portable ou fixe, écrans branchés |
| `pilotesTiers` | `Read-PilotesTiers` | Les fournisseurs qui ne sont pas Microsoft, groupés par classe |

Et, sur la machine d'arrivée seulement, `Read-PilotesManquants` : les
périphériques que Windows signale comme sans pilote ou en erreur.

### Ce que le volet pilotes ne prétend pas faire

Il ne dit **jamais** « une version plus récente existe ». Le programme ne fait
aucun appel réseau : il ne peut pas le savoir, et l'affirmer serait mentir. Ce
qu'il fait : signaler les périphériques sans pilote ou en erreur, distinguer un
pilote du constructeur d'un pilote générique Microsoft, et fabriquer le lien
vers la page de support du constructeur à partir du modèle et du numéro de
série relevés dans le SMBIOS. C'est à l'utilisateur d'y comparer les versions.

## Hors périmètre

Ce tableau a compté jusqu'à **trente-deux** familles. Vingt-sept ont été
retirées d'un coup, volontairement. Elles marchaient, elles étaient testées, et
elles ont coûté du travail — mais elles faisaient du projet autre chose que ce
qu'il devait être, et surtout elles **promettaient sans tenir** : le programme
listait des favoris, des polices, des règles de pare-feu et des archives mail
sans jamais rien copier. Une liste de ce qu'on va perdre n'est pas une
sauvegarde.

Retirées : `configs`, `variables`, `licences`, `payants`, `vpn`, `favoris`,
`vm`, `mail`, `bitlocker`, `antivirus`, `compte`, `imprimantes`, `wifi`,
`identifiants`, `polices`, `lecteurs`, `demarrage`, `taches`, `pareFeu`,
`associations`, `controles`, `outils`, `extensions`, `dossiers`, `precieux`,
`portables`, `web`.

Leur code vit dans l'historique git. **Qu'aucune ne revienne sans une raison
nommée** : « c'était détectable » n'en est pas une, et c'est exactement le
raisonnement qui avait produit les trente-deux.

Trois d'entre elles s'arrêtaient **volontairement** avant la fin, et ça
mérite de rester écrit même si le code est parti : la clé de récupération
BitLocker, les clés Wi-Fi et les mots de passe enregistrés dans Windows
n'étaient jamais relevés. Ils sont lisibles, la commande existe, et c'est
précisément pour ça qu'il fallait écrire qu'on ne le faisait pas : un
inventaire voyage sur une clé USB.

## Hors de portée

Ces points ne sont pas des oublis : ils ne sont pas récupérables par un script
honnête, ou pas transférables du tout.

| Point | Pourquoi |
|---|---|
| Vos fichiers personnels | Ce programme ne sauvegarde rien. Il liste des logiciels. Photos, documents et projets restent entièrement à votre charge, et c'est le seul geste irréversible de la procédure. |
| Mots de passe enregistrés dans les navigateurs | Chiffrés par DPAPI avec une clé liée au compte **et** à la machine. Les déchiffrer demanderait d'imiter un voleur de mots de passe. |
| Sessions ouvertes dans les applications | Les jetons d'authentification sont liés à la machine. Il faudra se reconnecter partout, c'est normal. |
| Activations liées au matériel | Certaines licences comptent les machines activées. Désactiver **avant** de démonter l'ancien PC. |
| Données vivant chez l'éditeur | Ce qui est dans le cloud n'est pas sur le disque : rien à scanner, rien à copier. |
| État interne des applications du Store | Le bac à sable de `WindowsApps` n'est pas lisible depuis l'extérieur. |
| Quelle version de pilote est la plus récente | Demanderait un appel réseau. Le programme n'en fait aucun. |

## Chiffres

| | Au plus large | Maintenant |
|---|---|---|
| Familles couvertes | 32 | 5 |
| Scripts PowerShell | 8 | 5 |
| Onglets de la page | 6 | 3 |

Les trois onglets restants sont **Logiciels**, **Pilotes** et **PWA**. « Avant de
quitter » et « Nouveau PC » sont partis : le premier listait des gestes de compte et de
données, le second des consignes d'installation de Windows qu'on trouve partout et que
ce programme ne savait pas vérifier. « Reste à faire » a fondu dans « Logiciels », parce
que la liste des logiciels et la liste de ce qui manque parlent des mêmes lignes.

Rien de ce qui est décrit ici n'a été exécuté sur un vrai PC : c'est validé par
les tests et par le job Windows de la CI, qui vérifient que le code fait ce
qu'il dit, pas que Windows réponde ce qu'on croit.

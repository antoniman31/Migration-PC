# Ce que le scan sait détecter, et ce qu'il ne sait pas

Ce fichier existe parce que l'écart entre ce que la checklist propose et ce que
les scripts savent réellement aller chercher sur l'ancien PC s'était creusé sans
que personne ne le suive. Il est la référence : si une ligne de la checklist
prétend être remplie par un scan, elle doit apparaître ici comme couverte.

Le champ `scan` de chaque entrée `data` dans `presets/exemple.json` renvoie à ce
tableau, et `tests/test-profil-sync.js` refuse toute ligne qui déclare une
couverture inconnue. Les noms de famille utilisés ici sont ceux de
`$CouverturesScan`, dans `lib-detection.ps1`.

## Couvert

| Famille | Détecteur | Réserve |
|---|---|---|
| `apps` | `Read-Registre`, `Read-Winget`, `Read-Store` | — |
| `jeux` | `Read-Steam`, `Read-Epic`, `Read-GOG`, `Read-Xbox`, `Read-Ubisoft`, `Read-Ea` | — |
| `configs` | `Read-Configs` | **partiel**, voir plus bas |
| `variables` | `Read-Variables` | — |
| `materiel` | `Read-Materiel` | — |
| `outils` | `Read-SdkAndroid`, `Read-Wsl`, `Read-GestionnairesPaquets`, `Read-OutilsLangages` | scoop, Chocolatey, npm, pip seulement |
| `extensions` | `Read-Extensions` | VS Code, Chromium, Firefox |
| `dossiers` | `Read-GrosDossiers` | — |
| `precieux` | `Read-FichiersPrecieux` | — |
| `portables` | `Read-Portables` | — |
| `web` | `Read-Registre` (applications web du navigateur) | — |

### Pourquoi `configs` n'est que partiel

Deux trous connus, tous les deux silencieux — rien n'échoue visiblement :

1. **Le registre n'est pas lu.** `$ConfigsConnues` n'a qu'un champ `chemins`.
   Or PuTTY range ses sessions SSH entièrement dans
   `HKCU\Software\SimonTatham`, sans le moindre fichier. Même chose pour 7-Zip,
   WinRAR, WinZip et TeamViewer.
2. **Les fichiers verrouillés échouent.** `sauvegarder-configs.ps1` copie avec
   `Copy-Item`. Si Firefox ou Thunderbird tourne pendant la sauvegarde,
   `places.sqlite`, `cookies.sqlite` et `key4.db` sont verrouillés — c'est-à-dire
   précisément les marque-pages et les mots de passe.

## Détectable, pas encore fait

Ces lignes existent dans la checklist et portent un `scan: attendu:<famille>`
ou sont encore marquées `manuel` faute de détecteur.

| Famille | Méthode connue |
|---|---|
| `imprimantes` | `Win32_Printer` |
| `wifi` | `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\Profiles` pour la liste ; `netsh wlan export profile key=clear` pour les clés |
| `identifiants` | `cmdkey /list` donne les noms, jamais les secrets |
| `polices` | clé `Fonts` du registre + `%LOCALAPPDATA%\Microsoft\Windows\Fonts` |
| `vpn` | pas de méthode arrêtée |
| `vm` | pas de méthode arrêtée |
| `mail` | pas de méthode arrêtée |
| `favoris` | pas de méthode arrêtée |
| `bitlocker` | pas de méthode arrêtée |
| `lecteurs-reseau` | pas de méthode arrêtée |
| `pare-feu` | pas de méthode arrêtée |
| `demarrage` | pas de méthode arrêtée |
| `taches` | pas de méthode arrêtée |
| `associations` | pas de méthode arrêtée |

## Repéré en relisant d'autres inventaires, pas encore fait

Rien de tout cela n'était sur une liste avant de comparer notre scan à GLPI
Agent, OCS Inventory, UniGetUI, hellzerg/cloning et
Kozphy/installed-software-inventory.

| Famille | Méthode | Pourquoi ça compte pour une migration |
|---|---|---|
| `licence-windows` | `SoftwareLicensingProduct` → `ProductKeyChannel` | Une licence OEM est attachée à la carte mère et **ne suit pas** le déménagement ; une Retail suit. Idem Office. |
| `liens` | `URLInfoAbout` et `HelpLink` au registre | L'adresse officielle de l'éditeur est déjà sur le disque : pas besoin d'Internet pour la retrouver. |
| `date-installation` | `InstallDate` au registre | Permet de dire « ce logiciel n'a pas servi depuis trois ans ». |
| `ecrans` | `WmiMonitorID` (`root\wmi`) | Combien de sorties vidéo prévoir sur le nouveau PC. |
| `antivirus` | `AntiVirusProduct` (`root\SecurityCenter2`) | Un antivirus tiers payant a une licence à transférer. |
| `compte-microsoft` | `HKLM\SOFTWARE\Microsoft\IdentityStore\Cache\<SID>\IdentityCache\<SID>\UserName` | Avec quel compte ouvrir la session sur le nouveau PC. |
| `machine` | `Win32_ComputerSystem`, `Win32_BIOS` | Fabricant, modèle, numéro de série de l'ancien PC. |
| `chassis` | `Win32_SystemEnclosure` | Portable ou fixe : change ce qu'on conseille. |
| `pilotes` | `Win32_PnPSignedDriver` | Matériel exotique dont le pilote ne sera pas retrouvé tout seul. |
| `outils` (extension) | `dotnet tool list -g`, `Get-InstalledModule`, `cargo install --list` | Les modules PowerShell n'apparaissent nulle part ailleurs : ni au registre, ni dans winget. |
| `licences-fichier` | `WinRAR\rarreg.key` et équivalents | Un fichier de licence perdu, c'est un logiciel à racheter. |

## Hors de portée

Ces points ne sont pas des oublis : ils ne sont pas récupérables par un script
honnête, ou pas transférables du tout. La checklist doit le dire au lieu de
faire croire qu'un scan les couvrira un jour.

| Point | Pourquoi |
|---|---|
| Mots de passe enregistrés dans les navigateurs | Chiffrés par DPAPI avec une clé liée au compte **et** à la machine. Les déchiffrer demanderait d'imiter un voleur de mots de passe. Passer par l'export du navigateur ou la synchronisation du compte. |
| Sessions ouvertes dans les applications | Les jetons d'authentification sont liés à la machine. Il faudra se reconnecter partout, c'est normal. |
| Activations liées au matériel | Certaines licences comptent les machines activées. Désactiver **avant** de démonter l'ancien PC. |
| Données vivant chez l'éditeur | Ce qui est dans le cloud n'est pas sur le disque : rien à scanner, rien à copier. |
| État interne des applications du Store | Le bac à sable de `WindowsApps` n'est pas lisible depuis l'extérieur. |

## Chiffres

| | Avant la relecture des autres inventaires | Après |
|---|---|---|
| Familles couvertes | 11 | 10 + 1 partielle |
| En attente, sans méthode | 14 | 10 |
| En attente, méthode trouvée | 0 | 4 |
| Nouvelles familles repérées | — | 11 |
| Hors de portée | 6, jamais écrites | 5, écrites ici |
| **Total à faire** | **14** | **25** |

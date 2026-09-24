# Migration PC — Antoni 2027

Checklist interactive HTML pour la migration complète vers le PC Full White.
Fonctionne hors ligne, sans dépendance externe, depuis une clé USB ou GitHub Pages.

**Version : v6** · ~77 Ko · Fichier unique auto-suffisant

---

## Sommaire

- [Vue d'ensemble](#vue-densemble)
- [Configuration cible](#configuration-cible)
- [Structure](#structure)
- [Fonctionnalités](#fonctionnalités)
- [Nouveau PC — 18 étapes](#nouveau-pc--18-étapes)
- [Apps — 56 applications](#apps--56-applications)
- [Données à sauvegarder — 16 items](#données-à-sauvegarder--16-items)
- [PWA — 8 raccourcis](#pwa--8-raccourcis)
- [Dépendances entre éléments](#dépendances-entre-éléments)
- [Warnings critiques](#warnings-critiques)
- [Requêtes Google](#requêtes-google)
- [Workflow clé USB](#workflow-clé-usb)
- [Structure technique](#structure-technique)
- [Déploiement GitHub Pages](#déploiement-github-pages)
- [Historique des versions](#historique-des-versions)

---

## Vue d'ensemble

Outil de suivi pour migrer de l'ancien PC (MSI Pulse 17) vers le nouveau PC Full White prévu pour mai-juin 2027.

Le fichier est entièrement autonome : aucune connexion internet requise pour fonctionner, aucune librairie externe, aucun CDN. Il peut être ouvert directement depuis une clé USB sur un PC fraîchement installé sans réseau.

La progression est sauvegardée automatiquement dans le localStorage du navigateur et peut être exportée en JSON pour transférer l'avancement entre les deux machines.

## Configuration cible

| Composant | Modèle |
|---|---|
| CPU | AMD Ryzen 7 9800X3D |
| GPU | MSI RTX 5070 Ti TRIO OC |
| Carte mère | ASUS ROG STRIX B850-A GAMING WIFI |
| RAM | Corsair Vengeance RGB DDR5-6000 |
| SSD | Samsung 9100 PRO 4 To (PCIe 5.0) |
| Boîtier | Antec C8 |
| Watercooling | ARCTIC Liquid Freezer III Pro 360 |
| Alimentation | Corsair RM850e |
| Ventilateurs | 10× ARCTIC P12/P14 Reverse |
| Écran principal | Xiaomi G Pro 27Qi 2026 (1440p 180Hz HDR) |
| Écran secondaire | Xiaomi A24i 2026 (1080p 165Hz) |
| OS | Windows 11 Pro (clé OEM UE) |

Budget estimé : ~4 720 € · Achat prévu mai-juin 2027

## Structure

| Onglet | Items | Rôle |
|---|---|---|
| Nouveau PC | 18 | Drivers, BIOS, activation, vérifications post-install |
| Apps | 56 | Applications à réinstaller, classées par catégorie |
| Données | 16 | Fichiers et configs à sauvegarder avant migration |
| PWA | 8 | Raccourcis Chrome à recréer |
| **Total** | **98** | |

## Fonctionnalités

### Navigation et affichage

Mode Normal et mode Compact (masque les descriptions pour afficher plus d'items). Thème clair/sombre détecté automatiquement depuis les préférences Windows via `prefers-color-scheme`, avec bouton de bascule manuel. Teinte de fond légèrement différente par onglet pour se repérer visuellement. Badge compteur `X/Y` sur chaque onglet. Titre de la page navigateur mis à jour avec la progression globale.

### Progression

Barre de progression globale tous onglets confondus avec pourcentage. Barre de progression par onglet. Estimation du temps restant calculée depuis les durées d'installation renseignées sur chaque item. Bloc Estimation journée en haut avec mini-barres cliquables pour Nouveau PC et Apps.

### Interaction

Recherche globale sur les 4 onglets simultanément, avec résultats groupés par onglet et cochables directement. Recherche locale dans l'onglet Apps. Quatre modes de tri pour les Apps : par catégorie, par priorité, par durée, ou ordre conseillé pour le Jour J. Filtre pour n'afficher que les apps sans winget (celles qui nécessitent une installation manuelle). Bouton Tout cocher par catégorie. Badge winget cliquable qui copie la commande d'installation dans le presse-papier. Bouton par catégorie pour copier le script winget de toute la section. Notes personnelles libres sur chaque item. Date de cochage affichée en relatif (aujourd'hui, hier, il y a 3j).

### Session de travail

Bouton pour démarrer une session qui affiche un chronomètre et compte les tâches cochées depuis le début. Bouton Arrêter pour terminer. Animation de confettis à chaque fois qu'un onglet atteint 100%.

### Historique

Affichage des 5 dernières actions (cochage/décochage) avec le nom de l'item.

### Champs spéciaux

Champ Clé de licence sur l'item Licences logicielles pour noter les clés AIDA64 et Adobe Acrobat. Champs Variables d'environnement sur l'item correspondant pour noter ANDROID_HOME, JAVA_HOME et les chemins PATH custom avant migration. Ces valeurs sont incluses dans l'export JSON.

### Dépendances

Badge visuel sur les items qui ont une dépendance ou qui sont requis par un autre élément, pour respecter l'ordre d'installation.

### Export et sync

Export JSON complet de la progression (cases cochées, notes, dates, licences, variables d'environnement). Import JSON pour reprendre sur une autre machine. Script winget complet de toutes les apps. Script winget des apps restantes uniquement (celles non cochées) pour le Jour J. Export texte de la checklist. Impression globale ou par onglet avec CSS dédié.

## Nouveau PC — 18 étapes

Les 12 premières sont l'installation des drivers dans l'ordre obligatoire. Les 6 dernières sont les vérifications post-installation.

### Installation (1-12)

| # | Étape | Source | Durée | Priorité |
|---|---|---|---|---|
| 1 | AMD Chipset Driver (B850) | amd.com | ~10min | Haute |
| 2 | ASUS BIOS Update (B850-A) | rog.asus.com | ~15min | Moyenne |
| 3 | ASUS DriverHub (B850-A) | rog.asus.com | ~20min | Haute |
| 4 | Realtek LAN (via DriverHub) | Inclus DriverHub | ~5min | Haute |
| 5 | WiFi 7 Driver (via DriverHub) | Inclus DriverHub | ~5min | Moyenne |
| 6 | Realtek Audio SupremeFX (via DriverHub) | Inclus DriverHub | ~5min | Haute |
| 7 | NVIDIA App + drivers RTX 5070 Ti | nvidia.com | ~15min | Haute |
| 8 | MSI Afterburner | msi.com | ~5min | Moyenne |
| 9 | Corsair iCUE (bridge RAM RGB) | corsair.com | ~10min | Haute |
| 10 | SignalRGB (RGB unifié) | signalrgb.com | ~15min | Haute |
| 11 | Xiaomi Display Manager | Xiaomi | ~10min | Moyenne |
| 12 | Windows 11 Pro — activation | destock-informatique.com | ~5min | Haute |

### Vérifications post-installation (13-18)

| # | Vérification | Outil | Durée |
|---|---|---|---|
| 13 | Activer EXPO DDR5-6000 dans le BIOS | BIOS ASUS → Ai Tweaker | ~5min |
| 14 | Vérifier températures idle (HWiNFO) | HWiNFO64 | ~10min |
| 15 | Vérifier flux ventilos ARCTIC (direction) | Physique / SignalRGB | ~10min |
| 16 | Benchmark SSD CrystalDiskMark | CrystalDiskMark | ~10min |
| 17 | Tester RGB SignalRGB complet | SignalRGB | ~10min |
| 18 | Configurer écrans Xiaomi (résolution + Hz) | Xiaomi Display Manager | ~10min |

**Détails des vérifications :**

**13. Activer EXPO DDR5-6000 dans le BIOS**
Redémarrer → DEL → Ai Tweaker → EXPO Profile 1 → Save. Vérifier 6000 MHz dans Task Manager → Performance → Mémoire.

**14. Vérifier températures idle (HWiNFO)**
CPU idle < 45°C, GPU idle < 40°C, SSD < 50°C. Si anormal, vérifier pâte thermique et orientation ventilos.

**15. Vérifier flux ventilos ARCTIC (direction)**
⚠️ Ventilos ARCTIC P12/P14 Reverse : flux inversé par rapport au standard. Vérifier que l'air entre par le bas/avant et sort par le haut/arrière. Confirmer avec SignalRGB ou à la main.

**16. Benchmark SSD CrystalDiskMark**
Samsung 9100 PRO sur PCIe 5.0 : seq read attendu ~14,800 MB/s. Si < 10,000 MB/s, vérifier que le slot M.2 est bien PCIe 5.0 et que le mode est activé dans le BIOS.

**17. Tester RGB SignalRGB complet**
Vérifier que B850-A (Aura), RTX 5070 Ti, RAM Corsair et les 10 ventilos ARCTIC répondent tous. Si un élément manque, relancer iCUE en arrière-plan puis SignalRGB.

**18. Configurer écrans Xiaomi (résolution + Hz)**
G Pro 27Qi : 2560×1440 @ 180Hz HDR. A24i : 1920×1080 @ 165Hz. Vérifier dans Paramètres → Affichage → Résolution et fréquence de rafraîchissement.

## Apps — 56 applications

### Développement (10)

| App | Winget ID | Priorité | Durée | Source |
|---|---|---|---|---|
| Android Studio | `Google.AndroidStudio` | Haute | ~45min | Site officiel |
| Python 3.14 | `Python.Python.3.14` | Haute | ~5min | Site officiel |
| Node.js | `OpenJS.NodeJS` | Haute | ~5min | Site officiel |
| Git | `Git.Git` | Haute | ~3min | Site officiel |
| PowerShell 7 | `Microsoft.PowerShell` | Haute | ~3min | Site officiel |
| PowerToys | `Microsoft.PowerToys` | Moyenne | ~5min | winget |
| AutoHotkey | `AutoHotkey.AutoHotkey` | Haute | ~3min | Site officiel / GitHub |
| Visual Studio Build Tools 2022 | `Microsoft.VisualStudio.2022.BuildTools` | Moyenne | ~30min | Site officiel |
| Unity 2022.3 LTS | — | Moyenne | ~30min | Unity Hub |
| Java 8 (JDK) | `Oracle.JDK.8` | Moyenne | ~5min | Site officiel |

### Jeux & Launchers (14)

| App | Winget ID | Priorité | Durée | Source |
|---|---|---|---|---|
| Steam | `Valve.Steam` | Haute | ~5min | Site officiel |
| Epic Games Launcher | `EpicGames.EpicGamesLauncher` | Haute | ~5min | Site officiel |
| EA App | `ElectronicArts.EADesktop` | Haute | ~10min | Site officiel |
| Vortex (mod manager) | `NexusMods.Vortex` | Moyenne | ~5min | Site officiel |
| Wallpaper Engine | — | Moyenne | ~5min | Via Steam |
| Minecraft Java Edition | `Mojang.MinecraftLauncher` | Moyenne | ~10min | Launcher officiel |
| Minecraft Bedrock (UWP) | — | Moyenne | ~10min | Microsoft Store |
| Age of Mythology: Retold | — | Basse | ~60min | Xbox / Steam |
| Cities: Skylines II | — | Basse | ~60min | Steam |
| Cyberpunk 2077 | — | Basse | ~120min | GOG / Steam |
| Marvel's Spider-Man Remastered | — | Basse | ~120min | Steam |
| The Last of Us Part I | — | Basse | ~150min | Steam |
| MOUSE: P.I. For Hire | — | Basse | ~30min | Steam |
| Hercule (rétro) | — | Basse | ~5min | Abandonware |

### Réseau & Sécurité (3)

| App | Winget ID | Priorité | Durée | Source |
|---|---|---|---|---|
| NordVPN | `NordVPN.NordVPN` | Haute | ~5min | Site officiel |
| NextDNS | `NextDNS.NextDNS` | Moyenne | ~3min | Site officiel |
| qBittorrent | `qBittorrent.qBittorrent` | Moyenne | ~3min | Site officiel |

### IA & Productivité (6)

| App | Winget ID | Priorité | Durée | Source |
|---|---|---|---|---|
| Claude | — | Haute | ~3min | Microsoft Store |
| ChatGPT Desktop | — | Moyenne | ~3min | Microsoft Store |
| Microsoft 365 | `Microsoft.Office` | Haute | ~15min | Site officiel |
| Google Chrome | `Google.Chrome` | Haute | ~5min | Site officiel |
| Google Drive | `Google.GoogleDrive` | Moyenne | ~10min | Site officiel |
| WCUM (Widget Claude Usage Mini) | — | Haute | ~15min | Local — C:\\dev\\WCW |

### Médias (3)

| App | Winget ID | Priorité | Durée | Source |
|---|---|---|---|---|
| K-Lite Codec Pack | `CodecGuide.K-LiteCodecPack.Basic` | Moyenne | ~5min | Site officiel |
| VLC | `VideoLAN.VLC` | Haute | ~3min | Site officiel |
| Deezer | — | Moyenne | ~3min | Microsoft Store |

### Utilitaires Système (15)

| App | Winget ID | Priorité | Durée | Source |
|---|---|---|---|---|
| UniGetUI | `MartiCliment.UniGetUI` | Haute | ~5min | Site officiel |
| 7-Zip | `7zip.7zip` | Haute | ~3min | Site officiel |
| CrystalDiskInfo | `CrystalDewWorld.CrystalDiskInfo` | Moyenne | ~3min | Site officiel |
| CrystalDiskMark | `CrystalDewWorld.CrystalDiskMark` | Moyenne | ~3min | Site officiel |
| HWiNFO64 | `REALiX.HWiNFO` | Moyenne | ~3min | Site officiel |
| AIDA64 Extreme | — | Moyenne | ~5min | Site officiel |
| WinDirStat | `WinDirStat.WinDirStat` | Basse | ~3min | Site officiel |
| Winaero Tweaker | — | Moyenne | ~3min | Site officiel |
| Windhawk | `RamenSoftware.Windhawk` | Moyenne | ~5min | Site officiel / GitHub |
| Adobe Acrobat | — | Moyenne | ~10min | Site officiel |
| Window Centering Helper | — | Basse | ~3min | Site officiel |
| Task Separator 11 | — | Basse | ~3min | Site officiel |
| Wintoys | — | Basse | ~3min | Microsoft Store |
| Wiggler | — | Basse | ~3min | Microsoft Store |
| FluentFlyout | — | Moyenne | ~3min | Microsoft Store / GitHub |

### Drivers périphériques (2)

| App | Winget ID | Priorité | Durée | Source |
|---|---|---|---|---|
| SteelSeries GG | — | Moyenne | ~10min | Site officiel |
| AULA F108Pro (driver) | — | Moyenne | ~5min | Site AULA |

### Communication & Perso (3)

| App | Winget ID | Priorité | Durée | Source |
|---|---|---|---|---|
| Discord | `Discord.Discord` | Haute | ~5min | Site officiel |
| WhatsApp Desktop | — | Haute | ~5min | Microsoft Store |
| Lock Screen Wallpaper Synchroniser | — | Basse | ~5min | Microsoft Store |

**30 apps sur 56 sont installables via winget.** Les autres nécessitent un téléchargement manuel ou passent par le Microsoft Store.

## Données à sauvegarder — 16 items

### Critique (7)

| Item | Chemin | Note |
|---|---|---|
| Projets dev locaux | `C:\\dev\\` | WCA, YouTube Notif — PRIORITÉ ABSOLUE, aucun filet de sécurité |
| Scripts custom Spcrit | `C:\\Users\\anton\\Downloads\\Spcrit\\` | IA-Menu.exe, presse_papier.exe, shutdown.exe — sources .ahk si disponibles |
| Clés SSH & GPG | `C:\\Users\\anton\\.ssh\\` | id_rsa, id_ed25519, known_hosts, config |
| Variables d'environnement *(champs variables d'env)* | `Panneau config → Système → Variables d'env` | PATH, ANDROID_HOME, JAVA_HOME — toutes les variables custom |
| Dossier Téléchargements | `C:\\Users\\anton\\Downloads\\` | Trier avant migration — garder uniquement l'essentiel |
| Licences logicielles *(champ clé de licence)* | `Email / comptes en ligne` | AIDA64, Adobe Acrobat — noter les clés |
| Profils Vortex (mods) | `%AppData%\\Vortex\\` | Exporter via Vortex → Settings → Export avant désinstall |

### Important (6)

| Item | Chemin | Note |
|---|---|---|
| Config Android Studio | `%AppData%\\Google\\AndroidStudio2025.3\\` | SDK path, AVDs, keymaps, settings |
| Config PowerToys | `%LocalAppData%\\Microsoft\\PowerToys\\` | FancyZones layouts dual monitor, raccourcis |
| Config Windhawk | `%ProgramData%\\Windhawk\\` | Mods actifs et leurs configurations |
| Wallpapers Wallpaper Engine | `Steam\\steamapps\\workshop\\content\\431960\\` | Workshop se retélécharge via Steam. Playlists custom à sauvegarder. |
| Sauvegardes jeux (hors cloud) | `Documents\\My Games\\ + %AppData%` | GTA V, RDR2, Cyberpunk — vérifier cloud Steam d'abord |
| Config Skyve (Cities Skylines II) | `%LocalAppData%\\Colossal Order\\Cities Skylines II\\` | Exporter le profil Skyve |

### Optionnel (2)

| Item | Chemin | Note |
|---|---|---|
| Projets Unity | `Selon localisation tes projets Unity` | ProjectSettings — versionner sur GitHub si possible |
| MacroDroid (Android) | `Sur téléphone — cloud sync automatique` | Auto sur Galaxy S26 Ultra. |

## PWA — 8 raccourcis

Ces raccourcis Chrome se restaurent automatiquement avec la synchronisation du compte Google après installation de Chrome. La checklist sert uniquement à vérifier qu'ils sont bien revenus.

| App | URL |
|---|---|
| Gmail | https://mail.google.com |
| Google Calendar (Agenda) | https://calendar.google.com |
| Google Keep | https://keep.google.com |
| Google Gemini | https://gemini.google.com |
| YouTube | https://youtube.com |
| PC Part Picker | https://pcpartpicker.com |
| Carrefour.fr | https://www.carrefour.fr |
| E.Leclerc Drive | https://www.leclercdrive.fr |

## Dépendances entre éléments

| Élément | Dépendance |
|---|---|
| NVIDIA App + drivers RTX 5070 Ti | Installer avant MSI Afterburner |
| Corsair iCUE (bridge RAM RGB) | Requis par SignalRGB |
| Node.js | Requis par WCUM |
| Google Chrome | Requis avant les PWA |
| WCUM (Widget Claude Usage Mini) | Requiert Node.js + Python |

## Warnings critiques

| Élément | Avertissement |
|---|---|
| ASUS DriverHub (B850-A) | Lancer en administrateur pour éviter les erreurs d'installation. |
| NVIDIA App + drivers RTX 5070 Ti | Télécharger uniquement sur nvidia.com — nombreux sites pirates de drivers. |
| MSI Afterburner | ⚠️ Télécharger EXCLUSIVEMENT sur msi.com ou guru3d.com — nombreux sites pirates dangereux. |
| SignalRGB (RGB unifié) | Configurer absolument après NVIDIA App et iCUE — sinon les bridges ne fonctionnent pas. |

## Requêtes Google

76 requêtes de recherche, toutes vérifiées. L'opérateur `site:` force Google à ne chercher que sur le domaine officiel, ce qui évite les sites pirates et garantit un lien à jour même dans un an.

Ce choix a été fait volontairement à la place de liens de téléchargement directs, qui seraient obsolètes d'ici 2027 (nouvelles versions, URLs modifiées, domaines changés).

| App | Requête |
|---|---|
| 7-Zip | `site:7-zip.org download` |
| AIDA64 Extreme | `site:aida64.com download extreme` |
| AMD Chipset Driver (B850) | `site:amd.com chipset drivers AM5 B850 download` |
| ASUS BIOS Update (B850-A) | `site:asus.com ROG STRIX B850-A GAMING WIFI BIOS download` |
| ASUS DriverHub (B850-A) | `site:asus.com DriverHub B850-A download` |
| AULA F108Pro (driver) | `AULA F108Pro driver download official` |
| Adobe Acrobat | `site:adobe.com download acrobat reader` |
| Age of Mythology: Retold | `Age of Mythology Retold download Steam Xbox` |
| Android Studio | `site:developer.android.com android studio download` |
| AutoHotkey | `site:github.com AutoHotkey AutoHotkey releases` |
| Carrefour.fr | `Carrefour.fr site web` |
| ChatGPT Desktop | `ChatGPT desktop app Microsoft Store Windows` |
| Cities: Skylines II | `Cities Skylines 2 download Steam` |
| Claude | `Claude desktop app Microsoft Store Windows` |
| Corsair iCUE (bridge RAM RGB) | `site:corsair.com iCUE software download` |
| CrystalDiskInfo | `site:crystalmark.info CrystalDiskInfo download` |
| CrystalDiskMark | `site:crystalmark.info CrystalDiskMark download` |
| Cyberpunk 2077 | `Cyberpunk 2077 download Steam GOG` |
| Deezer | `Deezer Microsoft Store Windows` |
| Discord | `site:discord.com download` |
| E.Leclerc Drive | `E.Leclerc Drive site web` |
| EA App | `site:ea.com ea-app download` |
| Epic Games Launcher | `site:store.epicgames.com download launcher` |
| FluentFlyout | `site:github.com unchihugo FluentFlyout releases` |
| Git | `site:git-scm.com download` |
| Gmail | `Gmail PWA install Chrome` |
| Google Calendar (Agenda) | `Google Calendar PWA install Chrome` |
| Google Chrome | `site:google.com chrome download` |
| Google Drive | `site:google.com drive download` |
| Google Gemini | `Google Gemini PWA install Chrome` |
| Google Keep | `Google Keep PWA install Chrome` |
| HWiNFO64 | `site:hwinfo.com download` |
| Hercule (rétro) | `Hercule retro game abandonware download` |
| Java 8 (JDK) | `site:java.com download JDK 8` |
| K-Lite Codec Pack | `site:codecguide.com k-lite codec pack basic download` |
| Lock Screen Wallpaper Synchroniser | `Lock Screen Wallpaper Synchroniser Microsoft Store` |
| MOUSE: P.I. For Hire | `MOUSE PI For Hire download Steam` |
| MSI Afterburner | `site:msi.com afterburner download` |
| Microsoft 365 | `site:microsoft.com download microsoft 365` |
| Minecraft Bedrock (UWP) | `Minecraft Bedrock Microsoft Store Windows` |
| Minecraft Java Edition | `site:minecraft.net download java edition` |
| NVIDIA App + drivers RTX 5070 Ti | `site:nvidia.com GeForce RTX 5070 Ti driver download` |
| NextDNS | `site:nextdns.io download` |
| Node.js | `site:nodejs.org download` |
| NordVPN | `site:nordvpn.com download` |
| PC Part Picker | `PCPartPicker PWA install Chrome` |
| PowerShell 7 | `site:github.com PowerShell releases download` |
| PowerToys | `site:github.com microsoft PowerToys releases` |
| Python 3.14 | `site:python.org download python 3` |
| Realtek Audio SupremeFX (via DriverHub) | `site:asus.com ROG STRIX B850-A audio driver` |
| Realtek LAN (via DriverHub) | `site:asus.com ROG STRIX B850-A LAN driver` |
| SignalRGB (RGB unifié) | `site:signalrgb.com download` |
| Steam | `site:store.steampowered.com about download` |
| SteelSeries GG | `site:steelseries.com gg download` |
| Task Separator 11 | `site:github.com DrummerSi TaskSeparator11 releases` |
| The Last of Us Part I | `The Last of Us Part I download Steam` |
| UniGetUI | `site:github.com marticliment UniGetUI releases` |
| Unity 2022.3 LTS | `site:unity.com download unity hub` |
| VLC | `site:videolan.org download VLC` |
| Visual Studio Build Tools 2022 | `site:visualstudio.microsoft.com build tools download` |
| Vortex (mod manager) | `site:nexusmods.com vortex mod manager download` |
| WCUM (Widget Claude Usage Mini) | `WCUM Widget Claude Usage Mini Python tkinter` |
| Wallpaper Engine | `site:store.steampowered.com wallpaper engine 431960` |
| WhatsApp Desktop | `WhatsApp desktop Microsoft Store Windows` |
| WiFi 7 Driver (via DriverHub) | `site:asus.com ROG STRIX B850-A WiFi 7 driver` |
| Wiggler | `Wiggler mouse Microsoft Store Windows` |
| WinDirStat | `site:windirstat.net download` |
| Winaero Tweaker | `site:winaero.com download winaero tweaker` |
| Windhawk | `site:github.com ramensoftware windhawk releases` |
| Window Centering Helper | `site:kamilszymborski.github.io download window centering helper` |
| Windows 11 Pro — activation | `Windows 11 Pro OEM key legitimate UE` |
| Wintoys | `Wintoys Microsoft Store Windows app` |
| Xiaomi Display Manager | `Xiaomi G Pro 27Qi display manager download` |
| YouTube | `YouTube PWA install Chrome` |
| qBittorrent | `site:qbittorrent.org download` |
| s Spider-Man Remastered | `Marvel Spider-Man Remastered download Steam` |

## Workflow clé USB

1. Copier `index.html` sur la clé USB
2. Sur l'ancien PC : ouvrir le fichier dans Chrome, cocher les tâches, cliquer **Sauvegarder** → télécharge `progression-migration-pc.json`
3. Copier le JSON sur la clé USB
4. Sur le nouveau PC : ouvrir le HTML, cliquer **Importer**, sélectionner le JSON

Le localStorage est lié au navigateur ET au chemin du fichier. Si la lettre de lecteur USB change entre les deux PCs, le localStorage ne persiste pas — c'est pourquoi l'export JSON est indispensable pour le transfert.

## Structure technique

### Clés localStorage

| Clé | Contenu |
|---|---|
| `am31_state_v3` | Objet complet de l'état (checked, notes, dates, lic, env, lastSave) |
| `am31_theme` | `dark` ou `light` |

### Format JSON export

```json
{
  "version": 3,
  "exported": 1738000000000,
  "state": {
    "checked": { "n1": true, "a35": true },
    "notes": { "a1": "Note perso" },
    "dates": { "n1": 1738000000000 },
    "lic": { "s6": "XXXX-XXXX-XXXX" },
    "env": { "ANDROID_HOME": "C:\\...", "JAVA_HOME": "C:\\..." },
    "lastSave": 1738000000000
  }
}
```

### Structures de données JS

```javascript
NPC_DATA   // { id, o, n, src, p, t, post?, dep?, d, warn? }
APPS_DATA  // { id, n, c, src, w?, p, t, dep?, d }
DATA_SAVES // { id, n, p, note, pr, lic?, env? }
PWA_DATA   // { id, n, u, d }
SEARCH_QUERIES // { 'Nom app': 'requête google' }
INSTALL_ORDER  // [ 'a32', 'a28', ... ] ordre conseillé Jour J
```

### Contraintes techniques

Aucune dépendance externe : pas de CDN, pas de Google Fonts, pas de librairie JS. Icônes en emojis Unicode et SVG inline. Police système (`Segoe UI`). Tout le CSS et le JS sont inline dans le fichier.

Le JavaScript utilise de la concaténation de strings plutôt que des template literals pour éviter les problèmes d'échappement avec les apostrophes françaises. Les handlers d'événements sur les champs texte passent par de la délégation d'événements plutôt que des attributs inline.

## Déploiement GitHub Pages

### Structure du repo

```
migration-pc/
├── index.html      # La checklist (migration_pc_Antoni_v6.html renommé)
└── README.md       # Ce fichier
```

### Commandes

```bash
git init
git add .
git commit -m "Checklist migration PC v6"
git branch -M main
git remote add origin https://github.com/antoniman31/Migration-PC.git
git push -u origin main
```

Puis dans les settings du repo : **Settings → Pages → Source : Deploy from a branch → Branch : main → / (root) → Save**

URL finale : `https://antoniman31.github.io/Migration-PC`

### Note sur la confidentialité

GitHub Pages sur un repo public rend la checklist accessible à quiconque connaît l'URL. Elle contient des chemins de fichiers locaux (`C:\Users\anton\...`) et des noms de projets personnels. Pour un repo privé, GitHub Pages nécessite un compte GitHub Pro.

La progression (cases cochées, notes, clés de licence) reste stockée en localStorage côté navigateur et n'est jamais envoyée nulle part.

## Historique des versions

| Version | Changements |
|---|---|
| v1 | Première checklist HTML avec 3 onglets |
| v2 | Cohérence inter-onglets, session, confettis, historique, estimation journée, ordre conseillé |
| v3 | Suppression du mode Jour J, passage aux requêtes Google `site:` au lieu des liens directs |
| v4 | Réécriture complète du code (bugs JS critiques), validation Node.js + test runtime avec DOM mocké |
| v4.1 | Liens directs sur les PWA |
| v4.2 | Footer supprimé, actions déplacées dans l'entête |
| v4.3 | Sync bar supprimée, entête épuré |
| v5 | 8 améliorations esthétiques : items aérés, badges winget tronqués, warn badge CSS natif, sentence case, badge onglet contrasté |
| v5.1 | FluentFlyout ajouté |
| v5.2 | Sources GitHub explicites pour AutoHotkey, Windhawk, FluentFlyout |
| v5.3 | Correction lien FluentFlyout → `unchihugo/FluentFlyout` |
| v5.4 | Corrections Window Centering Helper et Task Separator 11 |
| v5.5 | WCUM ajouté dans IA, Claude-Usage-Widget retiré |
| **v6** | **Script winget restant, badges de dépendance, champ licence, 6 vérifications post-install, champs variables d'env, bouton Suivant entre onglets, impression par onglet, toolbar Apps réorganisée** |

## Corrections de liens GitHub

| App | Lien erroné | Lien correct |
|---|---|---|
| FluentFlyout | `The-Fluent-Team/FluentFlyout` | `unchihugo/FluentFlyout` |
| Window Centering Helper | recherche GitHub générique | `kamilszymborski.github.io` |
| Task Separator 11 | `windhawk taskbar separator` | `DrummerSi/TaskSeparator11` |

## Apps open source identifiées

| App | Repo |
|---|---|
| PowerShell 7 | github.com/PowerShell/PowerShell |
| PowerToys | github.com/microsoft/PowerToys |
| UniGetUI | github.com/marticliment/UniGetUI |
| AutoHotkey | github.com/AutoHotkey/AutoHotkey |
| Windhawk | github.com/ramensoftware/windhawk |
| FluentFlyout | github.com/unchihugo/FluentFlyout |
| Task Separator 11 | github.com/DrummerSi/TaskSeparator11 |
| Window Centering Helper | kamilszymborski.github.io |
| Vortex | github.com/Nexus-Mods/Vortex |
| qBittorrent | github.com/qbittorrent/qBittorrent |
| 7-Zip | github.com/ip7z/7zip |
| VLC | github.com/videolan/vlc |

---

*Généré depuis `migration_pc_Antoni_v6.html` · Signature couleur AM31 Blue `#5493FF`*
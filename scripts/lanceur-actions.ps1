# Ce que le lanceur sait faire, et ce dont chaque action a besoin.
#
# Separe de l'interface pour une raison pratique : cette partie se teste
# partout, l'interface graphique seulement sur Windows. Une action mal decrite
# ou un fichier manquant se voit ici, pas devant l'utilisateur.

# Construire la ligne de commande passee a powershell.exe.
#
# Start-Process -ArgumentList @(...) recolle les elements avec des espaces,
# sans jamais les proteger. Un chemin qui en contient — « D:\Migration PC »,
# « E:\Sauvegarde du 12 » — se coupait en deux et powershell.exe refusait la
# ligne entiere en affichant son aide. Le lanceur ne marchait donc que depuis
# un dossier sans espace, ce qui n'est pas une hypothese qu'on peut faire :
# le dossier de ce projet s'appelle « Migration PC ». Trouve en l'executant.
#
# Les guillemets sont doubles a l'interieur, comme le veut la convention de
# ligne de commande de Windows. Une chaine sans espace ni guillemet est
# laissee telle quelle : plus lisible dans les messages d'erreur.
function Format-Argument {
    param([string]$Valeur)
    if ($null -eq $Valeur) { return '""' }
    if ($Valeur -eq '') { return '""' }
    if ($Valeur -notmatch '[\s"]') { return $Valeur }
    return '"' + ($Valeur -replace '"', '""') + '"'
}

function Get-LigneCommande {
    param([string[]]$Arguments)
    return @($Arguments | ForEach-Object { Format-Argument $_ })
}

function Get-ActionsMigration {
    param([string]$Racine)

    @(
        [ordered]@{
            id      = 'ancien'
            titre   = "Cet ordinateur est l'ANCIEN"
            detail  = "Fait la liste de tout ce qui est installé, relève où vivent les réglages, et ouvre la checklist déjà remplie."
            script  = 'scan-pc.ps1'
            requis  = @('scan-pc.ps1', 'lib-detection.ps1')
            duree   = "1 a 3 minutes"
            suite   = @(
                "La checklist s'ouvre déjà remplie de vos logiciels.",
                "Onglet « Apps » : décochez ce que vous ne voulez pas reprendre.",
                "Onglet « Données » : les dossiers de réglages repérés s'y trouvent.",
                "Menu (…) Plus > Exporter le profil, et posez le fichier sur la clé."
            )
        },
        [ordered]@{
            id      = 'nouveau'
            titre   = "Cet ordinateur est le NOUVEAU"
            detail  = "Regarde ce qui est déjà installé et le propose à cocher. Ne coche rien tout seul : un rapprochement par nom peut se tromper."
            script  = 'verifier-pc.ps1'
            requis  = @('verifier-pc.ps1', 'lib-detection.ps1')
            duree   = "1 a 2 minutes"
            suite   = @(
                "La page propose de cocher ce qui est déjà installé : vérifiez avant.",
                "Les périphériques sans pilote sont listés, avec de quoi chercher.",
                "Onglet « Nouveau PC » : les pilotes portent le modèle de votre carte.",
                "Puis onglet « Apps » : le bouton winget copie la commande d'installation."
            )
        },
        [ordered]@{
            id      = 'emporter'
            titre   = "Emporter mes réglages"
            detail  = "Copie les dossiers de configuration de vos logiciels vers la clé. Installer un logiciel prend une commande ; retrouver ses réglages prend une soirée."
            script  = 'sauvegarder-configs.ps1'
            requis  = @('sauvegarder-configs.ps1', 'lib-detection.ps1')
            dossier = $true
            argument = 'Destination'
            duree   = "selon la taille"
            suite   = @(
                "Un index est écrit à côté de la copie : c'est lui qui permettra",
                "de tout remettre en place, sans deviner un seul chemin.",
                "Sur le nouveau PC, choisissez « Remettre mes réglages »."
            )
        },
        [ordered]@{
            id      = 'remettre'
            titre   = "Remettre mes réglages"
            detail  = "Repose les dossiers copiés à leur place. Refuse d'écraser quoi que ce soit par défaut, et met l'existant de côté sinon."
            script  = 'restaurer-configs.ps1'
            requis  = @('restaurer-configs.ps1')
            dossier = $true
            argument = 'Source'
            duree   = "quelques secondes"
            suite   = @(
                "À faire APRÈS avoir installé les logiciels : la plupart créent",
                "leur dossier de réglages au premier démarrage.",
                "Fermez-les avant, sinon ils réécriront par-dessus en se fermant."
            )
        },
        [ordered]@{
            id      = 'sauvegardes'
            titre   = "Vérifier une sauvegarde"
            detail  = "Compare une copie à son original, fichier par fichier. Une sauvegarde qu'on n'a jamais relue n'est pas une sauvegarde."
            script  = 'verifier-sauvegardes.ps1'
            requis  = @('verifier-sauvegardes.ps1')
            dossier = $true
            duree   = "selon la taille"
            suite   = @(
                "Le rapport dit fichier par fichier ce qui manque ou diffère.",
                "Une copie incomplète se voit ici, pas le jour où on en a besoin."
            )
        },
        [ordered]@{
            id      = 'checklist'
            titre   = "Ouvrir la checklist"
            detail  = "La page seule, sans rien scanner."
            # La page est a la racine du dossier, les scripts dans scripts\ :
            # on la designe depuis la ou ils vivent.
            fichier = '..\index.html'
            requis  = @('..\index.html')
            duree   = "immediat"
            suite   = @(
                "Au premier lancement, deux questions adaptent la liste à votre cas.",
                "Le sélecteur en haut de page permet d'en changer à tout moment."
            )
        }
    ) | ForEach-Object {
        $a = $_
        # Une action dont il manque un fichier est montree, mais desactivee et
        # expliquee : plus utile qu'une action absente dont on ignore pourquoi.
        $manquants = @($a.requis | Where-Object { -not (Test-Path -LiteralPath (Join-Path $Racine $_)) })
        $a.manquants = $manquants
        $a.possible  = ($manquants.Count -eq 0)
        [pscustomobject]$a
    }
}

# Le parcours complet, pour qui ouvre le lanceur sans savoir par ou commencer.
function Get-Parcours {
    @(
        "  Vous partez d'un PC vers un autre",
        "    1. Sur l'ANCIEN : inventorier. La page s'ouvre remplie, vous ajustez,",
        "       vous exportez votre profil sur la clé.",
        "    2. Emportez vos réglages sur la clé, et sauvegardez vos dossiers.",
        "       Vérifiez la copie avant d'aller plus loin.",
        "    3. Sur le NOUVEAU : vérifier. La page coche ce qui est déjà là et",
        "       signale les périphériques sans pilote.",
        "    4. Installez vos logiciels, PUIS remettez vos réglages.",
        "",
        "  Vous réinstallez Windows sur CETTE machine",
        "    1. Inventorier d'abord : après le formatage, il n'y a plus de source.",
        "    2. Emportez vos réglages, sauvegardez, et vérifiez la copie",
        "       AVANT de formater. Après, il est trop tard.",
        "    3. Après réinstallation : vérifier, sur la même machine.",
        "",
        "  Vous gardez les deux PC",
        "    Même chose, mais ne déliez rien sur l'ancien : il reste en service.",
        "    La page a un cas « Deux PC » qui retire ces étapes et ajoute la",
        "    synchronisation des dossiers."
    )
}

function Get-MessageManquants {
    param([string[]]$Manquants)
    if (-not $Manquants -or $Manquants.Count -eq 0) { return '' }
    $liste = ($Manquants -join ', ')
    if ($Manquants -contains 'lib-detection.ps1') {
        return "Fichier(s) absent(s) : $liste. Copiez le dossier entier, pas un fichier isolé."
    }
    return "Fichier(s) absent(s) : $liste."
}

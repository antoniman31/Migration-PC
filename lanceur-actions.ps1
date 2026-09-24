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
            detail  = "Fait la liste de tout ce qui est installe, releve ou vivent les reglages, et ouvre la checklist deja remplie."
            script  = 'scan-pc.ps1'
            requis  = @('scan-pc.ps1', 'lib-detection.ps1')
            duree   = "1 a 3 minutes"
            suite   = @(
                "La checklist s'ouvre deja remplie de vos logiciels.",
                "Onglet « Apps » : decochez ce que vous ne voulez pas reprendre.",
                "Onglet « Donnees » : les dossiers de reglages reperes s'y trouvent.",
                "Menu (...) Plus > Exporter le profil, et posez le fichier sur la cle."
            )
        },
        [ordered]@{
            id      = 'nouveau'
            titre   = "Cet ordinateur est le NOUVEAU"
            detail  = "Regarde ce qui est deja installe et le propose a cocher. Ne coche rien tout seul : un rapprochement par nom peut se tromper."
            script  = 'verifier-pc.ps1'
            requis  = @('verifier-pc.ps1', 'lib-detection.ps1')
            duree   = "1 a 2 minutes"
            suite   = @(
                "La page propose de cocher ce qui est deja installe : verifiez avant.",
                "Les peripheriques sans pilote sont listes, avec de quoi chercher.",
                "Onglet « Nouveau PC » : les pilotes portent le modele de votre carte.",
                "Puis onglet « Apps » : le bouton winget copie la commande d'installation."
            )
        },
        [ordered]@{
            id      = 'emporter'
            titre   = "Emporter mes reglages"
            detail  = "Copie les dossiers de configuration de vos logiciels vers la cle. Installer un logiciel prend une commande ; retrouver ses reglages prend une soiree."
            script  = 'sauvegarder-configs.ps1'
            requis  = @('sauvegarder-configs.ps1', 'lib-detection.ps1')
            dossier = $true
            argument = 'Destination'
            duree   = "selon la taille"
            suite   = @(
                "Un index est ecrit a cote de la copie : c'est lui qui permettra",
                "de tout remettre en place, sans deviner un seul chemin.",
                "Sur le nouveau PC, choisissez « Remettre mes reglages »."
            )
        },
        [ordered]@{
            id      = 'remettre'
            titre   = "Remettre mes reglages"
            detail  = "Repose les dossiers copies a leur place. Refuse d'ecraser quoi que ce soit par defaut, et met l'existant de cote sinon."
            script  = 'restaurer-configs.ps1'
            requis  = @('restaurer-configs.ps1')
            dossier = $true
            argument = 'Source'
            duree   = "quelques secondes"
            suite   = @(
                "A faire APRES avoir installe les logiciels : la plupart creent",
                "leur dossier de reglages au premier demarrage.",
                "Fermez-les avant, sinon ils reecriront par-dessus en se fermant."
            )
        },
        [ordered]@{
            id      = 'sauvegardes'
            titre   = "Verifier une sauvegarde"
            detail  = "Compare une copie a son original, fichier par fichier. Une sauvegarde qu'on n'a jamais relue n'est pas une sauvegarde."
            script  = 'verifier-sauvegardes.ps1'
            requis  = @('verifier-sauvegardes.ps1')
            dossier = $true
            duree   = "selon la taille"
            suite   = @(
                "Le rapport dit fichier par fichier ce qui manque ou differe.",
                "Une copie incomplete se voit ici, pas le jour ou on en a besoin."
            )
        },
        [ordered]@{
            id      = 'checklist'
            titre   = "Ouvrir la checklist"
            detail  = "La page seule, sans rien scanner."
            fichier = 'index.html'
            requis  = @('index.html')
            duree   = "immediat"
            suite   = @(
                "Au premier lancement, deux questions adaptent la liste a votre cas.",
                "Le selecteur en haut de page permet d'en changer a tout moment."
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
        "       vous exportez votre profil sur la cle.",
        "    2. Emportez vos reglages sur la cle, et sauvegardez vos dossiers.",
        "       Verifiez la copie avant d'aller plus loin.",
        "    3. Sur le NOUVEAU : verifier. La page coche ce qui est deja la et",
        "       signale les peripheriques sans pilote.",
        "    4. Installez vos logiciels, PUIS remettez vos reglages.",
        "",
        "  Vous reinstallez Windows sur CETTE machine",
        "    1. Inventorier d'abord : apres le formatage, il n'y a plus de source.",
        "    2. Emportez vos reglages, sauvegardez, et verifiez la copie",
        "       AVANT de formater. Apres, il est trop tard.",
        "    3. Apres reinstallation : verifier, sur la meme machine.",
        "",
        "  Vous gardez les deux PC",
        "    Meme chose, mais ne deliez rien sur l'ancien : il reste en service.",
        "    La page a un cas « Deux PC » qui retire ces etapes et ajoute la",
        "    synchronisation des dossiers."
    )
}

function Get-MessageManquants {
    param([string[]]$Manquants)
    if (-not $Manquants -or $Manquants.Count -eq 0) { return '' }
    $liste = ($Manquants -join ', ')
    if ($Manquants -contains 'lib-detection.ps1') {
        return "Fichier(s) absent(s) : $liste. Copiez le dossier entier, pas un fichier isole."
    }
    return "Fichier(s) absent(s) : $liste."
}

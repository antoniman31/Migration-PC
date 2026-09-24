# Ce que le lanceur sait faire, et ce dont chaque action a besoin.
#
# Separe de l'interface pour une raison pratique : cette partie se teste
# partout, l'interface graphique seulement sur Windows. Une action mal decrite
# ou un fichier manquant se voit ici, pas devant l'utilisateur.

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
        "    2. Sauvegardez vos dossiers, puis verifiez la copie (option 3).",
        "    3. Sur le NOUVEAU : verifier. La page coche ce qui est deja la et",
        "       signale les peripheriques sans pilote.",
        "",
        "  Vous reinstallez Windows sur CETTE machine",
        "    1. Inventorier d'abord : apres le formatage, il n'y a plus de source.",
        "    2. Sauvegardez et verifiez la copie AVANT de formater.",
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

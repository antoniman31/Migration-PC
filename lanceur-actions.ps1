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
        },
        [ordered]@{
            id      = 'nouveau'
            titre   = "Cet ordinateur est le NOUVEAU"
            detail  = "Regarde ce qui est deja installe et le propose a cocher. Ne coche rien tout seul : un rapprochement par nom peut se tromper."
            script  = 'verifier-pc.ps1'
            requis  = @('verifier-pc.ps1', 'lib-detection.ps1')
            duree   = "1 a 2 minutes"
        },
        [ordered]@{
            id      = 'sauvegardes'
            titre   = "Verifier une sauvegarde"
            detail  = "Compare une copie a son original, fichier par fichier. Une sauvegarde qu'on n'a jamais relue n'est pas une sauvegarde."
            script  = 'verifier-sauvegardes.ps1'
            requis  = @('verifier-sauvegardes.ps1')
            dossier = $true
            duree   = "selon la taille"
        },
        [ordered]@{
            id      = 'checklist'
            titre   = "Ouvrir la checklist"
            detail  = "La page seule, sans rien scanner."
            fichier = 'index.html'
            requis  = @('index.html')
            duree   = "immediat"
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

function Get-MessageManquants {
    param([string[]]$Manquants)
    if (-not $Manquants -or $Manquants.Count -eq 0) { return '' }
    $liste = ($Manquants -join ', ')
    if ($Manquants -contains 'lib-detection.ps1') {
        return "Fichier(s) absent(s) : $liste. Copiez le dossier entier, pas un fichier isole."
    }
    return "Fichier(s) absent(s) : $liste."
}

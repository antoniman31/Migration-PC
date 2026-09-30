# Fonction commune aux deux scripts de scan : poser le resultat a cote de
# index.html et ouvrir la page dessus.
#
# Pourquoi un .js et pas seulement le .json : une page ouverte depuis une cle
# USB (file://) ne peut pas aller LIRE un fichier — le navigateur refuse fetch
# sur le disque local — mais elle peut charger un fichier JavaScript pose a
# cote d'elle. En ecrivant resultat-scan.js, ouvrir index.html suffit : la page
# s'affiche deja remplie, sans fichier a retrouver ni a deposer.
#
# Le .json reste ecrit : c'est le format d'echange, lisible et reutilisable.

# Ou vit index.html par rapport aux scripts. Les scripts vivent dans scripts\
# et la page a la racine : on la cherche a cote d'abord — un dossier decompresse
# a plat reste possible — puis un cran au-dessus. Rend $null si elle est absente.
function Get-DossierPage {
    param([Parameter(Mandatory)] [string] $DossierScript)
    if (Test-Path -LiteralPath (Join-Path $DossierScript 'index.html')) { return $DossierScript }
    $parent = Split-Path $DossierScript -Parent
    if ($parent -and (Test-Path -LiteralPath (Join-Path $parent 'index.html'))) { return $parent }
    return $null
}

function Write-ResultatPourSite {
    param(
        [Parameter(Mandatory)] $Donnees,
        [Parameter(Mandatory)] [string] $DossierScript,
        # L'instantane de la SOURCE, quand on tourne sur la cible. Le navigateur
        # du PC neuf n'a jamais vu celui de l'ancien : sa memoire locale est
        # vide, et sans ce second objet la page recevrait un scan de cible sans
        # rien a quoi le comparer. C'est tout l'interet de la cle USB.
        $Source,
        [switch] $NePasOuvrir
    )

    $dossierPage = Get-DossierPage -DossierScript $DossierScript
    if ($dossierPage) { $DossierScript = $dossierPage }
    $page = Join-Path $DossierScript 'index.html'
    if (-not (Test-Path -LiteralPath $page)) {
        Write-Host ""
        Format-Paragraphe (Tr "index.html n'est pas a cote de ce script : le fichier JSON est ecrit, a importer a la main depuis le site.") |
            ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
        return
    }

    $cible = Join-Path $DossierScript 'resultat-scan.js'
    # Ce depot est un confort, pas le resultat : le JSON est deja ecrit. Une
    # cle protegee en ecriture, un disque plein ou un antivirus ne doivent pas
    # faire finir en rouge un scan qui a reussi.
    try {
        $json = $Donnees | ConvertTo-Json -Depth 8 -Compress
        # Deux objets poses sur window : la page les lit comme des donnees.
        $texte = "window.MIGRATION_PC_SCAN=$json;"
        if ($null -ne $Source) {
            $jsonSrc = $Source | ConvertTo-Json -Depth 8 -Compress
            $texte += "window.MIGRATION_PC_SOURCE=$jsonSrc;"
        }
        [System.IO.File]::WriteAllText(([System.IO.Path]::GetFullPath($cible)), $texte, (New-Object System.Text.UTF8Encoding $false))
    } catch {
        Write-Host ""
        Write-Host (Tr "Impossible de poser le resultat a cote de la page :") -ForegroundColor Yellow
        Write-Host ("  " + $_.Exception.Message) -ForegroundColor Yellow
        Write-Host (Tr "Le fichier JSON est ecrit : importez-le a la main depuis le site.")
        return
    }

    Write-Host ""
    Write-Host (Tr "Resultat pose a cote de la page.") -ForegroundColor Green
    if ($NePasOuvrir) {
        Write-Host (Tr "Ouvrez index.html : elle s'affichera deja remplie.")
        return
    }
    Write-Host (Tr "Ouverture de la checklist...")
    try { Start-Process $page }
    catch { Write-Host (Tr "Ouvrez index.html a la main : {0}" $_.Exception.Message) -ForegroundColor Yellow }
}

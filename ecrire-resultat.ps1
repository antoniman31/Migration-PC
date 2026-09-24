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

function Write-ResultatPourSite {
    param(
        [Parameter(Mandatory)] $Donnees,
        [Parameter(Mandatory)] [string] $DossierScript,
        [switch] $NePasOuvrir
    )

    $page = Join-Path $DossierScript 'index.html'
    if (-not (Test-Path -LiteralPath $page)) {
        Write-Host ""
        Write-Host "index.html n'est pas a cote de ce script : le fichier JSON est ecrit," -ForegroundColor Yellow
        Write-Host "a importer a la main depuis le site." -ForegroundColor Yellow
        return
    }

    $cible = Join-Path $DossierScript 'resultat-scan.js'
    $json = $Donnees | ConvertTo-Json -Depth 8 -Compress
    # Une ligne, un objet pose sur window : la page le lit comme une donnee.
    Set-Content -LiteralPath $cible -Value "window.MIGRATION_PC_SCAN=$json;" -Encoding UTF8

    Write-Host ""
    Write-Host "Resultat pose a cote de la page." -ForegroundColor Green
    if ($NePasOuvrir) {
        Write-Host "Ouvrez index.html : elle s'affichera deja remplie."
        return
    }
    Write-Host "Ouverture de la checklist..."
    try { Start-Process $page }
    catch { Write-Host "Ouvrez index.html a la main : $($_.Exception.Message)" -ForegroundColor Yellow }
}

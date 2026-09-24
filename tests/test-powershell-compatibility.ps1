# Verification statique des constructions compatibles avec Windows PowerShell 5.1.
$scriptPath = Join-Path $PSScriptRoot '..\scan-pc.ps1'
$content = [System.IO.File]::ReadAllText((Resolve-Path $scriptPath))

$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) {
    throw "scan-pc.ps1 ne parse pas : $($errors[0].Message)"
}

$expected = "Write-Host ('{0} variable(s) d environnement relevee(s).' -f `$nombreVariables)"
if ($content.IndexOf($expected, [System.StringComparison]::Ordinal) -lt 0) {
    throw "La sortie du nombre de variables n'utilise pas la construction attendue."
}

"BOM UTF-8 : $(([System.IO.File]::ReadAllBytes((Resolve-Path $scriptPath))[0..2] -join ',') -eq '239,187,191')"
"Compatibilite PowerShell 5.1 OK"

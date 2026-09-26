#!/usr/bin/env bash
# Rejoue exactement ce que lance le job Linux de la CI, dans le meme ordre et
# avec les memes options. Ecrit parce que trois fois de suite ma verification
# locale etait plus faible que la CI : « npm test | grep -ci fail » comptait un
# mot au lieu de regarder le code de sortie, et le test tactile tournait sans
# STRICT=1, qui est justement ce qui le rend bloquant.
#
#   ./verifier-comme-ci.sh
cd "$(dirname "$0")"
export CHROME="${CHROME:-/opt/pw-browsers/chromium-1194/chrome-linux/chrome}"
ech=0
lancer() {
  printf '%-46s ' "$*"
  if "$@" >/tmp/mpc-ci.log 2>&1; then echo OK; else
    echo ECHEC; ech=$((ech+1)); sed -n '$!d;p' /tmp/mpc-ci.log; tail -6 /tmp/mpc-ci.log|sed 's/^/    /'
  fi
}
# Meme ordre que .github/workflows/ci.yml
for t in profil-sync checklist winget inventaire-etendu dependances; do
  lancer node "tests/test-$t.js"; done
for t in scan verification sauvegardes lanceur configs-aller-retour powershell-compatibility; do
  lancer pwsh -File "tests/test-$t.ps1"; done
for t in navigateur verification-pc pwa; do lancer node "tests/test-$t.js"; done
printf '%-46s ' 'STRICT=1 tests/test-mobile.js'
if STRICT=1 node tests/test-mobile.js >/tmp/mpc-ci.log 2>&1; then echo OK; else
  echo ECHEC; ech=$((ech+1)); tail -8 /tmp/mpc-ci.log|sed 's/^/    /'; fi
for t in accessibilite guide quitter scenarios reinit menu profil-hostile sauvegarde debut config outils; do
  lancer node "tests/test-$t.js"; done
echo
if [ "$ech" -gt 0 ]; then echo "$ech ETAPE(S) EN ECHEC"; exit 1; fi
echo "TOUT PASSE, COMME LA CI"

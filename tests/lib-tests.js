// Le peu que les suites navigateur partagent.
//
// UN SEUL EXEMPLAIRE, et c'est le point. Quatre suites mesurent des pixels
// rendus, et chacune annoncait — ou n'annoncait pas — son navigateur a sa
// facon. Le meme travers existe deja dans le projet : test-guide.js porte sa
// propre copie du plancher de 12 px et de la regle des 44 x 24, sans la liste
// d'exceptions de test-mobile.js. Deux seuils qui disent la meme chose finissent
// par ne plus la dire pareil.
//
// Ce fichier ne contient que ce qui doit etre identique partout. Le reste de
// chaque suite lui appartient.

// AVEC QUEL NAVIGATEUR ON A MESURE. test-mobile.js a ete vert en integration et
// rouge en local pendant des semaines, sur un defaut reel : les deux machines ne
// faisaient pas tourner le meme Chromium. Un verdict de mise en page ne veut
// rien dire si on ne sait pas qui l'a rendu.
//
// La version de playwright est epinglee exactement dans package.json, sans le
// « ^ » : sans cela une resolution de dependances suffisait a changer le
// navigateur d'un jour a l'autre, et personne ne l'aurait vu.
function annoncerNavigateur(nav) {
  const force = process.env.CHROME;
  let l = 'Navigateur : ' + nav.version()
    + ' · playwright ' + require('playwright/package.json').version;
  if (force) {
    l += '\n  ATTENTION : CHROME force vers ' + force + '.'
      + '\n  Ce n\'est pas forcement celui qu\'installe la CI, donc ce verdict'
      + ' peut differer du sien.';
  }
  console.log(l);
}

module.exports = { annoncerNavigateur };

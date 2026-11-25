// Service worker — permet d'installer la checklist et de l'ouvrir hors ligne.
//
// Strategie : reseau d'abord, cache en secours. La page doit etre a jour quand
// le reseau repond, et s'ouvrir quand meme quand il ne repond pas. L'inverse
// (cache d'abord) servirait une version perimee a quelqu'un qui vient de
// recevoir une correction.
//
// Ce qui est mis en cache : le squelette de l'application et ses icones,
// c'est-a-dire des fichiers qui ne changent qu'a une publication, et RIEN
// d'autre. Avant, toute lecture de meme origine qui repondait ok etait gardee :
// un dossier servi en local aurait donc mis l'inventaire du PC
// (resultat-scan.js) dans le cache. La progression et le profil vivent dans
// localStorage, qui n'a rien a voir avec ce cache et survit a son effacement.
// tests/test-pwa.js verifie que rien hors du squelette n'y entre.
//
// Rappel : un service worker ne s'enregistre qu'en HTTPS (ou sur localhost).
// Ouverte depuis une cle USB en file://, la page fonctionne exactement pareil,
// simplement sans installation ni cache — elle est deja autonome.
//
// CACHE : derive de index.html par `npm run sync`, et verifie par
// tests/test-pwa.js. Sans cela un appareil ayant deja installe la page
// garderait l'ancien service worker, et la correction ne lui parviendrait pas.
// Ne pas modifier a la main : lancer `npm run sync`.
const CACHE = "migration-pc-f2d43f9ff543";
const SQUELETTE = [
  "./",
  "./index.html",
  "./manifest.json",
  "./icons/icon-192.png",
  "./icons/icon-512.png"
];

self.addEventListener("install", (e) => {
  // addAll echoue en bloc si un seul fichier manque : on installe fichier par
  // fichier pour qu'une icone absente ne prive pas la page de son cache.
  e.waitUntil(
    caches.open(CACHE)
      .then((c) => Promise.all(SQUELETTE.map((u) => c.add(u).catch(() => null))))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys()
      .then((noms) => Promise.all(noms.filter((n) => n !== CACHE).map((n) => caches.delete(n))))
      .then(() => self.clients.claim())
  );
});

// Les adresses du squelette, resolues une fois : comparer des chemins absolus
// evite qu'une requete « ./index.html?x » ou « / » echappe a la liste.
const PERMIS = new Set(SQUELETTE.map((u) => new URL(u, self.location).pathname));

self.addEventListener("fetch", (e) => {
  // Seules les lectures du squelette passent par ici : le reste (autres
  // origines, inventaire, fichiers poses a cote) va au reseau sans que le
  // service worker s'en mele, donc sans jamais entrer dans le cache.
  if (e.request.method !== "GET") return;
  const url = new URL(e.request.url);
  if (url.origin !== self.location.origin || !PERMIS.has(url.pathname)) return;

  e.respondWith(
    fetch(e.request)
      .then((rep) => {
        // Une erreur serveur ne doit jamais remplacer une copie valide.
        if (rep && rep.ok) {
          const copie = rep.clone();
          caches.open(CACHE).then((c) => c.put(e.request, copie)).catch(() => {});
        }
        return rep;
      })
      .catch(() =>
        caches.match(e.request).then((c) => c || caches.match("./index.html"))
      )
  );
});

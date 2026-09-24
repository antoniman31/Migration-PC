// Service worker — permet d'installer la checklist et de l'ouvrir hors ligne.
//
// Strategie : reseau d'abord, cache en secours. La page doit etre a jour quand
// le reseau repond, et s'ouvrir quand meme quand il ne repond pas. L'inverse
// (cache d'abord) servirait une version perimee a quelqu'un qui vient de
// recevoir une correction.
//
// Ce qui est mis en cache : le squelette de l'application et ses icones,
// c'est-a-dire des fichiers qui ne changent qu'a une publication. Jamais de
// donnees : la progression et le profil vivent dans localStorage, qui n'a rien
// a voir avec ce cache et survit a son effacement.
//
// Rappel : un service worker ne s'enregistre qu'en HTTPS (ou sur localhost).
// Ouverte depuis une cle USB en file://, la page fonctionne exactement pareil,
// simplement sans installation ni cache — elle est deja autonome.
//
// CACHE : derive de index.html par `npm run sync`, et verifie par
// tests/test-pwa.js. Sans cela un appareil ayant deja installe la page
// garderait l'ancien service worker, et la correction ne lui parviendrait pas.
// Ne pas modifier a la main : lancer `npm run sync`.
const CACHE = "migration-pc-63f579db3c0f";
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

self.addEventListener("fetch", (e) => {
  // Seules les lectures passent par ici, et seulement celles de notre propre
  // origine : le reste va au reseau sans que le service worker s'en mele.
  if (e.request.method !== "GET") return;
  if (new URL(e.request.url).origin !== self.location.origin) return;

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

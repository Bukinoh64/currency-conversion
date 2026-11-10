"use strict";

const CACHE_NAME = "quiet-exchange-v3";
const APP_SHELL = [
  "./",
  "./index.html",
  "./css/styles.css",
  "./js/app.js",
  "./js/currencies.js",
  "./manifest.webmanifest",
  "./assets/icon.svg",
  "./assets/icon-192.png",
  "./assets/icon-512.png"
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(APP_SHELL))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((cacheNames) => Promise.all(
        cacheNames
          .filter((cacheName) => cacheName.startsWith("quiet-exchange-") && cacheName !== CACHE_NAME)
          .map((cacheName) => caches.delete(cacheName))
      ))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (event) => {
  const request = event.request;
  if (request.method !== "GET") return;

  const requestUrl = new URL(request.url);
  if (requestUrl.origin === self.location.origin) {
    if (request.mode === "navigate") {
      event.respondWith(
        fetch(request)
          .then((response) => {
            if (response.ok) {
              const copy = response.clone();
              caches.open(CACHE_NAME).then((cache) => cache.put("./index.html", copy));
            }
            return response;
          })
          .catch(async () => (await caches.match(request)) || caches.match("./index.html"))
      );
    } else {
      event.respondWith(
        caches.match(request).then((cached) =>
          cached || fetch(request).then((response) => {
            if (response.ok) {
              const copy = response.clone();
              caches.open(CACHE_NAME).then((cache) => cache.put(request, copy));
            }
            return response;
          })
        )
      );
    }
    return;
  }

  if (requestUrl.hostname === "flagcdn.com") {
    event.respondWith(
      caches.open(CACHE_NAME).then(async (cache) => {
        const cached = await cache.match(request);
        if (cached) return cached;

        const response = await fetch(request);
        if (response.ok || response.type === "opaque") {
          await cache.put(request, response.clone());
        }
        return response;
      })
    );
  }
});

const CACHE_NAME = "habit-last-v1";
const CORE_ASSETS = [
  "./",
  "./index.html",
  "./manifest.webmanifest",
  "./icons/icon-192.png",
  "./icons/icon-512.png",
  "./icons/icon-180.png"
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(CORE_ASSETS))
  );
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((names) =>
      Promise.all(
        names
          .filter((name) => name !== CACHE_NAME)
          .map((name) => caches.delete(name))
      )
    )
  );
  self.clients.claim();
});

function isSameOriginStaticAsset(request) {
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return false;
  if (request.method !== "GET") return false;
  if (request.mode === "navigate") return false;
  return /\.(?:css|js|mjs|json|webmanifest|png|jpg|jpeg|gif|svg|ico|woff2?)$/i.test(
    url.pathname
  );
}

async function networkFirstDocument(request) {
  const cache = await caches.open(CACHE_NAME);
  try {
    const networkResponse = await fetch(request);
    cache.put(request, networkResponse.clone());
    cache.put("./index.html", networkResponse.clone());
    return networkResponse;
  } catch {
    const cachedPage = await cache.match(request);
    if (cachedPage) return cachedPage;
    const fallback = await cache.match("./index.html");
    if (fallback) return fallback;
    return Response.error();
  }
}

async function staleWhileRevalidateAsset(request) {
  const cache = await caches.open(CACHE_NAME);
  const cached = await cache.match(request);

  const networkPromise = fetch(request)
    .then((response) => {
      if (response && response.ok) {
        cache.put(request, response.clone());
      }
      return response;
    })
    .catch(() => null);

  if (cached) {
    return cached;
  }

  const networkResponse = await networkPromise;
  if (networkResponse) return networkResponse;
  return Response.error();
}

self.addEventListener("fetch", (event) => {
  const { request } = event;

  if (request.mode === "navigate") {
    event.respondWith(networkFirstDocument(request));
    return;
  }

  if (isSameOriginStaticAsset(request)) {
    event.respondWith(staleWhileRevalidateAsset(request));
  }
});

/**
 * Service worker for the installed app.
 *
 * It exists for two reasons and deliberately no others: an installable app
 * needs a registered worker at the root scope, and a push notification needs
 * something running when no tab is.
 *
 * It does NOT cache HTML. Every page here is a LiveView, and a cached shell in
 * front of one is the bug that shows up a week later as "the screen is old"
 * with nobody able to say why. Only digested assets are cached, and those are
 * immutable by construction — the digest changes when the bytes do.
 */
const VERSION = "v1";
const ASSET_CACHE = `retrohexchat-assets-${VERSION}`;

self.addEventListener("install", (event) => {
  // Nothing to pre-cache: the assets worth keeping are whatever this version of
  // the app actually asks for, and it has not asked yet.
  event.waitUntil(self.skipWaiting());
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    (async () => {
      const names = await caches.keys();
      await Promise.all(
        names
          .filter((name) => name.startsWith("retrohexchat-assets-"))
          .filter((name) => name !== ASSET_CACHE)
          .map((name) => caches.delete(name)),
      );
      await self.clients.claim();
    })(),
  );
});

function cacheable(request) {
  if (request.method !== "GET") return false;

  const url = new URL(request.url);
  return url.origin === self.location.origin && url.pathname.startsWith("/assets/");
}

self.addEventListener("fetch", (event) => {
  if (!cacheable(event.request)) return;

  event.respondWith(
    (async () => {
      const cache = await caches.open(ASSET_CACHE);
      const hit = await cache.match(event.request);
      if (hit) return hit;

      const response = await fetch(event.request);
      // Only a clean response is worth keeping; a 404 cached under a digested
      // name would survive the deploy that fixed it.
      if (response && response.ok) {
        cache.put(event.request, response.clone());
      }
      return response;
    })(),
  );
});

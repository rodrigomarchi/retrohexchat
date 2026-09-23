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

// ── Push ──────────────────────────────────────────────────────────────────
//
// The payload is encrypted end to end for this browser, so the push service in
// the middle — Google's, Mozilla's, Apple's — carried ciphertext and an
// endpoint. What arrives here is the doorbell: which conversation, who, and
// enough of the line to know whether it is worth opening. The message itself is
// read in the app.

const NOTIFICATION_PATH = "/chat";

function notificationFrom(payload) {
  const data = payload && typeof payload === "object" ? payload : {};
  const conversation = typeof data.conversation === "string" ? data.conversation : "";

  return {
    title: typeof data.title === "string" && data.title !== "" ? data.title : "Retro Hex Chat",
    options: {
      body: typeof data.body === "string" ? data.body : "",
      // One notification per conversation: a room that was busy while the tab
      // was closed is one thing to come back to, not fifteen.
      tag: conversation || "retrohexchat",
      renotify: false,
      data: { conversation },
    },
  };
}

function conversationUrl(conversation) {
  if (!conversation) return NOTIFICATION_PATH;
  return `${NOTIFICATION_PATH}?conversation=${encodeURIComponent(conversation)}`;
}

// A person who already has the chat open somewhere wants that window raised,
// not a second one beside it. Only a window already on the app counts: focusing
// an unrelated tab of theirs would be worse than opening a new one.
function chooseClickTarget(windows, url) {
  const existing = (windows || []).find((client) => {
    try {
      return new URL(client.url).pathname.startsWith(NOTIFICATION_PATH);
    } catch {
      return false;
    }
  });

  return existing ? { focus: existing, url } : { open: url };
}

function readPayload(event) {
  if (!event || !event.data) return {};
  try {
    return event.data.json();
  } catch {
    return {};
  }
}

self.addEventListener("push", (event) => {
  const { title, options } = notificationFrom(readPayload(event));
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const conversation = (event.notification.data || {}).conversation;
  const url = conversationUrl(conversation);

  event.waitUntil(
    (async () => {
      const windows = await self.clients.matchAll({
        type: "window",
        includeUncontrolled: true,
      });
      const target = chooseClickTarget(windows, url);

      if (target.focus) {
        await target.focus.focus();
        if (target.focus.navigate) await target.focus.navigate(target.url);
        return;
      }

      await self.clients.openWindow(target.open);
    })(),
  );
});

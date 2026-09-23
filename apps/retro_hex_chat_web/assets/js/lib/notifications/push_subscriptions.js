/**
 * This browser's side of a web push subscription.
 *
 * The server can describe who should be told; only the browser can say where to
 * tell them. A subscription is an address at the browser vendor's push service
 * plus the two keys that let the server encrypt for this device — and it is
 * per-device by nature, so "turn this off" means this laptop, not this account.
 *
 * Everything here answers with a plain object instead of throwing. A person
 * ticking a box has no use for an exception: the box either turns green or the
 * window says why it could not.
 */

const APPLICATION_SERVER_KEY_PADDING = "=";

function base64UrlToUint8Array(value) {
  const padding = APPLICATION_SERVER_KEY_PADDING.repeat((4 - (value.length % 4)) % 4);
  const base64 = (value + padding).replace(/-/g, "+").replace(/_/g, "/");
  const raw = atob(base64);
  const bytes = new Uint8Array(raw.length);

  for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);

  return bytes;
}

function encodeKey(buffer) {
  if (!buffer) return null;

  const bytes = new Uint8Array(buffer);
  let binary = "";

  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);

  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function createPushSubscriptions(deps = {}) {
  const nav = deps.nav ?? (typeof navigator === "undefined" ? null : navigator);
  const userAgent = deps.userAgent ?? nav?.userAgent ?? "";

  function supported() {
    return Boolean(nav?.serviceWorker && typeof PushManager !== "undefined");
  }

  async function manager() {
    const registration = await nav.serviceWorker.ready;
    return registration?.pushManager ?? null;
  }

  function describe(subscription) {
    const json = subscription.toJSON ? subscription.toJSON() : {};
    const keys = json.keys ?? {};

    return {
      endpoint: subscription.endpoint,
      p256dh: keys.p256dh ?? encodeKey(subscription.getKey?.("p256dh")),
      auth: keys.auth ?? encodeKey(subscription.getKey?.("auth")),
      user_agent: userAgent.slice(0, 255),
    };
  }

  return {
    supported,

    /** What this browser already has, without asking it for anything new. */
    async current() {
      if (!supported()) return { supported: false, subscribed: false };

      try {
        const existing = await (await manager())?.getSubscription();
        return { supported: true, subscribed: Boolean(existing) };
      } catch {
        return { supported: true, subscribed: false };
      }
    },

    /**
     * Subscribe this browser, reusing whatever it already had.
     *
     * `userVisibleOnly` is not a preference: browsers refuse a subscription
     * without it, and a push that shows nothing is what the refusal is for.
     */
    async subscribe(publicKey) {
      if (!supported()) return { ok: false, reason: "unsupported" };
      if (!publicKey) return { ok: false, reason: "unconfigured" };

      try {
        const pushManager = await manager();
        const existing = await pushManager.getSubscription();
        const subscription =
          existing ??
          (await pushManager.subscribe({
            userVisibleOnly: true,
            applicationServerKey: base64UrlToUint8Array(publicKey),
          }));

        return { ok: true, subscription: describe(subscription) };
      } catch (error) {
        return { ok: false, reason: error?.name === "NotAllowedError" ? "denied" : "failed" };
      }
    },

    /** Give up this browser's subscription, and say which one it was. */
    async unsubscribe() {
      if (!supported()) return { ok: false, reason: "unsupported" };

      try {
        const existing = await (await manager())?.getSubscription();
        if (!existing) return { ok: true, endpoint: null };

        await existing.unsubscribe();
        return { ok: true, endpoint: existing.endpoint };
      } catch {
        return { ok: false, reason: "failed" };
      }
    },
  };
}

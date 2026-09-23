/**
 * Registering the service worker, and the reasons not to.
 *
 * The worker exists so the app can be installed and so a push has something to
 * wake; it is not load-bearing for anything on screen. So every failure here is
 * logged and swallowed: a browser without the API, a page served over plain
 * http, a user profile that blocks workers — none of those are reasons for the
 * chat itself to behave differently.
 */
import { log } from "../logger.js";

/**
 * @param {Object} [deps]
 * @param {Navigator} [deps.nav]
 * @param {string} [deps.path] - worker URL; must be root-scoped
 * @returns {Promise<ServiceWorkerRegistration|null>}
 */
export async function registerServiceWorker(deps = {}) {
  const nav = deps.nav ?? globalThis.navigator;
  const path = deps.path ?? "/sw.js";

  if (!nav || !("serviceWorker" in nav)) return null;

  try {
    return await nav.serviceWorker.register(path, { scope: "/" });
  } catch (error) {
    log.warn("service worker registration failed", error);
    return null;
  }
}

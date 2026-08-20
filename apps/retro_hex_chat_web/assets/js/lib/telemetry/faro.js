/**
 * @file Grafana Faro RUM bootstrap (framework-free, dependency-injected).
 *
 * Reads its configuration from `<meta>` tags rendered by the chat layout and
 * decides whether to start real-user monitoring. The Faro SDK itself is
 * injected (see `faro_boot.js`) so this module — the gating and the config
 * shape — is unit-tested under Vitest + jsdom without loading the SDK or
 * touching the network.
 *
 * Telemetry is POSTed same-origin to `/faro/collect`, which Nginx proxies to
 * the Grafana Alloy `faro.receiver` running on the app host.
 */

const APP_NAME = "retro_hex_chat_web";

/**
 * Normalise a URL path into a stable, low-cardinality RUM view name.
 *
 * Strips a leading locale segment (e.g. `/pt-BR`), maps the known surfaces to
 * friendly names, and collapses id-like segments to `:id` so metrics group by
 * route instead of by every distinct URL.
 *
 * @param {string} pathname - `location.pathname`.
 * @returns {string} The view name (e.g. "landing", "chat", "help").
 */
export function viewNameForPath(pathname) {
  let path = (pathname || "/").replace(/\/+$/, "");
  path = path.replace(/^\/[a-z]{2}(-[A-Za-z]{2,4})?(?=\/|$)/, "");

  if (path === "" || path === "/") return "landing";
  if (path === "/connect") return "connect";
  if (path === "/chat") return "chat";
  if (path === "/chat/help" || path.startsWith("/chat/help/")) return "help";

  return path
    .split("/")
    .map((seg) => (/^\d+$/.test(seg) || /^[0-9a-f]{8,}$/i.test(seg) ? ":id" : seg))
    .join("/");
}

/**
 * Read the Faro configuration from document meta tags.
 *
 * @param {{ querySelector: (selector: string) => ({ content: string } | null) }} doc - Document-like object.
 * @returns {{ enabled: boolean, url: string | null, version: string | null }}
 */
export function readFaroConfig(doc) {
  const meta = (name) => doc.querySelector(`meta[name="${name}"]`)?.content ?? null;
  return {
    enabled: meta("faro-enabled") === "true",
    url: meta("faro-collector-url"),
    version: meta("faro-app-version"),
  };
}

/**
 * Build a Faro bootstrapper bound to an injected SDK.
 *
 * `boot()` is a no-op (returns null) on localhost, when disabled, or when no
 * collector URL is configured — so dev traffic never ships and a missing
 * config fails closed. An SDK failure is logged and swallowed: RUM must never
 * take down the app it observes.
 *
 * @param {object} options
 * @param {(config: object) => unknown} options.initializeFaro - Faro SDK initializer.
 * @param {() => unknown[]} options.buildInstrumentations - Returns the instrumentation list.
 * @param {Window | { location: { hostname: string, protocol: string } }} options.win - Window-like object.
 * @param {{ querySelector: (selector: string) => ({ content: string } | null) }} options.doc - Document-like object.
 * @returns {{ boot: () => unknown | null }}
 */
export function createFaro({ initializeFaro, buildInstrumentations, win, doc }) {
  /**
   * Start Faro if the environment and config allow it.
   *
   * @returns {unknown | null} The Faro instance, or null when it did not start.
   */
  function boot() {
    const config = readFaroConfig(doc);
    const { hostname, protocol } = win.location;
    const isLocal = hostname === "localhost" || hostname === "127.0.0.1" || protocol === "file:";

    if (!config.enabled || isLocal || !config.url) return null;

    try {
      return initializeFaro({
        url: config.url,
        app: { name: APP_NAME, version: config.version ?? "unknown" },
        instrumentations: buildInstrumentations(),
      });
    } catch (error) {
      console.error("[faro] init failed", error);
      return null;
    }
  }

  return { boot };
}

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
 * localStorage key the load harness sets to disown its own traffic.
 *
 * Twenty synthetic browsers move a p75 tile as surely as twenty real ones, so a
 * load run silently rewrites the baseline it was meant to be measured against.
 * Marking the session lets the dashboards exclude it instead of guessing from a
 * user-agent.
 */
export const TRAFFIC_KEY = "retro_hex_chat_rum_traffic";

/**
 * Read the traffic kind this browser was told to report itself as.
 *
 * @param {{ localStorage?: Storage }} win - Window-like object.
 * @returns {string | null} The marker, or null for ordinary traffic.
 */
export function trafficKind(win) {
  try {
    return win.localStorage?.getItem(TRAFFIC_KEY) || null;
  } catch {
    // Storage denied (private mode, blocked cookies): this is a nice-to-have
    // label, never a reason to skip RUM.
    return null;
  }
}

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
 * Whether this page should have RUM at all.
 *
 * Answerable from the meta tags and the hostname alone, which is the point:
 * `faro_gate.js` asks before importing the SDK, so a disabled page never pays
 * for 83 KB of telemetry it will not send. Dev traffic never ships, and a
 * missing collector fails closed.
 *
 * @param {{ location: { hostname: string, protocol: string } }} win - Window-like object.
 * @param {{ querySelector: (selector: string) => ({ content: string } | null) }} doc - Document-like object.
 * @returns {boolean}
 */
export function rumEligible(win, doc) {
  const config = readFaroConfig(doc);
  const { hostname, protocol } = win.location;
  const isLocal = hostname === "localhost" || hostname === "127.0.0.1" || protocol === "file:";

  return config.enabled && !isLocal && Boolean(config.url);
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
 * @param {(attributes: Record<string, string>) => object} [options.createSession] - Faro SDK session factory, used only to label non-organic traffic.
 * @param {Window | { location: { hostname: string, protocol: string } }} options.win - Window-like object.
 * @param {{ querySelector: (selector: string) => ({ content: string } | null) }} options.doc - Document-like object.
 * @returns {{ boot: () => unknown | null }}
 */
export function createFaro({ initializeFaro, buildInstrumentations, createSession, win, doc }) {
  /**
   * Start Faro if the environment and config allow it.
   *
   * @returns {unknown | null} The Faro instance, or null when it did not start.
   */
  function boot() {
    if (!rumEligible(win, doc)) return null;

    const config = readFaroConfig(doc);
    const traffic = trafficKind(win);

    try {
      return initializeFaro({
        url: config.url,
        app: { name: APP_NAME, version: config.version ?? "unknown" },
        instrumentations: buildInstrumentations(),
        // Seeding the session is the only way to attach an attribute to every
        // signal it produces; setting it after boot would leave the first
        // batch unlabelled, which is exactly the ramp-up a load run cares about.
        ...(traffic && createSession
          ? { sessionTracking: { session: createSession({ traffic }) } }
          : {}),
      });
    } catch (error) {
      console.error("[faro] init failed", error);
      return null;
    }
  }

  return { boot };
}

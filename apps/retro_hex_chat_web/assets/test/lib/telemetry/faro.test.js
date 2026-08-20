/**
 * @file Verifies the Grafana Faro RUM bootstrap logic.
 *
 * Covers the gating (localhost short-circuit, disabled flag, missing URL),
 * the config passed to the injected `initializeFaro`, and the swallow-and-log
 * behaviour when the SDK throws. The real Faro SDK is dependency-injected so
 * these cases never load it or touch the network.
 */
import { createFaro, readFaroConfig } from "../../../js/lib/telemetry/faro";

/**
 * Build a stub document whose `querySelector('meta[name="..."]')` resolves
 * from a plain map of meta name → content.
 *
 * @param {Record<string, string>} metas - Meta name/content pairs.
 * @returns {{ querySelector: (selector: string) => ({ content: string } | null) }}
 */
function makeDoc(metas) {
  return {
    querySelector(selector) {
      const match = selector.match(/^meta\[name="(.+)"\]$/);
      if (!match) return null;
      const name = match[1];
      return name in metas ? { content: metas[name] } : null;
    },
  };
}

/**
 * Build a stub window with a controllable location.
 *
 * @param {string} href - Value backing `location`.
 * @returns {{ location: { hostname: string, protocol: string, href: string } }}
 */
function makeWin(href) {
  const url = new URL(href);
  return {
    location: { hostname: url.hostname, protocol: url.protocol, href: url.href },
  };
}

const PROD_METAS = {
  "faro-enabled": "true",
  "faro-collector-url": "/faro/collect",
  "faro-app-version": "1.2.3",
};

/**
 * Assemble a `createFaro` instance with sensible test doubles, overridable
 * per case.
 *
 * @param {object} [overrides]
 * @returns {{ faro: ReturnType<typeof createFaro>, initializeFaro: any, instrumentations: any[] }}
 */
function build({ metas = PROD_METAS, href = "https://retrohexchat.app/chat", initImpl } = {}) {
  const instrumentations = [{ name: "web" }, { name: "tracing" }];
  const initializeFaro = initImpl ? vi.fn(initImpl) : vi.fn().mockReturnValue({ api: {} });
  const faro = createFaro({
    initializeFaro,
    buildInstrumentations: () => instrumentations,
    win: makeWin(href),
    doc: makeDoc(metas),
  });
  return { faro, initializeFaro, instrumentations };
}

describe("readFaroConfig", () => {
  it("reads enabled/url/version from meta tags", () => {
    const cfg = readFaroConfig(makeDoc(PROD_METAS));
    expect(cfg).toEqual({ enabled: true, url: "/faro/collect", version: "1.2.3" });
  });

  it("treats a missing enabled meta as disabled", () => {
    const cfg = readFaroConfig(makeDoc({ "faro-collector-url": "/faro/collect" }));
    expect(cfg.enabled).toBe(false);
  });
});

describe("createFaro.boot", () => {
  it("initializes with the configured url, app name and version", () => {
    const { faro, initializeFaro, instrumentations } = build();

    const result = faro.boot();

    expect(initializeFaro).toHaveBeenCalledTimes(1);
    expect(initializeFaro).toHaveBeenCalledWith({
      url: "/faro/collect",
      app: { name: "retro_hex_chat_web", version: "1.2.3" },
      instrumentations,
    });
    expect(result).not.toBeNull();
  });

  it("does not initialize when disabled", () => {
    const { faro, initializeFaro } = build({
      metas: { ...PROD_METAS, "faro-enabled": "false" },
    });

    expect(faro.boot()).toBeNull();
    expect(initializeFaro).not.toHaveBeenCalled();
  });

  it("does not initialize on localhost", () => {
    const { faro, initializeFaro } = build({ href: "http://localhost:4000/chat" });

    expect(faro.boot()).toBeNull();
    expect(initializeFaro).not.toHaveBeenCalled();
  });

  it("does not initialize on 127.0.0.1", () => {
    const { faro, initializeFaro } = build({ href: "http://127.0.0.1:4000/chat" });

    expect(faro.boot()).toBeNull();
    expect(initializeFaro).not.toHaveBeenCalled();
  });

  it("does not initialize without a collector url", () => {
    const { faro, initializeFaro } = build({
      metas: { "faro-enabled": "true", "faro-app-version": "1.2.3" },
    });

    expect(faro.boot()).toBeNull();
    expect(initializeFaro).not.toHaveBeenCalled();
  });

  it("falls back to an 'unknown' version when the meta is absent", () => {
    const { faro, initializeFaro } = build({
      metas: { "faro-enabled": "true", "faro-collector-url": "/faro/collect" },
    });

    faro.boot();

    expect(initializeFaro.mock.calls[0][0].app.version).toBe("unknown");
  });

  it("catches and logs an SDK failure instead of throwing", () => {
    const error = new Error("boom");
    const { faro } = build({
      initImpl: () => {
        throw error;
      },
    });
    const spy = vi.spyOn(console, "error").mockImplementation(() => {});

    expect(() => faro.boot()).not.toThrow();
    expect(faro.boot()).toBeNull();
    expect(spy).toHaveBeenCalled();

    spy.mockRestore();
  });
});

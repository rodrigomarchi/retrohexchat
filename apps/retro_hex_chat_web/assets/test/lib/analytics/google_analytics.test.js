/**
 * @file Verifies where a page is measured, what reaches gtag, and that an event
 * sent while leaving a page survives the navigation.
 */
import {
  installAnalytics,
  measurementId,
  NEXT_PAGE_KEY,
} from "../../../js/lib/analytics/google_analytics";

const ORIGIN = "https://retrohexchat.app";

/**
 * Build a window and document pair good enough for the installer.
 *
 * @param {object} [options]
 * @param {string} [options.href] - The page's address.
 * @param {string | null} [options.id] - The measurement id in the meta tag.
 * @returns {{ win: EventTarget, doc: object }} The stubs.
 */
function makePage({ href = `${ORIGIN}/`, id = "G-TEST" } = {}) {
  const url = new URL(href);
  const win = new EventTarget();
  const stored = new Map();

  win.location = { href, hostname: url.hostname, protocol: url.protocol, origin: url.origin };
  win.sessionStorage = {
    getItem: (key) => stored.get(key) ?? null,
    setItem: (key, value) => stored.set(key, value),
    removeItem: (key) => stored.delete(key),
  };

  const doc = {
    head: { appendChild: vi.fn() },
    createElement: () => ({}),
    querySelector: () => (id ? { content: id } : null),
  };

  return { win, doc };
}

/**
 * @param {object} win - The stub window.
 * @param {string} name - A gtag command's first argument.
 * @returns {unknown[][]} Every queued command with that first argument.
 */
const commands = (win, name) =>
  win.dataLayer.map((entry) => [...entry]).filter(([command]) => command === name);

const fire = (win, name, detail = {}) => {
  const event = new Event(name);
  event.detail = detail;
  win.dispatchEvent(event);
};

describe("measurementId", () => {
  it("answers with the id on a real page", () => {
    const { win, doc } = makePage();
    expect(measurementId(win, doc)).toBe("G-TEST");
  });

  it("is off without an id and on localhost", () => {
    [makePage({ id: null }), makePage({ href: "http://localhost:4000/" })].forEach((page) => {
      expect(installAnalytics(page)).toBe(false);
      expect(page.win.dataLayer).toBeUndefined();
    });
  });
});

describe("installAnalytics", () => {
  it("configures the tag and fetches it at once", () => {
    const { win, doc } = makePage();
    installAnalytics({ win, doc });

    expect(commands(win, "config")).toEqual([["config", "G-TEST"]]);
    expect(doc.head.appendChild).toHaveBeenCalledTimes(1);
  });

  it("hands the server's events to gtag, and who is visiting to its settings", () => {
    const { win, doc } = makePage();
    installAnalytics({ win, doc });

    fire(win, "phx:analytics", { name: "channel_view", params: { channel: "#lobby" } });
    fire(win, "phx:analytics_user", { member: "yes", user_id: 7 });

    expect(commands(win, "event")).toEqual([["event", "channel_view", { channel: "#lobby" }]]);
    expect(commands(win, "set")).toEqual([
      ["set", { user_id: "7" }],
      ["set", "user_properties", { member: "yes" }],
    ]);
  });

  it("keeps an event sent while leaving for the next page, and sends it once", () => {
    const first = makePage();
    installAnalytics(first);
    fire(first.win, "phx:analytics", {
      name: "sign_up",
      params: { method: "nickname" },
      next_page: true,
    });

    expect(commands(first.win, "event")).toEqual([]);

    const next = makePage();
    next.win.sessionStorage.setItem(NEXT_PAGE_KEY, first.win.sessionStorage.getItem(NEXT_PAGE_KEY));
    installAnalytics(next);

    expect(commands(next.win, "event")).toEqual([["event", "sign_up", { method: "nickname" }]]);
    expect(next.win.sessionStorage.getItem(NEXT_PAGE_KEY)).toBeNull();
  });
});

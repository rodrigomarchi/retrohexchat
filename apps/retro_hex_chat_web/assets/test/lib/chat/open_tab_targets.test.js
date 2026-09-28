import { cleanupDOM } from "../../helpers/hook_helper.js";
import {
  describeTarget,
  gatedAnchor,
  modifiedClick,
} from "../../../js/lib/chat/open_tab_targets.js";

const ORIGIN = "https://retrohexchat.app";

function anchor(html) {
  const host = document.createElement("div");
  host.innerHTML = html;
  document.body.appendChild(host);
  return host.querySelector("a");
}

describe("open_tab_targets", () => {
  afterEach(() => cleanupDOM());

  describe("gatedAnchor", () => {
    it("claims a door the server marked", () => {
      const a = anchor(`<a href="/call/abc" data-confirm-tab="surface">Join</a>`);
      expect(gatedAnchor(a)).toBe(a);
    });

    it("claims a link inside message content by the class the renderers stamp", () => {
      const a = anchor(
        `<a class="chat-link" href="https://x.test" data-url="https://x.test">x</a>`,
      );
      expect(gatedAnchor(a)).toBe(a);
    });

    it("claims it from a click on something inside it", () => {
      const a = anchor(`<a href="/play" data-confirm-tab="surface"><span>Games</span></a>`);
      expect(gatedAnchor(a.querySelector("span"))).toBe(a);
    });

    // The absence of the attribute is the allowlist: help and the project's own
    // GitHub entries were deliberately left out, and that has to keep reading as
    // a decision rather than becoming a gap the gate quietly closes.
    it("leaves an unmarked anchor alone", () => {
      const a = anchor(`<a href="/chat/help" target="_blank">Help</a>`);
      expect(gatedAnchor(a)).toBeNull();
    });

    it("answers null for a target that cannot be asked", () => {
      expect(gatedAnchor(null)).toBeNull();
      expect(gatedAnchor({})).toBeNull();
    });
  });

  describe("modifiedClick", () => {
    it("is true for the modifiers that already mean a new tab", () => {
      for (const key of ["ctrlKey", "metaKey", "shiftKey", "altKey"]) {
        expect(modifiedClick({ button: 0, [key]: true })).toBe(true);
      }
    });

    it("is true for a middle click", () => {
      expect(modifiedClick({ button: 1 })).toBe(true);
    });

    it("is false for a plain left click", () => {
      expect(modifiedClick({ button: 0 })).toBe(false);
    });
  });

  describe("describeTarget", () => {
    it("reads a door of ours as the kind it declared, with its label", () => {
      const a = anchor(
        `<a href="/call/abc" data-confirm-tab="surface" data-confirm-label="Call in #retro">Join</a>`,
      );

      expect(describeTarget(a, ORIGIN)).toEqual({
        url: "/call/abc",
        kind: "surface",
        label: "Call in #retro",
        host: null,
      });
    });

    it("reads an attachment as one", () => {
      const a = anchor(
        `<a href="/chat/attachments/7" data-confirm-tab="attachment" data-confirm-label="holiday.png">f</a>`,
      );

      expect(describeTarget(a, ORIGIN)).toMatchObject({ kind: "attachment", host: null });
    });

    it("reads an off-site link as external and names the host", () => {
      const a = anchor(
        `<a class="chat-link" href="https://tecnoblog.net/a" data-url="https://tecnoblog.net/a">n</a>`,
      );

      expect(describeTarget(a, ORIGIN)).toMatchObject({
        kind: "external",
        host: "tecnoblog.net",
        url: "https://tecnoblog.net/a",
      });
    });

    // The prefix attack, which is why the comparison is on the parsed origin and
    // never on the string. `ShareLinkRef.ours?/1` guards the same shape in Elixir.
    it("reads a host that merely starts with ours as external", () => {
      const evil = "https://retrohexchat.app.evil.example/join/abcdefgh";
      const a = anchor(`<a class="chat-link" href="${evil}" data-url="${evil}">join</a>`);

      expect(describeTarget(a, ORIGIN)).toMatchObject({
        kind: "external",
        host: "retrohexchat.app.evil.example",
      });
    });

    it("reads our own host as not external", () => {
      const ours = `${ORIGIN}/join/abcdefgh`;
      const a = anchor(`<a class="chat-link" href="${ours}" data-url="${ours}">join</a>`);

      expect(describeTarget(a, ORIGIN)).toMatchObject({ kind: "surface", host: null });
    });

    // The arcade: our own path, redirecting to the static host the bundle lives
    // on. The declaration wins over the address, and no host is invented.
    it("honours a declared external on a path of ours, without a host", () => {
      const a = anchor(`<a href="/play/arcade/pong" data-confirm-tab="external">Start</a>`);

      expect(describeTarget(a, ORIGIN)).toMatchObject({
        kind: "external",
        host: null,
        url: "/play/arcade/pong",
      });
    });

    it("settles an unknown declared kind on surface", () => {
      const a = anchor(`<a href="/x" data-confirm-tab="nonsense">x</a>`);
      expect(describeTarget(a, ORIGIN)).toMatchObject({ kind: "surface" });
    });

    it("prefers data-url over href, because the server wrote it", () => {
      const a = anchor(
        `<a class="chat-link" href="https://normalised.test/" data-url="https://raw.test/a?b=1">x</a>`,
      );

      expect(describeTarget(a, ORIGIN).url).toBe("https://raw.test/a?b=1");
    });

    it("answers null when there is nothing to open", () => {
      expect(describeTarget(anchor(`<a data-confirm-tab="surface">x</a>`), ORIGIN)).toBeNull();
      expect(describeTarget(null, ORIGIN)).toBeNull();
    });

    it("answers null for an address that cannot be parsed", () => {
      const a = anchor(`<a data-confirm-tab="surface" data-url="http://[">x</a>`);
      expect(describeTarget(a, ORIGIN)).toBeNull();
    });
  });

  describe("the click a door was going to make", () => {
    it("carries the event and its values", () => {
      const a = anchor(
        `<a href="/play/arcade/pong" data-confirm-tab="external"
            data-confirm-event="arcade_select_game"
            data-confirm-params='{"game-id":"pong"}'>Start</a>`,
      );

      expect(describeTarget(a, ORIGIN)).toMatchObject({
        event: "arcade_select_game",
        params: { "game-id": "pong" },
      });
    });

    it("carries nothing when the door declared nothing", () => {
      const target = describeTarget(
        anchor(`<a href="/x" data-confirm-tab="surface">x</a>`),
        ORIGIN,
      );

      expect(target).not.toHaveProperty("event");
      expect(target).not.toHaveProperty("params");
    });

    it("fires with no values when the params are not an object", () => {
      const a = anchor(
        `<a href="/x" data-confirm-tab="surface" data-confirm-event="e" data-confirm-params="[1,2]">x</a>`,
      );

      expect(describeTarget(a, ORIGIN)).toMatchObject({ event: "e", params: {} });
    });

    it("fires with no values when the params are malformed", () => {
      const a = anchor(
        `<a href="/x" data-confirm-tab="surface" data-confirm-event="e" data-confirm-params="{oops">x</a>`,
      );

      expect(describeTarget(a, ORIGIN)).toMatchObject({ event: "e", params: {} });
    });
  });
});

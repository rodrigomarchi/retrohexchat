import { cleanupDOM } from "../../helpers/hook_helper.js";
import { blockedLink, openPath, parseAllow } from "../../../js/lib/chat/visitor_links.js";

const ORIGIN = "https://retrohexchat.app";
const ALLOW = ["/chat", "/locale/", "/chat/help", "/chat/help/", "/", "/games", "/games/"];

function link(html) {
  const host = document.createElement("div");
  host.innerHTML = html;
  document.body.appendChild(host);
  return host.querySelector("a") || host.firstElementChild;
}

describe("visitor_links", () => {
  afterEach(() => cleanupDOM());

  describe("blockedLink", () => {
    it("holds a game, a call, a space and a private session, naming each and its path", () => {
      expect(blockedLink(link(`<a href="/play/arcade/doom">x</a>`), ORIGIN, ALLOW)).toEqual({
        feature: "games",
        path: "/play/arcade/doom",
      });
      expect(blockedLink(link(`<a href="/play">x</a>`), ORIGIN, ALLOW)).toEqual({
        feature: "games",
        path: "/play",
      });
      expect(blockedLink(link(`<a href="/call/abc?x=1">x</a>`), ORIGIN, ALLOW)).toEqual({
        feature: "calls",
        path: "/call/abc?x=1",
      });
      expect(blockedLink(link(`<a href="/space/xyz">x</a>`), ORIGIN, ALLOW)).toEqual({
        feature: "space",
        path: "/space/xyz",
      });
      expect(blockedLink(link(`<a href="/p2p/tok">x</a>`), ORIGIN, ALLOW)).toEqual({
        feature: "p2p",
        path: "/p2p/tok",
      });
    });

    it("holds another site and an attachment as links", () => {
      const external = link(`<a class="chat-link" href="https://example.com/a">x</a>`);
      expect(blockedLink(external, ORIGIN, ALLOW)).toEqual({ feature: "links" });

      const attachment = link(`<a href="/chat/attachments/9">file</a>`);
      expect(blockedLink(attachment, ORIGIN, ALLOW)).toEqual({ feature: "links" });
    });

    it("holds a click on something inside the link", () => {
      const inner = link(`<a href="/play/tetris"><span id="inner">Play</span></a>`);
      expect(blockedLink(inner.querySelector("#inner"), ORIGIN, ALLOW)).toEqual({
        feature: "games",
        path: "/play/tetris",
      });
    });

    it("lets the open paths through", () => {
      for (const href of [
        "/chat",
        "/chat?join=%23lobby",
        "/chat/help/connecting",
        "/locale/pt_BR",
        "/",
        "/games/tetris",
      ]) {
        expect(blockedLink(link(`<a href="${href}">x</a>`), ORIGIN, ALLOW)).toBeNull();
      }
    });

    it("ignores what is not a link to follow", () => {
      expect(blockedLink(link(`<a href="#top">x</a>`), ORIGIN, ALLOW)).toBeNull();
      expect(blockedLink(link(`<button>x</button>`), ORIGIN, ALLOW)).toBeNull();
      expect(blockedLink(null, ORIGIN, ALLOW)).toBeNull();
    });

    it("holds a lookalike host", () => {
      const lookalike = link(`<a href="https://retrohexchat.app.evil.test/chat">x</a>`);
      expect(blockedLink(lookalike, ORIGIN, ALLOW)).toEqual({ feature: "links" });
    });
  });

  describe("openPath", () => {
    it("opens `/` only for itself", () => {
      expect(openPath("/", ["/"])).toBe(true);
      expect(openPath("/play", ["/"])).toBe(false);
    });

    it("opens an entry without a slash only for itself", () => {
      expect(openPath("/chat", ["/chat"])).toBe(true);
      expect(openPath("/chat/emoji/1", ["/chat"])).toBe(false);
    });
  });

  describe("parseAllow", () => {
    it("reads a list of paths and nothing else", () => {
      expect(parseAllow('["/chat", 3]')).toEqual(["/chat"]);
      expect(parseAllow("{}")).toEqual([]);
      expect(parseAllow("not json")).toEqual([]);
      expect(parseAllow(undefined)).toEqual([]);
    });
  });
});

import {
  isAtBottom,
  shouldLoadMore,
  detectContextTarget,
  buildMessageText,
  collectUrls,
} from "../../js/lib/chat.js";
import "../helpers/hook_helper.js"; // scrollIntoView stub
import { cleanupDOM } from "../helpers/hook_helper.js";

describe("lib/chat", () => {
  afterEach(() => {
    cleanupDOM();
  });

  // ── isAtBottom ─────────────────────────────────────────

  describe("isAtBottom", () => {
    function mockEl(scrollHeight, scrollTop, clientHeight) {
      return { scrollHeight, scrollTop, clientHeight };
    }

    it("returns true when exactly at bottom", () => {
      expect(isAtBottom(mockEl(1000, 800, 200))).toBe(true);
    });

    it("returns true within threshold", () => {
      expect(isAtBottom(mockEl(1000, 770, 200))).toBe(true);
    });

    it("returns false when scrolled up", () => {
      expect(isAtBottom(mockEl(1000, 100, 200))).toBe(false);
    });

    it("uses custom threshold", () => {
      expect(isAtBottom(mockEl(1000, 780, 200), 10)).toBe(false);
      expect(isAtBottom(mockEl(1000, 795, 200), 10)).toBe(true);
    });
  });

  // ── shouldLoadMore ─────────────────────────────────────

  describe("shouldLoadMore", () => {
    it("returns true near top", () => {
      expect(shouldLoadMore(5)).toBe(true);
    });

    it("returns false when away from top", () => {
      expect(shouldLoadMore(100)).toBe(false);
    });

    it("uses custom threshold", () => {
      expect(shouldLoadMore(15, 20)).toBe(true);
      expect(shouldLoadMore(25, 20)).toBe(false);
    });
  });

  // ── detectContextTarget ────────────────────────────────

  describe("detectContextTarget", () => {
    function createMsg(html, dataset = {}) {
      const el = document.createElement("div");
      el.className = "chat-message";
      el.innerHTML = html;
      Object.assign(el.dataset, { author: "Nick", messageId: "1", ...dataset });
      document.body.appendChild(el);
      return el;
    }

    function fakeEvent(target) {
      return { target, clientX: 10, clientY: 20 };
    }

    it("detects nick target (highest priority)", () => {
      const msg = createMsg('<span class="chat-nick" data-nick="Bob">Bob</span>');
      const result = detectContextTarget(fakeEvent(msg.querySelector(".chat-nick")), msg);
      expect(result.type).toBe("nick");
      expect(result.nick).toBe("Bob");
    });

    it("detects URL target", () => {
      const msg = createMsg('<a class="chat-link" data-url="https://x.com">link</a>');
      const result = detectContextTarget(fakeEvent(msg.querySelector(".chat-link")), msg);
      expect(result.type).toBe("url");
      expect(result.url).toBe("https://x.com");
    });

    it("detects channel target", () => {
      const msg = createMsg('<span class="chat-channel-link" data-channel="#test">#test</span>');
      const result = detectContextTarget(fakeEvent(msg.querySelector(".chat-channel-link")), msg);
      expect(result.type).toBe("channel");
      expect(result.channel).toBe("#test");
    });

    it("falls back to message type", () => {
      const msg = createMsg('<span class="chat-content">hello</span>');
      const result = detectContextTarget(fakeEvent(msg.querySelector(".chat-content")), msg);
      expect(result.type).toBe("message");
    });

    it("includes common payload fields", () => {
      const msg = createMsg('<span class="chat-content">hi</span>', {
        author: "Alice",
        messageId: "42",
      });
      const result = detectContextTarget(fakeEvent(msg.querySelector(".chat-content")), msg);
      expect(result.author).toBe("Alice");
      expect(result.message_id).toBe("42");
      expect(result.x).toBe(10);
      expect(result.y).toBe(20);
    });
  });

  // ── buildMessageText ───────────────────────────────────

  describe("buildMessageText", () => {
    it("formats standard message", () => {
      const el = document.createElement("div");
      el.dataset.author = "Alice";
      el.innerHTML = `
        <span class="chat-timestamp">14:30</span>
        <span class="chat-nick">Alice</span>
        <span class="chat-content">hello world</span>
      `;
      expect(buildMessageText(el)).toBe("[14:30] <Alice> hello world");
    });

    it("falls back for non-standard messages", () => {
      const el = document.createElement("div");
      el.textContent = " System   message  ";
      expect(buildMessageText(el)).toBe("System message");
    });
  });

  // ── collectUrls ────────────────────────────────────────

  describe("collectUrls", () => {
    it("collects URLs from links", () => {
      const el = document.createElement("div");
      el.innerHTML =
        '<a class="chat-link" data-url="https://a.com">a</a><a class="chat-link" data-url="https://b.com">b</a>';
      expect(collectUrls(el)).toEqual(["https://a.com", "https://b.com"]);
    });

    it("returns empty for no links", () => {
      const el = document.createElement("div");
      expect(collectUrls(el)).toEqual([]);
    });
  });
});

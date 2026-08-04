import {
  detectContextTarget,
  buildMessageText,
  buildMessageSource,
  collectUrls,
} from "../../../js/lib/chat/chat.js";
import "../../helpers/hook_helper.js"; // scrollIntoView stub
import { cleanupDOM } from "../../helpers/hook_helper.js";

describe("lib/chat", () => {
  afterEach(() => {
    cleanupDOM();
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
      const msg = createMsg(
        `
          <span class="chat-message__time">14:30</span>
          <span class="chat-nick">Alice</span>
          <span class="chat-content">hi</span>
        `,
        {
          author: "Alice",
          messageId: "42",
          messageText: "visible hi",
          messageSourceB64: btoa("**visible** hi"),
          messageFormat: "markdown",
        },
      );
      const result = detectContextTarget(fakeEvent(msg.querySelector(".chat-content")), msg);
      expect(result.author).toBe("Alice");
      expect(result.message_id).toBe("42");
      expect(result.message_text).toBe("[14:30] <Alice> visible hi");
      expect(result.message_source).toBe("**visible** hi");
      expect(result.message_format).toBe("markdown");
      expect(result.x).toBe(10);
      expect(result.y).toBe(20);
    });

    it("prefers the persisted message id over the LiveView DOM id", () => {
      const msg = createMsg('<span class="chat-content">hi</span>', {
        messageId: "chat_messages-42",
        realId: "42",
      });
      const result = detectContextTarget(fakeEvent(msg.querySelector(".chat-content")), msg);
      expect(result.message_id).toBe("42");
    });
  });

  // ── buildMessageText ───────────────────────────────────

  describe("buildMessageText", () => {
    it("formats standard message", () => {
      const el = document.createElement("div");
      el.dataset.author = "Alice";
      el.innerHTML = `
        <span class="chat-message__time">14:30</span>
        <span class="chat-nick">Alice</span>
        <span class="chat-content">hello world</span>
      `;
      expect(buildMessageText(el)).toBe("[14:30] <Alice> hello world");
    });

    it("uses canonical visible message text from the row dataset", () => {
      const el = document.createElement("div");
      el.dataset.author = "Alice";
      el.dataset.messageText = "hello rendered world";
      el.innerHTML = `
        <span class="chat-message__time">14:30</span>
        <span class="chat-nick">Alice</span>
        <span class="chat-content"><strong>hello</strong> rendered world</span>
      `;

      expect(buildMessageText(el)).toBe("[14:30] <Alice> hello rendered world");
    });

    it("falls back for non-standard messages", () => {
      const el = document.createElement("div");
      el.textContent = " System   message  ";
      expect(buildMessageText(el)).toBe("System message");
    });
  });

  // ── buildMessageSource ─────────────────────────────────

  describe("buildMessageSource", () => {
    it("decodes original source content from the row dataset", () => {
      const el = document.createElement("div");
      el.dataset.messageSourceB64 = btoa("**hello** [doc](https://example.com)");

      expect(buildMessageSource(el)).toBe("**hello** [doc](https://example.com)");
    });

    it("uses original source content when available", () => {
      const el = document.createElement("div");
      el.dataset.messageSource = "**hello** [doc](https://example.com)";

      expect(buildMessageSource(el)).toBe("**hello** [doc](https://example.com)");
    });

    it("falls back to visible message text", () => {
      const el = document.createElement("div");
      el.dataset.messageText = "hello doc";

      expect(buildMessageSource(el)).toBe("hello doc");
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

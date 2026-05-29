import { mountHook, simulateEvent, cleanupDOM } from "../../helpers/hook_helper.js";
import ScrollHook from "../../../js/hooks/chat/scroll_hook.js";

describe("ScrollHook", () => {
  let hook;

  beforeEach(() => {
    hook = mountHook(ScrollHook, {
      tag: "div",
      attrs: { id: "chat-messages", style: "height: 200px; overflow: auto;" },
      html: '<div style="height: 500px;">messages</div>',
    });
  });

  afterEach(() => {
    cleanupDOM();
  });

  // ── scroll detection ───────────────────────────────────

  describe("scroll detection", () => {
    it("starts at bottom", () => {
      expect(hook.isAtBottom).toBe(true);
    });

    it("detects not at bottom when scrolled up", () => {
      // Simulate scroll position away from bottom
      Object.defineProperty(hook.el, "scrollHeight", { value: 1000, configurable: true });
      Object.defineProperty(hook.el, "clientHeight", { value: 200, configurable: true });
      Object.defineProperty(hook.el, "scrollTop", {
        value: 100,
        writable: true,
        configurable: true,
      });
      hook.handleScroll();
      expect(hook.isAtBottom).toBe(false);
    });

    it("detects at bottom within threshold", () => {
      Object.defineProperty(hook.el, "scrollHeight", { value: 1000, configurable: true });
      Object.defineProperty(hook.el, "clientHeight", { value: 200, configurable: true });
      Object.defineProperty(hook.el, "scrollTop", {
        value: 770,
        writable: true,
        configurable: true,
      });
      hook.handleScroll();
      expect(hook.isAtBottom).toBe(true);
    });
  });

  // ── load_more ──────────────────────────────────────────

  describe("load_more", () => {
    it("pushes load_more when near top", () => {
      Object.defineProperty(hook.el, "scrollTop", { value: 5, writable: true, configurable: true });
      Object.defineProperty(hook.el, "scrollHeight", { value: 1000, configurable: true });
      Object.defineProperty(hook.el, "clientHeight", { value: 200, configurable: true });
      hook.handleScroll();
      expect(hook.pushEvent).toHaveBeenCalledWith("load_more", {});
    });

    it("does not push load_more when away from top", () => {
      Object.defineProperty(hook.el, "scrollTop", {
        value: 500,
        writable: true,
        configurable: true,
      });
      Object.defineProperty(hook.el, "scrollHeight", { value: 1000, configurable: true });
      Object.defineProperty(hook.el, "clientHeight", { value: 200, configurable: true });
      hook.pushEvent.mockClear();
      hook.handleScroll();
      const loadMoreCalls = hook.pushEvent.mock.calls.filter((c) => c[0] === "load_more");
      expect(loadMoreCalls).toHaveLength(0);
    });
  });

  // ── context menu detection ─────────────────────────────

  describe("context menu detection", () => {
    function createMsgEl(html, dataset = {}) {
      const el = document.createElement("div");
      el.className = "chat-message";
      el.innerHTML = html;
      Object.assign(el.dataset, { author: "TestUser", messageId: "123", ...dataset });
      hook.el.appendChild(el);
      return el;
    }

    it("detects nick context target", () => {
      const msgEl = createMsgEl('<span class="chat-nick" data-nick="Alice">Alice</span>');
      const nickEl = msgEl.querySelector(".chat-nick");
      const fakeEvent = { target: nickEl, clientX: 100, clientY: 200, preventDefault: vi.fn() };

      hook.detectAndPushContextMenu(fakeEvent, msgEl);

      expect(hook.pushEvent).toHaveBeenCalledWith(
        "chat_context_menu",
        expect.objectContaining({ type: "nick", nick: "Alice" }),
      );
    });

    it("detects URL context target", () => {
      const msgEl = createMsgEl('<a class="chat-link" data-url="https://example.com">link</a>');
      const linkEl = msgEl.querySelector(".chat-link");
      const fakeEvent = { target: linkEl, clientX: 100, clientY: 200, preventDefault: vi.fn() };

      hook.detectAndPushContextMenu(fakeEvent, msgEl);

      expect(hook.pushEvent).toHaveBeenCalledWith(
        "chat_context_menu",
        expect.objectContaining({ type: "url", url: "https://example.com" }),
      );
    });

    it("falls back to message type", () => {
      const msgEl = createMsgEl('<span class="chat-content">hello</span>');
      const contentEl = msgEl.querySelector(".chat-content");
      const fakeEvent = { target: contentEl, clientX: 100, clientY: 200, preventDefault: vi.fn() };

      hook.detectAndPushContextMenu(fakeEvent, msgEl);

      expect(hook.pushEvent).toHaveBeenCalledWith(
        "chat_context_menu",
        expect.objectContaining({ type: "message" }),
      );
    });
  });

  // ── buildMessageText ───────────────────────────────────

  describe("buildMessageText", () => {
    it("formats standard message as [HH:MM] <Nick> content", () => {
      const msgEl = document.createElement("div");
      msgEl.dataset.author = "Alice";
      msgEl.innerHTML = `
        <span class="chat-timestamp">14:30</span>
        <span class="chat-nick">Alice</span>
        <span class="chat-content">hello world</span>
      `;
      expect(hook.buildMessageText(msgEl)).toBe("[14:30] <Alice> hello world");
    });

    it("falls back to plain text for non-standard messages", () => {
      const msgEl = document.createElement("div");
      msgEl.textContent = "  System  message  here  ";
      expect(hook.buildMessageText(msgEl)).toBe("System message here");
    });
  });

  // ── collectUrls ────────────────────────────────────────

  describe("collectUrls", () => {
    it("collects URLs from chat-link elements", () => {
      const msgEl = document.createElement("div");
      msgEl.innerHTML = `
        <a class="chat-link" data-url="https://a.com">a</a>
        <a class="chat-link" data-url="https://b.com">b</a>
      `;
      expect(hook.collectUrls(msgEl)).toEqual(["https://a.com", "https://b.com"]);
    });

    it("returns empty array when no URLs", () => {
      const msgEl = document.createElement("div");
      msgEl.textContent = "no links";
      expect(hook.collectUrls(msgEl)).toEqual([]);
    });
  });

  // ── prepend_start ──────────────────────────────────────

  describe("prepend_start", () => {
    it("sets pendingPrepend flag", () => {
      simulateEvent(hook, "prepend_start", {});
      expect(hook.pendingPrepend).toBe(true);
    });
  });

  // ── mutation filtering ─────────────────────────────────

  describe("mutation filtering", () => {
    it("ignores internal search-highlight DOM mutations for auto-scroll", async () => {
      const msgEl = document.createElement("div");
      msgEl.dataset.messageId = "chat_messages-1";
      msgEl.innerHTML = '<span class="chat-content">hello</span>';
      hook.el.appendChild(msgEl);
      await new Promise((resolve) => setTimeout(resolve, 0));

      hook.scrollToBottom = vi.fn();
      msgEl.querySelector(".chat-content").innerHTML =
        '<mark class="search-highlight">hello</mark>';
      await new Promise((resolve) => setTimeout(resolve, 0));

      expect(hook.scrollToBottom).not.toHaveBeenCalled();
    });
  });

  // ── message interaction events ─────────────────────────

  describe("message interaction events", () => {
    it("scrolls to current LiveView message rows", () => {
      const msgEl = document.createElement("div");
      msgEl.id = "chat_messages-123";
      msgEl.scrollIntoView = vi.fn();
      hook.el.appendChild(msgEl);

      simulateEvent(hook, "scroll_to_message", { message_id: 123 });

      expect(msgEl.scrollIntoView).toHaveBeenCalled();
      expect(msgEl.classList.contains("chat-message--scroll-highlight")).toBe(true);
    });

    it("reports missing scroll targets to LiveView", () => {
      simulateEvent(hook, "scroll_to_message", { message_id: 999 });

      expect(hook.pushEvent).toHaveBeenCalledWith("scroll_to_message_missing", {
        message_id: 999,
      });
    });

    it("enters and exits edit mode for current LiveView message rows", () => {
      const input = document.createElement("textarea");
      input.id = "chat-input";
      document.body.appendChild(input);

      const msgEl = document.createElement("div");
      msgEl.id = "chat_messages-123";
      hook.el.appendChild(msgEl);

      simulateEvent(hook, "enter_edit_mode", {
        message_id: 123,
        content: "edit me",
      });

      expect(msgEl.classList.contains("chat-message--editing")).toBe(true);
      expect(input.value).toBe("edit me");
      expect(input.dataset.editMode).toBe("true");
      expect(input.dataset.editMessageId).toBe("123");

      simulateEvent(hook, "exit_edit_mode", { message_id: 123 });

      expect(msgEl.classList.contains("chat-message--editing")).toBe(false);
      expect(input.value).toBe("");
      expect(input.dataset.editMode).toBeUndefined();
      expect(input.dataset.editMessageId).toBeUndefined();
    });
  });
});

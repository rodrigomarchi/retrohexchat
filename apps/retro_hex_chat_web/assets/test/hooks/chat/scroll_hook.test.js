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
    finishInitialScroll(hook);
  });

  afterEach(() => {
    hook?.destroyed?.();
    vi.useRealTimers();
    cleanupDOM();
  });

  function finishInitialScroll(hook) {
    hook.cancelRepin();
    hook.initialScrollPending = false;
  }

  function messageNode(id = "1") {
    const el = document.createElement("div");
    el.dataset.messageId = `chat_messages-${id}`;
    el.textContent = `message ${id}`;
    return el;
  }

  function flushMutations() {
    return new Promise((resolve) => setTimeout(resolve, 0));
  }

  function pointerEvent(type, attrs = {}) {
    const event = new Event(type, { bubbles: true, cancelable: true });
    for (const [key, value] of Object.entries(attrs)) {
      Object.defineProperty(event, key, { value, configurable: true });
    }
    return event;
  }

  // ── scroll detection ───────────────────────────────────

  describe("scroll detection", () => {
    it("starts at bottom", () => {
      expect(hook.isAtBottom).toBe(true);
    });

    it("detects not at bottom when the reader scrolls up", () => {
      // Simulate scroll position away from bottom
      Object.defineProperty(hook.el, "scrollHeight", { value: 1000, configurable: true });
      Object.defineProperty(hook.el, "clientHeight", { value: 200, configurable: true });
      Object.defineProperty(hook.el, "scrollTop", {
        value: 100,
        writable: true,
        configurable: true,
      });
      hook.markUserScrollIntent();
      hook.handleScroll();
      expect(hook.isAtBottom).toBe(false);
      expect(hook.autoScrollPinned).toBe(false);
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
      expect(hook.autoScrollPinned).toBe(true);
    });

    it("does not unpin live auto-scroll for non-user scroll/layout movement", () => {
      Object.defineProperty(hook.el, "scrollHeight", { value: 1000, configurable: true });
      Object.defineProperty(hook.el, "clientHeight", { value: 200, configurable: true });
      Object.defineProperty(hook.el, "scrollTop", {
        value: 100,
        writable: true,
        configurable: true,
      });
      hook.autoScrollPinned = true;
      hook.userScrollIntent = false;
      hook.scrollToBottom = vi.fn();

      hook.handleScroll();

      expect(hook.scrollToBottom).toHaveBeenCalled();
      expect(hook.autoScrollPinned).toBe(true);
    });
  });

  // ── initial scroll settling ────────────────────────────

  describe("initial scroll settling", () => {
    it("keeps initial stream mutations pinned to bottom without showing new messages", async () => {
      hook.initialScrollPending = true;
      hook.isAtBottom = false;

      hook.el.appendChild(messageNode("initial"));
      await flushMutations();

      expect(hook.isAtBottom).toBe(true);
      expect(document.querySelector(".new-messages-btn")).toBeNull();
    });

    it("does not trigger load_more while the initial scroll is settling", () => {
      hook.initialScrollPending = true;
      hook.pushEvent.mockClear();
      Object.defineProperty(hook.el, "scrollTop", { value: 5, writable: true, configurable: true });

      hook.handleScroll();

      expect(hook.pushEvent).not.toHaveBeenCalledWith("load_more", {});
    });

    it("scrolls stream resets to bottom instead of showing new messages", async () => {
      hook.el.appendChild(messageNode("old"));
      await flushMutations();
      hook.isAtBottom = false;

      hook.el.replaceChildren(messageNode("new"));
      await flushMutations();

      expect(hook.isAtBottom).toBe(true);
      expect(document.querySelector(".new-messages-btn")).toBeNull();
    });

    it("keeps live messages pinned when the reader has not scrolled up", async () => {
      hook.autoScrollPinned = true;
      hook.isAtBottom = false;
      hook.scrollToBottom = vi.fn();

      hook.el.appendChild(messageNode("live"));
      await flushMutations();

      expect(hook.scrollToBottom).toHaveBeenCalled();
      expect(document.querySelector(".new-messages-btn")).toBeNull();
    });

    it("does not auto-scroll or show a button when a live message arrives after user scroll-up", async () => {
      hook.autoScrollPinned = false;
      hook.isAtBottom = false;
      hook.scrollToBottom = vi.fn();

      hook.el.appendChild(messageNode("live"));
      await flushMutations();

      expect(hook.scrollToBottom).not.toHaveBeenCalled();
      expect(document.querySelector(".new-messages-btn")).toBeNull();
    });

    it("resettles to bottom when the hidden chat viewport becomes visible again", () => {
      const hiddenParent = document.createElement("div");
      hiddenParent.className = "hidden";
      document.body.appendChild(hiddenParent);
      hiddenParent.appendChild(hook.el);
      hook.wasHidden = true;
      const repin = vi.spyOn(hook, "repinToBottom");

      hiddenParent.className = "";
      hook.updated();

      expect(repin).toHaveBeenCalled();
      expect(hook.isAtBottom).toBe(true);
    });
  });

  // ── load_more ──────────────────────────────────────────

  describe("load_more", () => {
    it("pushes load_more when near top", () => {
      Object.defineProperty(hook.el, "scrollTop", { value: 5, writable: true, configurable: true });
      Object.defineProperty(hook.el, "scrollHeight", { value: 1000, configurable: true });
      Object.defineProperty(hook.el, "clientHeight", { value: 200, configurable: true });
      hook.markUserScrollIntent();
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

    it("opens the same message context menu from a touch long press", () => {
      vi.useFakeTimers();
      const msgEl = createMsgEl('<span class="chat-nick" data-nick="Alice">Alice</span>');
      const nickEl = msgEl.querySelector(".chat-nick");

      nickEl.dispatchEvent(
        pointerEvent("pointerdown", {
          pointerType: "touch",
          button: 0,
          clientX: 33,
          clientY: 77,
        }),
      );
      vi.advanceTimersByTime(550);

      expect(hook.pushEvent).toHaveBeenCalledWith(
        "chat_context_menu",
        expect.objectContaining({ type: "nick", nick: "Alice", x: 33, y: 77 }),
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

  // ── link previews ──────────────────────────────────────

  describe("link previews", () => {
    // jsdom has no CSS.escape; the handler uses it to build the href selector.
    globalThis.CSS = globalThis.CSS ?? { escape: (s) => String(s) };

    function linkNode(url) {
      const link = document.createElement("a");
      link.className = "chat-link";
      link.href = url;
      link.textContent = url;
      hook.el.appendChild(link);
      return link;
    }

    it("re-pins to bottom after a preview grows the row while at bottom", () => {
      linkNode("https://example.com/");
      hook.isAtBottom = true;
      hook.scrollToBottom = vi.fn();

      simulateEvent(hook, "link_preview", { url: "https://example.com/", title: "Example" });

      expect(hook.scrollToBottom).toHaveBeenCalled();
    });

    it("does not re-pin when the reader is scrolled up", () => {
      linkNode("https://example.com/");
      hook.autoScrollPinned = false;
      hook.scrollToBottom = vi.fn();

      simulateEvent(hook, "link_preview", { url: "https://example.com/", title: "Example" });

      expect(hook.scrollToBottom).not.toHaveBeenCalled();
    });
  });

  // ── resize pinning ─────────────────────────────────────

  describe("resize pinning", () => {
    let roCallback;
    let observed;

    function mountWithResizeObserver() {
      roCallback = null;
      observed = new Set();
      globalThis.ResizeObserver = class {
        constructor(cb) {
          roCallback = cb;
        }
        observe(el) {
          observed.add(el);
        }
        unobserve(el) {
          observed.delete(el);
        }
        disconnect() {
          observed.clear();
        }
      };

      const h = mountHook(ScrollHook, {
        tag: "div",
        attrs: { id: "chat-messages", style: "height: 200px; overflow: auto;" },
        html: "",
      });
      h.cancelRepin();
      h.initialScrollPending = false;
      return h;
    }

    afterEach(() => {
      delete globalThis.ResizeObserver;
    });

    it("observes the scroll container so panel resizes can re-pin", () => {
      const h = mountWithResizeObserver();
      expect(observed.has(h.el)).toBe(true);
      h.destroyed?.();
    });

    it("re-pins to bottom on resize while the reader is at the bottom", () => {
      const h = mountWithResizeObserver();
      h.isAtBottom = true;
      h.scrollToBottom = vi.fn();

      roCallback();

      expect(h.scrollToBottom).toHaveBeenCalled();
      h.destroyed?.();
    });

    it("does not re-pin on resize when the reader has scrolled up", () => {
      const h = mountWithResizeObserver();
      h.autoScrollPinned = false;
      h.scrollToBottom = vi.fn();

      roCallback();

      expect(h.scrollToBottom).not.toHaveBeenCalled();
      h.destroyed?.();
    });

    it("does not re-pin on resize during a prepend of older messages", () => {
      const h = mountWithResizeObserver();
      h.isAtBottom = true;
      h.pendingPrepend = true;
      h.scrollToBottom = vi.fn();

      roCallback();

      expect(h.scrollToBottom).not.toHaveBeenCalled();
      h.destroyed?.();
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

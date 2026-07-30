import { mountHook, simulateEvent, cleanupDOM } from "../../helpers/hook_helper.js";
import ChatViewportHook from "../../../js/hooks/chat/chat_viewport_hook.js";

describe("ChatViewportHook", () => {
  let hook;
  let scroller;
  let stream;
  let pinnedObserver;

  function setGeometry({ scrollHeight, clientHeight = 500, scrollTop = 0 }) {
    Object.defineProperty(scroller, "scrollHeight", {
      value: scrollHeight,
      configurable: true,
    });
    Object.defineProperty(scroller, "clientHeight", {
      value: clientHeight,
      configurable: true,
    });
    Object.defineProperty(scroller, "scrollTop", {
      value: scrollTop,
      writable: true,
      configurable: true,
    });
  }

  function addRow(id) {
    const row = document.createElement("div");
    row.dataset.messageId = `chat_messages-${id}`;
    stream.appendChild(row);
  }

  function flushMutations() {
    return new Promise((resolve) => setTimeout(resolve, 0));
  }

  beforeEach(() => {
    window.IntersectionObserver = class {
      constructor(callback) {
        this.callback = callback;
        this.targets = new Set();
        pinnedObserver = this;
      }
      observe(el) {
        this.targets.add(el);
      }
      unobserve(el) {
        this.targets.delete(el);
      }
      disconnect() {
        this.targets.clear();
      }
      report(isIntersecting) {
        this.callback([...this.targets].map((target) => ({ target, isIntersecting })));
      }
    };

    document.body.innerHTML = `
      <div id="chat-messages" data-chat-scroller>
        <div id="chat-load-older"></div>
        <div id="chat-message-stream"></div>
        <div id="chat-bottom-anchor"></div>
      </div>
    `;

    scroller = document.getElementById("chat-messages");
    stream = document.getElementById("chat-message-stream");
    setGeometry({ scrollHeight: 2000, scrollTop: 1500 });

    hook = mountHook(ChatViewportHook, { attrs: { id: "chat-viewport-driver" } });
  });

  afterEach(() => {
    hook?.destroyed?.();
    cleanupDOM();
    delete window.IntersectionObserver;
  });

  // ── staying on the newest message ──────────────────────

  it("follows a line that arrives while the reader is at the end", async () => {
    pinnedObserver.report(true);
    setGeometry({ scrollHeight: 2400, scrollTop: 1500 });

    addRow("live");
    await flushMutations();

    expect(scroller.scrollTop).toBe(2400);
  });

  it("leaves a reader who has scrolled away from the end alone", async () => {
    pinnedObserver.report(false);
    setGeometry({ scrollHeight: 2400, scrollTop: 400 });

    addRow("live");
    await flushMutations();

    expect(scroller.scrollTop).toBe(400);
  });

  // ── paging back ────────────────────────────────────────

  // The distance from the end is what a prepended page must not change, and it
  // is measurable without knowing anything about how the page reached the DOM:
  // how many patches it took, or when the heights were read.
  it("holds the reader's distance from the end when older messages arrive", async () => {
    pinnedObserver.report(false);
    setGeometry({ scrollHeight: 2000, scrollTop: 300 });

    simulateEvent(hook, "prepend_start", {});
    setGeometry({ scrollHeight: 5000, scrollTop: 300 });

    addRow("older");
    await flushMutations();

    // 2000 - 300 = 1700 from the end before; 5000 - 3300 = 1700 after.
    expect(scroller.scrollTop).toBe(3300);
  });

  it("does not treat the page after a prepend as another prepend", async () => {
    pinnedObserver.report(false);
    setGeometry({ scrollHeight: 2000, scrollTop: 300 });

    simulateEvent(hook, "prepend_start", {});
    setGeometry({ scrollHeight: 5000, scrollTop: 300 });
    addRow("older");
    await flushMutations();

    setGeometry({ scrollHeight: 5400, scrollTop: 3300 });
    addRow("live-after");
    await flushMutations();

    expect(scroller.scrollTop).toBe(3300);
  });

  // ── a new list ─────────────────────────────────────────

  it("goes to the newest message when the server says the list was replaced", () => {
    pinnedObserver.report(false);
    setGeometry({ scrollHeight: 3000, scrollTop: 100 });

    simulateEvent(hook, "chat_scroll_reset", {});

    expect(scroller.scrollTop).toBe(3000);
  });

  it("drops a prepend still in flight when the list is replaced", async () => {
    pinnedObserver.report(false);
    setGeometry({ scrollHeight: 2000, scrollTop: 300 });
    simulateEvent(hook, "prepend_start", {});

    setGeometry({ scrollHeight: 3000, scrollTop: 3000 });
    simulateEvent(hook, "chat_scroll_reset", {});

    addRow("fresh");
    await flushMutations();

    expect(scroller.scrollTop).toBe(3000);
  });

  // ── interactions push from the driver, never from the scroller ──

  it("pushes on the reader's behalf without touching the scrolling element", () => {
    const msg = document.createElement("div");
    msg.className = "chat-message";
    msg.dataset.author = "Alice";
    msg.dataset.messageId = "7";
    msg.innerHTML = '<span class="chat-content">hello</span>';
    stream.appendChild(msg);

    msg
      .querySelector(".chat-content")
      .dispatchEvent(new MouseEvent("contextmenu", { bubbles: true, cancelable: true }));

    expect(hook.pushEvent).toHaveBeenCalledWith(
      "chat_context_menu",
      expect.objectContaining({ type: "message" }),
    );
    expect(hook.el.id).toBe("chat-viewport-driver");
    expect(scroller.contains(hook.el)).toBe(false);
  });
});

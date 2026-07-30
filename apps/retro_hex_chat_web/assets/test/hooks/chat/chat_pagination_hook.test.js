import { mountHook, cleanupDOM } from "../../helpers/hook_helper.js";
import ChatPaginationHook from "../../../js/hooks/chat/chat_pagination_hook.js";

describe("ChatPaginationHook", () => {
  let hook;
  let observers;

  beforeEach(() => {
    observers = [];

    // jsdom has no IntersectionObserver; this stand-in lets a test say "the
    // sentinel came into view" without pretending to lay anything out.
    window.IntersectionObserver = class {
      constructor(callback, options) {
        this.callback = callback;
        this.options = options;
        this.targets = new Set();
        observers.push(this);
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
      enter() {
        this.callback([...this.targets].map((target) => ({ target, isIntersecting: true })));
      }
    };

    const scroller = document.createElement("div");
    scroller.setAttribute("data-chat-scroller", "");
    document.body.appendChild(scroller);

    hook = mountHook(ChatPaginationHook, {
      attrs: { id: "chat-load-older", "data-has-more": "true" },
      parent: scroller,
    });

    // The shared mock drops the reply callback; pagination needs it to re-arm.
    hook.__replies = [];
    hook.pushEvent = vi.fn((event, payload, onReply) => {
      hook.__pushEvents.push({ event, payload });
      hook.__replies.push(onReply);
    });
  });

  afterEach(() => {
    hook?.destroyed?.();
    cleanupDOM();
    delete window.IntersectionObserver;
  });

  function loadMoreCalls() {
    return hook.__pushEvents.filter((e) => e.event === "load_more");
  }

  it("asks for a page when the sentinel comes into view", () => {
    observers[0].enter();

    expect(loadMoreCalls()).toHaveLength(1);
  });

  it("watches the scroller, a screenful ahead of the top", () => {
    expect(observers[0].options.root).toBe(hook.el.parentElement);
    expect(observers[0].options.rootMargin).toBe("400px 0px 0px 0px");
  });

  it("stays quiet once the server says there is no more history", () => {
    hook.el.dataset.hasMore = "false";

    observers[0].enter();

    expect(loadMoreCalls()).toHaveLength(0);
  });

  // A sentinel sitting inside the lead distance is reported once, so without
  // the re-arm below a scrollback would stop one page short of where the reader
  // was heading.
  it("asks for one page at a time and re-arms on the reply", () => {
    observers[0].enter();
    observers[0].enter();
    observers[0].enter();
    expect(loadMoreCalls()).toHaveLength(1);

    hook.__replies[0]();
    expect(observers[0].targets.has(hook.el)).toBe(true);

    observers[0].enter();
    expect(loadMoreCalls()).toHaveLength(2);
  });
});

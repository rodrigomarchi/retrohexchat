import { beforeEach, describe, expect, it, vi } from "vitest";

import { SWIPE_REPLY_PX, createSwipeReply, swipeIntent } from "../../../js/lib/chat/swipe_reply.js";

describe("swipeIntent", () => {
  it("waits until the finger has gone somewhere", () => {
    expect(swipeIntent(4, 3)).toBe("undecided");
  });

  it("leaves a mostly vertical drag to the scroll", () => {
    expect(swipeIntent(14, 30)).toBe("scroll");
  });

  it("follows a drag to the right", () => {
    expect(swipeIntent(20, 4)).toBe("swipe");
  });

  it("ignores a drag to the left", () => {
    expect(swipeIntent(-20, 2)).toBe("scroll");
  });
});

function touch(type, x, y, target) {
  const event = new Event(type, { bubbles: true, cancelable: true });
  Object.assign(event, { pointerType: "touch", clientX: x, clientY: y, button: 0 });
  target.dispatchEvent(event);
  return event;
}

describe("createSwipeReply", () => {
  let root;
  let row;
  let onReply;
  let swipe;

  beforeEach(() => {
    document.body.innerHTML = `
      <div id="list">
        <div class="chat-message chat-message--message" data-real-id="42"><span class="chat-content">hi</span></div>
        <div class="chat-message chat-message--action" data-real-id="43">waves</div>
        <div class="chat-message chat-message--message chat-message--deleted" data-real-id="44">gone</div>
        <div class="chat-message" data-real-id="system-1" data-system-message="true">joined</div>
      </div>`;
    root = document.getElementById("list");
    row = root.querySelector('[data-real-id="42"]');
    onReply = vi.fn();
    swipe = createSwipeReply(root, { onReply });
    swipe.mount();
  });

  it("answers the line once it is dragged past the threshold", () => {
    const text = row.querySelector(".chat-content");
    touch("pointerdown", 10, 100, text);
    touch("pointermove", 10 + SWIPE_REPLY_PX + 5, 104, text);
    expect(row.classList.contains("chat-message--swiping")).toBe(true);
    touch("pointerup", 10 + SWIPE_REPLY_PX + 5, 104, text);

    expect(onReply).toHaveBeenCalledWith(row);
    expect(row.classList.contains("chat-message--swiping")).toBe(false);
    expect(row.style.getPropertyValue("--swipe-x")).toBe("");
  });

  it("lets go without answering when the drag stops short", () => {
    touch("pointerdown", 10, 100, row);
    touch("pointermove", 10 + SWIPE_REPLY_PX - 10, 100, row);
    touch("pointerup", 10 + SWIPE_REPLY_PX - 10, 100, row);

    expect(onReply).not.toHaveBeenCalled();
  });

  it("never answers an action or a deleted line", () => {
    for (const id of ["43", "44"]) {
      const line = root.querySelector(`[data-real-id="${id}"]`);
      touch("pointerdown", 10, 100, line);
      touch("pointermove", 10 + SWIPE_REPLY_PX + 5, 100, line);
      touch("pointerup", 10 + SWIPE_REPLY_PX + 5, 100, line);
    }

    expect(onReply).not.toHaveBeenCalled();
  });

  it("never answers a line that is narration", () => {
    const narration = root.querySelector('[data-system-message="true"]');
    touch("pointerdown", 10, 100, narration);
    touch("pointermove", 10 + SWIPE_REPLY_PX + 5, 100, narration);
    touch("pointerup", 10 + SWIPE_REPLY_PX + 5, 100, narration);

    expect(onReply).not.toHaveBeenCalled();
  });

  it("is a mouse-free gesture: a mouse drag does nothing", () => {
    const down = new Event("pointerdown", { bubbles: true });
    Object.assign(down, { pointerType: "mouse", clientX: 10, clientY: 100, button: 0 });
    row.dispatchEvent(down);
    touch("pointermove", 10 + SWIPE_REPLY_PX + 5, 100, row);
    touch("pointerup", 10 + SWIPE_REPLY_PX + 5, 100, row);

    expect(onReply).not.toHaveBeenCalled();
  });

  it("stops listening once destroyed", () => {
    swipe.destroy();
    touch("pointerdown", 10, 100, row);
    touch("pointermove", 10 + SWIPE_REPLY_PX + 5, 100, row);
    touch("pointerup", 10 + SWIPE_REPLY_PX + 5, 100, row);

    expect(onReply).not.toHaveBeenCalled();
  });
});

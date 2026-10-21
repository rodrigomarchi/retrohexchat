import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  applyRovingFocus,
  createMessageKeyboard,
  isContextMenuKey,
  nextRow,
} from "../../../js/lib/chat/message_keyboard.js";

// A row as the viewport draws one: the line, its reaction smiley with the
// picks inside a popover, and a link in the text.
function row(id) {
  const el = document.createElement("div");
  el.className = "chat-message";
  el.id = id;
  el.innerHTML = `
    <details data-popover>
      <summary data-testid="trigger-${id}">:)</summary>
      <div data-popover-panel><button type="button" data-testid="pick-${id}">+1</button></div>
    </details>
    <a href="https://example.com" data-testid="link-${id}">link</a>
    <audio controls data-testid="audio-${id}"></audio>`;
  return el;
}

function harness(count = 3) {
  const scroller = document.createElement("div");
  const stream = document.createElement("div");
  scroller.appendChild(stream);
  document.body.appendChild(scroller);
  const rows = Array.from({ length: count }, (_v, i) => row(`m${i}`));
  rows.forEach((r) => stream.appendChild(r));
  return { scroller, stream, rows };
}

function key(target, keyName, init = {}) {
  const event = new KeyboardEvent("keydown", { key: keyName, bubbles: true, ...init });
  target.dispatchEvent(event);
  return event;
}

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

afterEach(() => {
  document.body.innerHTML = "";
});

describe("nextRow", () => {
  const rows = ["a", "b", "c"];

  it("moves one line up and down", () => {
    expect(nextRow(rows, "b", "ArrowUp")).toBe("a");
    expect(nextRow(rows, "b", "ArrowDown")).toBe("c");
  });

  // A conversation has a first and a last line; wrapping from the newest to
  // the oldest would throw the reader to the top of the history.
  it("stops at both ends instead of wrapping", () => {
    expect(nextRow(rows, "a", "ArrowUp")).toBeNull();
    expect(nextRow(rows, "c", "ArrowDown")).toBeNull();
  });

  it("jumps to the first and the last line", () => {
    expect(nextRow(rows, "b", "Home")).toBe("a");
    expect(nextRow(rows, "b", "End")).toBe("c");
  });

  it("ignores any other key", () => {
    expect(nextRow(rows, "b", "x")).toBeNull();
  });
});

describe("isContextMenuKey", () => {
  it("knows the Menu key and Shift+F10", () => {
    expect(isContextMenuKey({ key: "ContextMenu" })).toBe(true);
    expect(isContextMenuKey({ key: "F10", shiftKey: true })).toBe(true);
    expect(isContextMenuKey({ key: "F10", shiftKey: false })).toBe(false);
  });
});

describe("applyRovingFocus", () => {
  it("gives one row the Tab stop and parks every other row's controls", () => {
    const { rows } = harness();

    applyRovingFocus(rows, rows[2]);

    expect(rows.map((r) => r.getAttribute("tabindex"))).toEqual(["-1", "-1", "0"]);
    expect(rows[0].querySelector("summary").getAttribute("tabindex")).toBe("-1");
    expect(rows[0].querySelector("a").getAttribute("tabindex")).toBe("-1");
    expect(rows[2].querySelector("summary").hasAttribute("tabindex")).toBe(false);
    expect(rows[2].querySelector("a").hasAttribute("tabindex")).toBe(false);
  });

  it("gives a control back the tabindex the server gave it", () => {
    const { rows } = harness(2);
    rows[0].querySelector("a").setAttribute("tabindex", "2");

    applyRovingFocus(rows, rows[1]);
    applyRovingFocus(rows, rows[0]);

    expect(rows[0].querySelector("a").getAttribute("tabindex")).toBe("2");
    expect(rows[1].querySelector("a").getAttribute("tabindex")).toBe("-1");
  });

  // A smiley opened with the mouse on a row that is not the current one must
  // still let the keyboard reach its picks.
  it("leaves the picks of an open popover reachable on any row", () => {
    const { rows } = harness(2);
    rows[0].querySelector("details").open = true;

    applyRovingFocus(rows, rows[1]);

    expect(rows[0].querySelector("[data-popover-panel] button").hasAttribute("tabindex")).toBe(
      false,
    );
  });
});

describe("createMessageKeyboard", () => {
  let h;
  let keyboard;

  beforeEach(() => {
    h = harness();
    keyboard = createMessageKeyboard(h.scroller, h.stream);
  });

  afterEach(() => keyboard.destroy());

  it("makes the newest line the conversation's Tab stop", () => {
    expect(h.rows[2].getAttribute("tabindex")).toBe("0");
    expect(h.rows[0].getAttribute("tabindex")).toBe("-1");
  });

  it("moves between lines with the arrows", () => {
    h.rows[2].focus();

    key(h.rows[2], "ArrowUp");

    expect(document.activeElement).toBe(h.rows[1]);
    expect(h.rows[1].getAttribute("tabindex")).toBe("0");
    expect(h.rows[2].getAttribute("tabindex")).toBe("-1");
  });

  it("opens the line's reactions with Enter and puts the focus on a pick", () => {
    h.rows[2].focus();

    key(h.rows[2], "Enter");

    expect(h.rows[2].querySelector("details").open).toBe(true);
    expect(document.activeElement).toBe(h.rows[2].querySelector("[data-popover-panel] button"));
  });

  it("opens the context menu from the keyboard as a right-click would", () => {
    const opened = vi.fn();
    h.scroller.addEventListener("contextmenu", opened);
    h.rows[1].focus();

    key(h.rows[1], "F10", { shiftKey: true });

    expect(opened).toHaveBeenCalledTimes(1);
    expect(opened.mock.calls[0][0].target).toBe(h.rows[1]);
  });

  // A line's Escape must not also reach the window manager listening on the
  // document, which would close whatever window is in front.
  it("keeps the line's Escape from reaching the rest of the page", () => {
    const outside = vi.fn();
    document.addEventListener("keydown", outside);
    const link = h.rows[2].querySelector("a");
    link.focus();

    key(link, "Escape");

    expect(outside).not.toHaveBeenCalled();
    document.removeEventListener("keydown", outside);
  });

  it("leaves keys with Ctrl, Alt or Cmd to the browser", () => {
    h.rows[2].focus();

    const event = key(h.rows[2], "ArrowUp", { ctrlKey: true });

    expect(event.defaultPrevented).toBe(false);
    expect(document.activeElement).toBe(h.rows[2]);
  });

  it("leaves Shift+Arrow to the browser, for selecting text", () => {
    h.rows[2].focus();

    const event = key(h.rows[2], "ArrowUp", { shiftKey: true });

    expect(event.defaultPrevented).toBe(false);
  });

  it("parks a voice message's player like any other control", () => {
    expect(h.rows[0].querySelector("audio").getAttribute("tabindex")).toBe("-1");
    expect(h.rows[2].querySelector("audio").hasAttribute("tabindex")).toBe(false);
  });

  // Some browsers follow Shift+F10 or the Menu key with a contextmenu event of
  // their own; the menu is opened once.
  it("drops the browser's own menu event that follows a keyboard-opened one", () => {
    const opened = vi.fn();
    h.scroller.parentElement.addEventListener("contextmenu", opened);
    h.rows[1].focus();
    key(h.rows[1], "F10", { shiftKey: true });

    h.rows[1].dispatchEvent(new MouseEvent("contextmenu", { bubbles: true, cancelable: true }));

    expect(opened).toHaveBeenCalledTimes(1);
  });

  it("only touches the rows a patch changed", async () => {
    const untouched = h.rows[0];
    const spy = vi.spyOn(untouched, "querySelectorAll");

    h.rows[1].querySelector("a").setAttribute("tabindex", "0");
    await flush();

    expect(spy).not.toHaveBeenCalled();
    expect(h.rows[1].querySelector("a").getAttribute("tabindex")).toBe("-1");
  });

  it("returns from a control to its line with Escape", () => {
    const link = h.rows[2].querySelector("a");
    link.focus();

    key(link, "Escape");

    expect(document.activeElement).toBe(h.rows[2]);
  });

  it("follows the focus a click put on another line", () => {
    h.rows[0].querySelector("summary").focus();

    expect(h.rows[0].getAttribute("tabindex")).toBe("0");
    expect(h.rows[2].getAttribute("tabindex")).toBe("-1");
  });

  // LiveView re-renders a changed row from the server, which drops what was
  // set here; the observer puts it back.
  it("re-applies itself after a row is re-rendered", async () => {
    const fresh = row("m1");
    h.stream.replaceChild(fresh, h.rows[1]);
    await flush();

    expect(fresh.getAttribute("tabindex")).toBe("-1");
    expect(fresh.querySelector("a").getAttribute("tabindex")).toBe("-1");
  });

  it("rides the newest line while the reader is elsewhere", async () => {
    const newest = row("m3");
    h.stream.appendChild(newest);
    await flush();

    expect(newest.getAttribute("tabindex")).toBe("0");
    expect(h.rows[2].getAttribute("tabindex")).toBe("-1");
  });

  it("keeps the reader's line while they are on it", async () => {
    h.rows[2].focus();
    key(h.rows[2], "ArrowUp");
    h.stream.appendChild(row("m3"));
    await flush();

    expect(h.rows[1].getAttribute("tabindex")).toBe("0");
  });

  it("hands the Tab stop to the new newest line when the current one goes", async () => {
    h.rows[2].remove();
    await flush();

    expect(h.rows[1].getAttribute("tabindex")).toBe("0");
  });
});

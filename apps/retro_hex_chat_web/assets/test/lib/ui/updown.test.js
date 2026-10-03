import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { installUpDown, stepNumberField } from "../../../js/lib/ui/updown";

describe("updown", () => {
  let uninstall;
  let input;
  let up;
  let down;
  let events;

  beforeEach(() => {
    vi.useFakeTimers();
    document.body.innerHTML = `
      <form id="form">
        <span data-updown>
          <input type="number" name="n" value="5" min="1" max="7" />
          <span>
            <button type="button" data-updown-step="up"></button>
            <button type="button" data-updown-step="down"></button>
          </span>
        </span>
      </form>
    `;
    input = document.querySelector("input");
    [up, down] = document.querySelectorAll("button");
    events = [];
    document.getElementById("form").addEventListener("input", () => events.push("input"));
    document.getElementById("form").addEventListener("change", () => events.push("change"));
    uninstall = installUpDown(document, window);
  });

  afterEach(() => {
    uninstall();
    vi.useRealTimers();
    document.body.innerHTML = "";
  });

  const press = (button) =>
    button.dispatchEvent(
      new MouseEvent("pointerdown", { bubbles: true, cancelable: true, button: 0 }),
    );
  const release = (button) => button.dispatchEvent(new MouseEvent("pointerup", { bubbles: true }));

  it("steps the field once per press and tells the form, as typing would", () => {
    press(up);
    release(up);
    expect(input.value).toBe("6");
    expect(events).toEqual(["input", "change"]);

    press(down);
    release(down);
    expect(input.value).toBe("5");
  });

  it("keeps the focus where it was: the press is cancelled before it can move it", () => {
    const event = new MouseEvent("pointerdown", { bubbles: true, cancelable: true, button: 0 });
    up.dispatchEvent(event);
    expect(event.defaultPrevented).toBe(true);
  });

  it("repeats while held and stops at the bound", () => {
    press(up);
    vi.advanceTimersByTime(399);
    expect(input.value).toBe("6");

    vi.advanceTimersByTime(1000);
    expect(input.value).toBe("7");
    expect(vi.getTimerCount()).toBe(0);
  });

  it("stops repeating on release", () => {
    input.max = "100";
    press(up);
    release(up);
    vi.advanceTimersByTime(2000);
    expect(input.value).toBe("6");
  });

  it("does nothing for a disabled field or button, and fires nothing at a bound", () => {
    input.disabled = true;
    press(up);
    expect(input.value).toBe("5");

    input.disabled = false;
    up.disabled = true;
    press(up);
    expect(input.value).toBe("5");

    input.value = "7";
    expect(stepNumberField(input, "up")).toBe(false);
    expect(events).toEqual([]);
  });

  it("ignores a secondary button", () => {
    up.dispatchEvent(new MouseEvent("pointerdown", { bubbles: true, cancelable: true, button: 2 }));
    expect(input.value).toBe("5");
  });
});

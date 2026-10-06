import { describe, it, expect, beforeEach, vi } from "vitest";
import {
  POPOVER_CLOSE_EVENT,
  installPopoverBehaviour,
  keepDisclosureStateAcrossPatch,
  nextMenuRow,
  panelPosition,
  popoversOutside,
} from "../../../js/lib/ui/popover";

function popover(id) {
  const details = document.createElement("details");
  details.dataset.popover = "";
  details.id = id;
  details.innerHTML = `<summary>t</summary><div><button type="button">act</button></div>`;
  document.body.appendChild(details);
  return details;
}

describe("ui/popover", () => {
  beforeEach(() => {
    document.body.innerHTML = "";
    installPopoverBehaviour(document);
  });

  it("carries an open disclosure into its patch, and a closed one stays closed", () => {
    const from = document.createElement("details");
    const to = document.createElement("details");

    from.open = true;
    keepDisclosureStateAcrossPatch(from, to);
    expect(to.open).toBe(true);

    from.open = false;
    to.open = true;
    keepDisclosureStateAcrossPatch(from, to);
    expect(to.open).toBe(false);
  });

  it("keeps the position the browser gave an open panel", () => {
    const from = document.createElement("div");
    const to = document.createElement("div");
    from.setAttribute("data-popover-panel", "");
    from.setAttribute("style", "position: fixed; top: 10px;");

    keepDisclosureStateAcrossPatch(from, to);

    expect(to.getAttribute("style")).toBe("position: fixed; top: 10px;");
  });

  it("leaves elements that are not disclosures alone", () => {
    const from = document.createElement("div");
    const to = document.createElement("div");
    expect(() => keepDisclosureStateAcrossPatch(from, to)).not.toThrow();
  });

  it("a click outside closes an open popover, a click inside does not", () => {
    const a = popover("a");
    a.open = true;

    a.querySelector("button").click();
    expect(a.open).toBe(true);

    document.body.click();
    expect(a.open).toBe(false);
  });

  it("only the popovers the click is outside of are closed", () => {
    const a = popover("a");
    const b = popover("b");
    a.open = true;
    b.open = true;

    expect(popoversOutside(document, a.querySelector("button"))).toEqual([b]);
  });

  it("Escape closes open popovers and goes no further", () => {
    const a = popover("a");
    a.open = true;
    let reachedWindow = false;
    const onWindow = () => (reachedWindow = true);
    window.addEventListener("keydown", onWindow);

    document.body.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));

    expect(a.open).toBe(false);
    expect(reachedWindow).toBe(false);
    window.removeEventListener("keydown", onWindow);
  });

  it("Escape with nothing open passes through", () => {
    let reachedWindow = false;
    const onWindow = () => (reachedWindow = true);
    window.addEventListener("keydown", onWindow);

    document.body.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));

    expect(reachedWindow).toBe(true);
    window.removeEventListener("keydown", onWindow);
  });

  it("an action inside closes the popover it was chosen from", () => {
    const a = popover("a");
    a.open = true;

    a.querySelector("button").dispatchEvent(
      new CustomEvent(POPOVER_CLOSE_EVENT, { bubbles: true }),
    );

    expect(a.open).toBe(false);
  });

  it("a click on another popover's trigger closes the first one", () => {
    const a = popover("a");
    const b = popover("b");
    a.open = true;

    b.querySelector("summary").click();

    expect(a.open).toBe(false);
    expect(b.open).toBe(true);
  });

  it("closing hands the focus back to the trigger", () => {
    const a = popover("a");
    a.open = true;
    const action = a.querySelector("button");
    action.focus();

    document.body.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));

    expect(a.open).toBe(false);
    expect(document.activeElement).toBe(a.querySelector("summary"));
  });

  it("an Escape that is part of an input method composition is left alone", () => {
    const a = popover("a");
    a.open = true;

    document.body.dispatchEvent(
      new KeyboardEvent("keydown", { key: "Escape", bubbles: true, isComposing: true }),
    );

    expect(a.open).toBe(true);
  });

  it("the arrow keys move between the rows of a menu, wrapping at the ends", () => {
    const details = document.createElement("details");
    details.dataset.popover = "";
    details.open = true;
    details.innerHTML = `<summary>m</summary><div role="menu">
      <button role="menuitem">one</button>
      <button role="menuitem" disabled>skip</button>
      <button role="menuitemcheckbox">two</button>
    </div>`;
    document.body.appendChild(details);
    const [one, , two] = details.querySelectorAll("button");

    one.focus();
    one.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowDown", bubbles: true }));
    expect(document.activeElement).toBe(two);

    two.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowDown", bubbles: true }));
    expect(document.activeElement).toBe(one);
  });

  it("nextMenuRow covers Home, End and an empty menu", () => {
    const rows = ["a", "b", "c"];
    expect(nextMenuRow(rows, "b", "Home")).toBe("a");
    expect(nextMenuRow(rows, "b", "End")).toBe("c");
    expect(nextMenuRow(rows, "a", "ArrowUp")).toBe("c");
    expect(nextMenuRow([], null, "ArrowDown")).toBe(null);
    expect(nextMenuRow(rows, "a", "x")).toBe(null);
  });

  it("installs its listeners once per document", () => {
    const spy = vi.spyOn(document, "addEventListener");
    installPopoverBehaviour(document);
    expect(spy).not.toHaveBeenCalled();
    spy.mockRestore();
  });

  describe("panelPosition", () => {
    const trigger = { top: 700, bottom: 722, left: 900, right: 922, width: 22 };
    const panel = { width: 288, height: 120 };
    const viewport = { width: 1366, height: 820 };

    it("hangs an above-end panel over the trigger, right edges aligned", () => {
      expect(panelPosition(trigger, panel, "above-end", viewport)).toEqual({
        top: 700 - 4 - 120,
        left: 922 - 288,
      });
    });

    it("centres an above panel on the trigger", () => {
      expect(panelPosition(trigger, panel, "above", viewport).left).toBe(911 - 144);
    });

    it("drops a below-start panel under the trigger", () => {
      expect(panelPosition(trigger, panel, "below-start", { width: 1366, height: 2000 })).toEqual({
        top: 726,
        left: 900,
      });
    });

    it("keeps the panel on screen at the edges", () => {
      const corner = { top: 10, bottom: 32, left: 2, right: 24, width: 22 };
      expect(panelPosition(corner, panel, "above-end", viewport)).toEqual({ top: 4, left: 4 });
    });
  });
});

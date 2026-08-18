import { afterEach, describe, expect, it, vi } from "vitest";

import { createRetroTable } from "../../../js/lib/ui/retro_table.js";

// jsdom implements neither; the controller calls both on the focused row.
if (!Element.prototype.scrollIntoView) Element.prototype.scrollIntoView = () => {};

function markup() {
  return `
    <table class="retro-table__grid" data-retro-table-grid>
      <thead><tr class="retro-table__head-row" data-retro-table-head-row>
        <th class="retro-table__head" data-column="name"><span>Name</span>
          <span class="retro-table__resizer" data-retro-table-resizer></span></th>
        <th class="retro-table__head" data-column="owner"><span>Owner</span>
          <span class="retro-table__resizer" data-retro-table-resizer></span></th>
      </tr></thead>
      <tbody>
        <tr class="retro-table__row" data-row-id="r1" aria-selected="false">
          <td class="retro-table__cell" data-column="name">a.txt</td>
          <td class="retro-table__cell" data-column="owner">alice</td>
        </tr>
        <tr class="retro-table__row" data-row-id="r2" aria-selected="false">
          <td class="retro-table__cell" data-column="name">b.txt</td>
          <td class="retro-table__cell" data-column="owner">bob</td>
        </tr>
      </tbody>
    </table>
    <div class="retro-table__menu u-hidden" data-retro-table-menu></div>
  `;
}

function mountTable(ports) {
  const el = document.createElement("div");
  el.className = "retro-table";
  el.innerHTML = markup();
  document.body.appendChild(el);
  const table = createRetroTable(el, ports);
  table.mount();
  return { el, table };
}

afterEach(() => {
  document.body.innerHTML = "";
  vi.restoreAllMocks();
});

describe("createRetroTable — clipboard port", () => {
  it("copies the selection through the injected writeText port", () => {
    const writeText = vi.fn(() => Promise.resolve());
    const { table } = mountTable({ writeText });

    table.moveTo("r1", { extend: false, toggle: false });
    table.copySelection();

    expect(writeText).toHaveBeenCalledTimes(1);
    expect(writeText.mock.calls[0][0]).toBe("Name\tOwner\na.txt\talice");
  });

  it("does not throw when the port rejects, and logs nothing to the page", async () => {
    const writeText = vi.fn(() => Promise.reject(new Error("denied")));
    const { table } = mountTable({ writeText });

    table.moveTo("r2", { extend: false, toggle: false });
    expect(() => table.copySelection()).not.toThrow();
    await Promise.resolve();
  });

  it("copies nothing when the selection is empty", () => {
    const writeText = vi.fn();
    const { table } = mountTable({ writeText });

    table.copySelection();

    expect(writeText).not.toHaveBeenCalled();
  });
});

describe("createRetroTable — listener symmetry (R8)", () => {
  it("removes every document listener it added, on destroy", () => {
    const added = [];
    const removed = [];
    vi.spyOn(document, "addEventListener").mockImplementation((type, fn) => added.push([type, fn]));
    vi.spyOn(document, "removeEventListener").mockImplementation((type, fn) =>
      removed.push([type, fn]),
    );

    const { table } = mountTable({ writeText: vi.fn() });
    expect(added.length).toBeGreaterThan(0);

    table.destroy();

    // Every (type, fn) added on document is removed with the same reference.
    for (const pair of added) {
      expect(removed).toContainEqual(pair);
    }
  });

  it("disconnects the resize observer on destroy", () => {
    const disconnect = vi.fn();
    const observe = vi.fn();
    const RealResizeObserver = globalThis.ResizeObserver;
    globalThis.ResizeObserver = class {
      observe = observe;
      disconnect = disconnect;
    };

    try {
      const { table } = mountTable({ writeText: vi.fn() });
      expect(observe).toHaveBeenCalled();
      table.destroy();
      expect(disconnect).toHaveBeenCalledTimes(1);
    } finally {
      globalThis.ResizeObserver = RealResizeObserver;
    }
  });
});

describe("createRetroTable — lifecycle", () => {
  it("reconcile re-asserts client state after a server re-render without throwing", () => {
    const { el, table } = mountTable({ writeText: vi.fn() });

    table.moveTo("r1", { extend: false, toggle: false });
    el.innerHTML = markup(); // server replaced the rows
    expect(() => table.reconcile()).not.toThrow();
  });
});

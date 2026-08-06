import { mountHook, cleanupDOM } from "../../helpers/hook_helper.js";
import RetroTableHook from "../../../js/hooks/ui/retro_table_hook.js";

const COLUMN_WIDTH = "--retro-table-column-width";
const TABLE_WIDTH = "--retro-table-width";

const COLUMNS = [
  { key: "name", label: "Name", width: 120, content: 260 },
  { key: "objects", label: "Objects", width: 80, content: 90 },
  { key: "owner", label: "Owner", width: 200, content: 400 },
];

const ROWS = [
  { id: "r1", name: "code_server", objects: "4 470", owner: ":code_server" },
  { id: "r2", name: "tw_merge_cache", objects: "204", owner: "#PID<0.4957.0>" },
  { id: "r3", name: "ac_tab", objects: "300", owner: ":application_controller" },
];

function tableMarkup() {
  const headings = COLUMNS.map(
    (column) => `
      <th class="retro-table__head" data-column="${column.key}"
          data-test-width="${column.width}" data-test-content="${column.content}">
        <button type="button" class="retro-table__sort">${column.label}</button>
        <span class="retro-table__resizer" data-retro-table-resizer></span>
      </th>`,
  ).join("");

  const rows = ROWS.map(
    (row) => `
      <tr class="retro-table__row" data-row-id="${row.id}" tabindex="-1" aria-selected="false">
        ${COLUMNS.map(
          (column) =>
            `<td class="retro-table__cell" data-column="${column.key}">${row[column.key]}</td>`,
        ).join("")}
      </tr>`,
  ).join("");

  const menuItems = COLUMNS.map(
    (column) => `
      <li role="menuitemcheckbox" aria-checked="true" data-retro-table-column="${column.key}">
        ${column.label}
      </li>`,
  ).join("");

  return `
    <table class="retro-table__grid" data-retro-table-grid>
      <thead><tr class="retro-table__head-row" data-retro-table-head-row>${headings}</tr></thead>
      <tbody>${rows}</tbody>
    </table>
    <div class="retro-table__menu u-hidden" data-retro-table-menu>
      <ul>
        ${menuItems}
        <li data-retro-table-columns-reset>Show all columns</li>
      </ul>
    </div>
  `;
}

/**
 * jsdom lays nothing out, so geometry is declared on the elements themselves:
 * a heading reports `data-test-width`, or `data-test-content` while the hook has
 * the table in its measuring state.
 */
function stubGeometry(root) {
  const rect = (width, height = 0) => ({
    width,
    height,
    top: 0,
    left: 0,
    right: width,
    bottom: height,
    x: 0,
    y: 0,
    toJSON: () => ({}),
  });

  Element.prototype.getBoundingClientRect = function () {
    if (this === root) return rect(400, 200);

    if (this.classList.contains("retro-table__head")) {
      const measuring = root.dataset.measuring === "true";
      const declared = measuring ? this.dataset.testContent : this.dataset.testWidth;
      const pinned = this.style.getPropertyValue(COLUMN_WIDTH);
      const override = pinned ? parseInt(pinned, 10) : null;
      return rect(measuring || override === null ? Number(declared) : override);
    }

    if (this.classList.contains("retro-table__row")) return rect(400, 20);

    return rect(0);
  };
}

function mount() {
  let root;
  const original = Element.prototype.getBoundingClientRect;

  const hook = mountHook(
    {
      ...RetroTableHook,
      mounted() {
        root = this.el;
        stubGeometry(root);
        RetroTableHook.mounted.call(this);
      },
    },
    {
      html: tableMarkup(),
      attrs: { id: "ets-table" },
    },
  );

  hook.__restoreGeometry = () => {
    Element.prototype.getBoundingClientRect = original;
  };

  return hook;
}

function heading(hook, key) {
  return hook.el.querySelector(`.retro-table__head[data-column="${key}"]`);
}

function columnWidth(hook, key) {
  return heading(hook, key).style.getPropertyValue(COLUMN_WIDTH);
}

function tableWidth(hook) {
  return hook.el.querySelector("[data-retro-table-grid]").style.getPropertyValue(TABLE_WIDTH);
}

function row(hook, id) {
  return hook.el.querySelector(`.retro-table__row[data-row-id="${id}"]`);
}

function selectedIds(hook) {
  return Array.from(hook.el.querySelectorAll('.retro-table__row[aria-selected="true"]')).map(
    (el) => el.dataset.rowId,
  );
}

function pointer(type, target, clientX) {
  target.dispatchEvent(new MouseEvent(type, { bubbles: true, cancelable: true, clientX }));
}

describe("RetroTableHook", () => {
  let hook;

  beforeEach(() => {
    hook = mount();
  });

  afterEach(() => {
    hook.__restoreGeometry();
    cleanupDOM();
  });

  describe("pinning widths", () => {
    it("fixes the layout from the widths of the first paint", () => {
      expect(hook.el.dataset.layout).toBe("fixed");
      expect(columnWidth(hook, "name")).toBe("120px");
      expect(columnWidth(hook, "objects")).toBe("80px");
      expect(columnWidth(hook, "owner")).toBe("200px");
    });

    it("makes the table exactly as wide as its columns", () => {
      expect(tableWidth(hook)).toBe("400px");
    });

    it("leaves an unrendered table unpinned so it can be measured once it opens", () => {
      hook.__restoreGeometry();
      Element.prototype.getBoundingClientRect = () => ({ width: 0, height: 0, toJSON: () => ({}) });

      const closed = mountHook(RetroTableHook, {
        html: tableMarkup(),
        attrs: { id: "closed-table" },
      });

      expect(closed.el.dataset.layout).toBeUndefined();
    });
  });

  describe("resizing a column", () => {
    it("follows the pointer and leaves the other columns alone", () => {
      const grip = heading(hook, "name").querySelector("[data-retro-table-resizer]");

      pointer("pointerdown", grip, 120);
      pointer("pointermove", grip, 180);
      pointer("pointerup", grip, 180);

      expect(columnWidth(hook, "name")).toBe("180px");
      expect(columnWidth(hook, "objects")).toBe("80px");
      expect(columnWidth(hook, "owner")).toBe("200px");
    });

    it("grows the table by what the column gained", () => {
      const grip = heading(hook, "owner").querySelector("[data-retro-table-resizer]");

      pointer("pointerdown", grip, 400);
      pointer("pointermove", grip, 450);
      pointer("pointerup", grip, 450);

      expect(tableWidth(hook)).toBe("450px");
    });

    it("stops at a width a heading can still be grabbed by", () => {
      const grip = heading(hook, "objects").querySelector("[data-retro-table-resizer]");

      pointer("pointerdown", grip, 200);
      pointer("pointermove", grip, 0);
      pointer("pointerup", grip, 0);

      expect(columnWidth(hook, "objects")).toBe("32px");
    });

    it("swallows the click that ends a drag so the heading does not also sort", () => {
      const grip = heading(hook, "name").querySelector("[data-retro-table-resizer]");
      const sorted = vi.fn();
      hook.el.addEventListener("click", sorted);

      pointer("pointerdown", grip, 120);
      pointer("pointermove", grip, 200);
      pointer("pointerup", grip, 200);
      grip.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }));

      expect(sorted).not.toHaveBeenCalled();
    });

    it("lets a click through when the pointer never moved", () => {
      const grip = heading(hook, "name").querySelector("[data-retro-table-resizer]");
      const sorted = vi.fn();
      hook.el.addEventListener("click", sorted);

      pointer("pointerdown", grip, 120);
      pointer("pointerup", grip, 120);
      grip.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }));

      expect(sorted).toHaveBeenCalled();
    });

    it("fits a column to its longest value on a double-click", () => {
      const grip = heading(hook, "owner").querySelector("[data-retro-table-resizer]");

      grip.dispatchEvent(new MouseEvent("dblclick", { bubbles: true, cancelable: true }));

      expect(columnWidth(hook, "owner")).toBe("400px");
      expect(hook.el.dataset.measuring).toBeUndefined();
      expect(hook.el.dataset.layout).toBe("fixed");
    });
  });

  describe("choosing columns", () => {
    function openMenu() {
      hook.el
        .querySelector("[data-retro-table-head-row]")
        .dispatchEvent(new MouseEvent("contextmenu", { bubbles: true, cancelable: true }));
    }

    it("opens the menu on a right-click of the header", () => {
      openMenu();
      expect(hook.el.querySelector("[data-retro-table-menu]").classList).not.toContain("u-hidden");
    });

    it("hides every cell of a column that is switched off", () => {
      hook.el.querySelector('[data-retro-table-column="owner"]').click();

      expect(heading(hook, "owner").dataset.hidden).toBe("true");
      expect(hook.el.querySelectorAll('td[data-column="owner"][data-hidden="true"]')).toHaveLength(
        ROWS.length,
      );
      expect(heading(hook, "name").dataset.hidden).toBeUndefined();
    });

    it("narrows the table by the width the column was holding", () => {
      hook.el.querySelector('[data-retro-table-column="owner"]').click();

      expect(tableWidth(hook)).toBe("200px");
    });

    it("marks the menu item as unchecked", () => {
      const item = hook.el.querySelector('[data-retro-table-column="owner"]');
      item.click();
      expect(item.getAttribute("aria-checked")).toBe("false");
    });

    it("refuses to hide the last column standing", () => {
      hook.el.querySelector('[data-retro-table-column="owner"]').click();
      hook.el.querySelector('[data-retro-table-column="objects"]').click();
      hook.el.querySelector('[data-retro-table-column="name"]').click();

      expect(heading(hook, "name").dataset.hidden).toBeUndefined();
    });

    it("brings every column back", () => {
      hook.el.querySelector('[data-retro-table-column="owner"]').click();
      hook.el.querySelector("[data-retro-table-columns-reset]").click();

      expect(hook.el.querySelectorAll("[data-hidden]")).toHaveLength(0);
      expect(tableWidth(hook)).toBe("400px");
    });

    it("closes the menu once a column is chosen", () => {
      openMenu();
      hook.el.querySelector('[data-retro-table-column="owner"]').click();

      expect(hook.el.querySelector("[data-retro-table-menu]").classList).toContain("u-hidden");
    });

    it("closes the menu on a click outside it", () => {
      openMenu();
      document.body.dispatchEvent(new MouseEvent("pointerdown", { bubbles: true }));

      expect(hook.el.querySelector("[data-retro-table-menu]").classList).toContain("u-hidden");
    });
  });

  describe("selecting rows", () => {
    it("selects the row that was clicked", () => {
      row(hook, "r2").click();
      expect(selectedIds(hook)).toEqual(["r2"]);
    });

    it("moves the selection with the arrow keys", () => {
      row(hook, "r1").click();
      row(hook, "r1").dispatchEvent(
        new KeyboardEvent("keydown", { key: "ArrowDown", bubbles: true }),
      );

      expect(selectedIds(hook)).toEqual(["r2"]);
    });

    it("extends the selection when Shift is held", () => {
      row(hook, "r1").click();
      row(hook, "r1").dispatchEvent(
        new KeyboardEvent("keydown", { key: "ArrowDown", shiftKey: true, bubbles: true }),
      );

      expect(selectedIds(hook)).toEqual(["r1", "r2"]);
    });

    it("adds a single row when Ctrl is held", () => {
      row(hook, "r1").click();
      row(hook, "r3").dispatchEvent(
        new MouseEvent("click", { bubbles: true, cancelable: true, ctrlKey: true }),
      );

      expect(selectedIds(hook)).toEqual(["r1", "r3"]);
    });

    it("goes to the ends with Home and End", () => {
      row(hook, "r2").click();
      row(hook, "r2").dispatchEvent(new KeyboardEvent("keydown", { key: "End", bubbles: true }));
      expect(selectedIds(hook)).toEqual(["r3"]);

      row(hook, "r3").dispatchEvent(new KeyboardEvent("keydown", { key: "Home", bubbles: true }));
      expect(selectedIds(hook)).toEqual(["r1"]);
    });

    it("takes every row on Ctrl+A", () => {
      row(hook, "r1").click();
      row(hook, "r1").dispatchEvent(
        new KeyboardEvent("keydown", { key: "a", ctrlKey: true, bubbles: true }),
      );

      expect(selectedIds(hook)).toEqual(["r1", "r2", "r3"]);
    });

    it("leaves the arrow keys alone when focus is on a sort button", () => {
      row(hook, "r2").click();
      const sort = hook.el.querySelector(".retro-table__sort");
      sort.focus();
      sort.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowDown", bubbles: true }));

      expect(selectedIds(hook)).toEqual(["r2"]);
    });
  });

  describe("copying the selection", () => {
    it("writes the visible columns as tab-separated text", async () => {
      const writeText = vi.fn().mockResolvedValue(undefined);
      Object.defineProperty(navigator, "clipboard", {
        value: { writeText },
        configurable: true,
      });

      hook.el.querySelector('[data-retro-table-column="owner"]').click();
      row(hook, "r1").click();
      row(hook, "r1").dispatchEvent(
        new KeyboardEvent("keydown", { key: "c", ctrlKey: true, bubbles: true }),
      );

      expect(writeText).toHaveBeenCalledWith("Name\tObjects\ncode_server\t4 470");
    });
  });

  describe("surviving a server render", () => {
    it("puts the widths, the hidden columns and the selection back", () => {
      hook.el.querySelector('[data-retro-table-column="owner"]').click();
      row(hook, "r2").click();

      // What a LiveView patch leaves behind: the server's markup, which knows
      // none of the above.
      hook.el.innerHTML = tableMarkup();
      hook.updated();

      expect(heading(hook, "owner").dataset.hidden).toBe("true");
      expect(columnWidth(hook, "name")).toBe("120px");
      expect(selectedIds(hook)).toEqual(["r2"]);
    });

    it("forgets the widths when the window shows a different listing", () => {
      // The database window runs whichever report is chosen, and each report
      // brings its own columns. Keeping a width measured for the old ones
      // pinned the table to the sum of the few keys that survived, collapsing
      // every new column to nothing.
      const replaced = tableMarkup()
        .replaceAll('data-column="name"', 'data-column="schema"')
        .replaceAll('data-column="owner"', 'data-column="size"');

      hook.el.innerHTML = replaced;
      hook.updated();

      expect(columnWidth(hook, "schema")).toBe("120px");
      expect(columnWidth(hook, "size")).toBe("200px");
      expect(tableWidth(hook)).toBe("400px");
    });

    it("keeps a hidden column hidden across an ordinary refresh", () => {
      hook.el.querySelector('[data-retro-table-column="owner"]').click();

      hook.el.innerHTML = tableMarkup();
      hook.updated();

      expect(heading(hook, "owner").dataset.hidden).toBe("true");
    });

    it("shows every column again once the listing is replaced", () => {
      hook.el.querySelector('[data-retro-table-column="owner"]').click();

      hook.el.innerHTML = tableMarkup().replaceAll('data-column="name"', 'data-column="schema"');
      hook.updated();

      expect(hook.el.querySelectorAll("[data-hidden]")).toHaveLength(0);
    });

    it("drops a selected row that the new page no longer holds", () => {
      row(hook, "r3").click();

      hook.el.innerHTML = tableMarkup().replace(
        /<tr class="retro-table__row" data-row-id="r3"[\s\S]*?<\/tr>/,
        "",
      );
      hook.updated();

      expect(selectedIds(hook)).toEqual([]);
    });
  });
});

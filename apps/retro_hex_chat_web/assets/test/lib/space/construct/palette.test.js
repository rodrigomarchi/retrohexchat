import { describe, it, expect, vi } from "vitest";

import { createBuildPalette } from "../../../../js/lib/space/construct/palette.js";

function paletteDom() {
  const root = document.createElement("div");
  root.setAttribute("data-refused-occupied", "Something is already there.");
  root.setAttribute("data-refused-default", "That piece cannot go there.");
  root.innerHTML = `
    <button data-construct-kind="chair" data-selected="false"><canvas data-construct-thumb width="40" height="40"></canvas></button>
    <button data-construct-kind="tree" data-selected="false"><canvas data-construct-thumb width="40" height="40"></canvas></button>
    <button data-construct-rotate disabled></button>
    <button data-construct-remove disabled></button>
    <p data-construct-hint data-hint="Pick a piece." data-paint-hint="Drag to paint.">Pick a piece.</p>
    <p data-construct-status data-refused="false" hidden></p>
  `;
  return root;
}

describe("createBuildPalette", () => {
  it("reports presses through its ports", () => {
    const root = paletteDom();
    const ports = { onChoose: vi.fn(), onRotate: vi.fn(), onRemove: vi.fn() };
    const palette = createBuildPalette(root, ports);
    palette.attach();
    palette.render({ mode: "selected", itemId: "x" });

    root.querySelector('[data-construct-kind="tree"]').click();
    root.querySelector("[data-construct-rotate]").click();
    root.querySelector("[data-construct-remove]").click();

    expect(ports.onChoose).toHaveBeenCalledWith("tree");
    expect(ports.onRotate).toHaveBeenCalledOnce();
    expect(ports.onRemove).toHaveBeenCalledOnce();
    palette.detach();
  });

  it("sinks the armed kind and enables only the tools that apply", () => {
    const root = paletteDom();
    const palette = createBuildPalette(root, { onChoose() {}, onRotate() {}, onRemove() {} });

    palette.render({ mode: "placing", kind: "chair", dir: "down" });
    expect(root.querySelector('[data-construct-kind="chair"]').dataset.selected).toBe("true");
    expect(root.querySelector('[data-construct-kind="tree"]').dataset.selected).toBe("false");
    expect(root.querySelector("[data-construct-rotate]").disabled).toBe(false);
    expect(root.querySelector("[data-construct-remove]").disabled).toBe(true);

    palette.render({ mode: "idle" });
    expect(root.querySelector('[data-construct-kind="chair"]').dataset.selected).toBe("false");
    expect(root.querySelector("[data-construct-rotate]").disabled).toBe(true);
  });

  it("has nothing to turn for a kind with one facing", () => {
    const root = paletteDom();
    const palette = createBuildPalette(root, {
      onChoose() {},
      onRotate() {},
      onRemove() {},
      dirsOf: (kind) => (kind === "tree" ? ["down"] : undefined),
    });

    palette.render({ mode: "placing", kind: "tree", dir: "down" }, { kind: "tree", dir: "down" });
    expect(root.querySelector("[data-construct-rotate]").disabled).toBe(true);

    palette.render({ mode: "placing", kind: "chair", dir: "down" }, { kind: "chair", dir: "down" });
    expect(root.querySelector("[data-construct-rotate]").disabled).toBe(false);
  });

  it("says why an edit was refused, and puts the hint back after one that went through", () => {
    const root = paletteDom();
    const palette = createBuildPalette(root, { onChoose() {}, onRotate() {}, onRemove() {} });
    const status = root.querySelector("[data-construct-status]");

    palette.refuse("occupied");
    expect(status.textContent).toBe("Something is already there.");
    expect(status.hidden).toBe(false);
    palette.refuse("would_trap");
    expect(status.textContent).toBe("That piece cannot go there.");
    palette.clear();
    expect(status.hidden).toBe(true);
    expect(status.textContent).toBe("");
  });

  it("draws each kind's sprite into its key", () => {
    const root = paletteDom();
    const ctx = { clearRect: vi.fn(), drawImage: vi.fn(), imageSmoothingEnabled: true };
    for (const canvas of root.querySelectorAll("canvas")) canvas.getContext = () => ctx;
    const palette = createBuildPalette(root, { onChoose() {}, onRotate() {}, onRemove() {} });

    palette.drawSprites({
      kind: (kind) => (kind === "tree" ? { img: {}, sx: 0, sy: 0, sw: 72, sh: 104 } : null),
      tile: () => null,
    });

    expect(ctx.drawImage).toHaveBeenCalledOnce();
    const [, , , sw, sh, , , w, h] = ctx.drawImage.mock.calls[0];
    expect([sw, sh]).toEqual([72, 104]);
    expect(h).toBeLessThanOrEqual(36);
    expect(w / h).toBeCloseTo(72 / 104, 1);
  });

  it("shows one group of kinds at a time", () => {
    const root = document.createElement("div");
    root.innerHTML = `
      <button data-construct-tab="furniture" data-selected="true"></button>
      <button data-construct-tab="fun" data-selected="false"></button>
      <div data-construct-group="furniture"><button data-construct-kind="chair"></button></div>
      <div data-construct-group="fun" hidden><button data-construct-kind="die"></button></div>
    `;
    const onChoose = vi.fn();
    const palette = createBuildPalette(root, { onChoose, onRotate() {}, onRemove() {} });
    palette.attach();

    root.querySelector('[data-construct-tab="fun"]').click();
    expect(root.querySelector('[data-construct-group="fun"]').hidden).toBe(false);
    expect(root.querySelector('[data-construct-group="furniture"]').hidden).toBe(true);
    expect(root.querySelector('[data-construct-tab="fun"]').dataset.selected).toBe("true");
    expect(root.querySelector('[data-construct-tab="furniture"]').dataset.selected).toBe("false");
    expect(onChoose).not.toHaveBeenCalled();
    palette.detach();
  });

  it("names a refusal in the server's own words", () => {
    const palette = createBuildPalette(paletteDom(), {
      onChoose() {},
      onRotate() {},
      onRemove() {},
    });
    expect(palette.sentence("occupied")).toBe("Something is already there.");
    expect(palette.sentence("whatever")).toBe("That piece cannot go there.");
  });

  it("says what a press does: paint while a floor is armed, build otherwise", () => {
    const root = paletteDom();
    const palette = createBuildPalette(root, { onChoose() {}, onRotate() {}, onRemove() {} });
    const line = root.querySelector("[data-construct-hint]");

    palette.render({ mode: "painting", material: "wood" });
    expect(line.textContent).toBe("Drag to paint.");
    palette.render({ mode: "idle" });
    expect(line.textContent).toBe("Pick a piece.");

    // A refusal is said in its own line, and stays until an edit goes through.
    palette.refuse("occupied");
    palette.render({ mode: "painting", material: "wood" });
    expect(root.querySelector("[data-construct-status]").textContent).toBe(
      "Something is already there.",
    );
    expect(line.textContent).toBe("Drag to paint.");
  });

  describe("the drawer and the card", () => {
    function drawerDom() {
      const root = document.createElement("div");
      root.dataset.open = "false";
      root.innerHTML = `
        <button data-construct-toggle aria-expanded="false"></button>
        <section data-construct-drawer>
          <button data-construct-close></button>
          <button data-construct-kind="chair" aria-label="Chair"><canvas data-construct-thumb width="40" height="40"></canvas></button>
          <button data-construct-material="wood" data-construct-tile="floor_wood" aria-label="Wood"><canvas data-construct-thumb width="40" height="40"></canvas></button>
          <p data-construct-hint data-hint="Click the floor." data-touch-hint="Tap the floor." data-paint-hint="Drag to paint.">Click the floor.</p>
        </section>
        <div data-construct-holding hidden>
          <canvas data-construct-holding-thumb width="40" height="40"></canvas>
          <span data-construct-holding-name></span>
          <button data-construct-rotate disabled></button>
          <button data-construct-remove disabled></button>
          <button data-construct-drop></button>
        </div>
      `;
      return root;
    }

    const memory = () => {
      const store = new Map();
      return {
        getItem: (k) => store.get(k) ?? null,
        setItem: (k, v) => store.set(k, v),
      };
    };

    const ports = (extra = {}) => ({
      onChoose: vi.fn(),
      onPaint: vi.fn(),
      onRotate: vi.fn(),
      onRemove: vi.fn(),
      onDrop: vi.fn(),
      ...extra,
    });

    it("opens and shuts from the Build key and the close key, and remembers it", () => {
      const root = drawerDom();
      const store = memory();
      const palette = createBuildPalette(
        root,
        ports({ storage: () => store, isSheet: () => false }),
      );
      palette.attach();
      expect(root.dataset.open).toBe("false");

      root.querySelector("[data-construct-toggle]").click();
      expect(root.dataset.open).toBe("true");
      expect(root.querySelector("[data-construct-toggle]").getAttribute("aria-expanded")).toBe(
        "true",
      );
      root.querySelector("[data-construct-close]").click();
      expect(root.dataset.open).toBe("false");
      palette.toggle();
      palette.detach();

      // The next visit opens it the way it was left.
      const again = drawerDom();
      createBuildPalette(again, ports({ storage: () => store })).attach();
      expect(again.dataset.open).toBe("true");
    });

    it("opens shut when this browser keeps no memory", () => {
      const root = drawerDom();
      const blocked = () => {
        throw new Error("blocked");
      };
      createBuildPalette(root, ports({ storage: blocked })).attach();
      expect(root.dataset.open).toBe("false");
    });

    it("on a phone, choosing a piece shuts the sheet so the floor can take the tap", () => {
      const root = drawerDom();
      const p = ports({ storage: () => memory(), isSheet: () => true });
      const palette = createBuildPalette(root, p);
      palette.attach();
      palette.toggle();

      root.querySelector("[data-construct-kind]").click();
      expect(p.onChoose).toHaveBeenCalledWith("chair");
      expect(root.dataset.open).toBe("false");
    });

    it("on a desktop, the side panel stays open for the next piece", () => {
      const root = drawerDom();
      const palette = createBuildPalette(
        root,
        ports({ storage: () => memory(), isSheet: () => false }),
      );
      palette.attach();
      palette.toggle();
      root.querySelector("[data-construct-kind]").click();
      expect(root.dataset.open).toBe("true");
    });

    it("shows what is in hand, its name and picture, and lets it go", () => {
      const root = drawerDom();
      const ctx = { clearRect: vi.fn(), drawImage: vi.fn(), imageSmoothingEnabled: true };
      for (const canvas of root.querySelectorAll("canvas")) canvas.getContext = () => ctx;
      const p = ports({ storage: () => memory() });
      const palette = createBuildPalette(root, p);
      palette.attach();
      const sprite = { img: {}, sx: 0, sy: 0, sw: 30, sh: 30 };
      palette.drawSprites({ kind: () => sprite, tile: () => sprite });
      const card = root.querySelector("[data-construct-holding]");

      palette.render({ mode: "idle" }, null);
      expect(card.hidden).toBe(true);

      palette.render(
        { mode: "placing", kind: "chair", dir: "down" },
        { kind: "chair", dir: "down" },
      );
      expect(card.hidden).toBe(false);
      expect(root.querySelector("[data-construct-holding-name]").textContent).toBe("Chair");
      expect(root.querySelector("[data-construct-rotate]").disabled).toBe(false);
      expect(root.querySelector("[data-construct-remove]").disabled).toBe(true);

      palette.render({ mode: "painting", material: "wood" }, { material: "wood" });
      expect(root.querySelector("[data-construct-holding-name]").textContent).toBe("Wood");

      root.querySelector("[data-construct-drop]").click();
      expect(p.onDrop).toHaveBeenCalledOnce();
    });

    it("hints in the words of the pointer that pressed the floor", () => {
      const root = drawerDom();
      const palette = createBuildPalette(root, ports({ storage: () => memory() }));
      const line = root.querySelector("[data-construct-hint]");

      palette.render({ mode: "idle" }, null);
      expect(line.textContent).toBe("Click the floor.");
      palette.usePointer("touch");
      palette.render({ mode: "idle" }, null);
      expect(line.textContent).toBe("Tap the floor.");
    });
  });
});

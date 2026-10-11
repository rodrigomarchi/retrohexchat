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
    <p data-construct-status data-hint="Pick a piece.">Pick a piece.</p>
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

  it("says why an edit was refused, and puts the hint back after one that went through", () => {
    const root = paletteDom();
    const palette = createBuildPalette(root, { onChoose() {}, onRotate() {}, onRemove() {} });
    const status = root.querySelector("[data-construct-status]");

    palette.refuse("occupied");
    expect(status.textContent).toBe("Something is already there.");
    palette.refuse("would_trap");
    expect(status.textContent).toBe("That piece cannot go there.");
    palette.clear();
    expect(status.textContent).toBe("Pick a piece.");
  });

  it("draws each kind's sprite into its key", () => {
    const root = paletteDom();
    const ctx = { clearRect: vi.fn(), drawImage: vi.fn(), imageSmoothingEnabled: true };
    for (const canvas of root.querySelectorAll("canvas")) canvas.getContext = () => ctx;
    const palette = createBuildPalette(root, { onChoose() {}, onRotate() {}, onRemove() {} });

    palette.drawThumbnails((kind) =>
      kind === "tree" ? { img: {}, sx: 0, sy: 0, sw: 72, sh: 104 } : null,
    );

    expect(ctx.drawImage).toHaveBeenCalledOnce();
    const [, , , sw, sh, , , w, h] = ctx.drawImage.mock.calls[0];
    expect([sw, sh]).toEqual([72, 104]);
    expect(h).toBeLessThanOrEqual(36);
    expect(w / h).toBeCloseTo(72 / 104, 1);
  });
});

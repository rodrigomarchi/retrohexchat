import { nextCanvasSize, createCanvasResizer } from "../../../js/lib/space/canvas_resizer.js";

describe("nextCanvasSize", () => {
  it("returns the client box when the backing store differs", () => {
    expect(
      nextCanvasSize({ clientWidth: 300, clientHeight: 150, backingWidth: 0, backingHeight: 0 }),
    ).toEqual({ width: 300, height: 150 });
  });

  it("returns null when the backing store already matches", () => {
    expect(
      nextCanvasSize({
        clientWidth: 300,
        clientHeight: 150,
        backingWidth: 300,
        backingHeight: 150,
      }),
    ).toBe(null);
  });

  it("returns null before the element has a real size", () => {
    expect(
      nextCanvasSize({ clientWidth: 0, clientHeight: 0, backingWidth: 10, backingHeight: 10 }),
    ).toBe(null);
  });
});

describe("createCanvasResizer", () => {
  function fakeCanvas(clientWidth, clientHeight) {
    return {
      width: 0,
      height: 0,
      // jsdom leaves client* at 0; define them explicitly for the fit.
      clientWidth,
      clientHeight,
    };
  }

  it("fits the canvas to its client box and notifies on attach", () => {
    const el = { clientWidth: 0, clientHeight: 0 };
    const canvas = fakeCanvas(320, 240);
    let resized = 0;
    const resizer = createCanvasResizer(el, canvas, { onResized: () => (resized += 1) });
    resizer.attach();
    expect(canvas.width).toBe(320);
    expect(canvas.height).toBe(240);
    expect(resized).toBe(1);
    resizer.detach();
  });

  it("falls back to the shell box when the canvas reports no client size", () => {
    const el = { clientWidth: 500, clientHeight: 400 };
    const canvas = fakeCanvas(0, 0);
    const resizer = createCanvasResizer(el, canvas, {});
    resizer.fit();
    expect(canvas.width).toBe(500);
    expect(canvas.height).toBe(400);
  });

  it("still notifies even when the size does not change", () => {
    const el = { clientWidth: 0, clientHeight: 0 };
    const canvas = fakeCanvas(100, 100);
    canvas.width = 100;
    canvas.height = 100;
    let resized = 0;
    const resizer = createCanvasResizer(el, canvas, { onResized: () => (resized += 1) });
    resizer.fit();
    expect(resized).toBe(1);
    expect(canvas.width).toBe(100);
  });
});

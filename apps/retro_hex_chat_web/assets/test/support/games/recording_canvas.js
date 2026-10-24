/**
 * A canvas whose 2D context records every call and assignment, in order.
 * Two renderers draw the same picture when their logs match.
 *
 * Gradients and patterns are named (`g1`, `p1`) so the log can say which one a
 * fill used. `measureText` answers 8 pixels per character, which keeps layouts
 * that centre text on its width stable without a real font.
 *
 * @param {number} width
 * @param {number} height
 */
export function recordingCanvas(width, height) {
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;

  let log = [];
  let nextId = 1;
  const state = {};

  const named = (prefix, op, args) => {
    const id = `${prefix}${nextId++}`;
    log.push([op, ...args]);
    return {
      id,
      addColorStop: (offset, color) => log.push([`${id}.addColorStop`, offset, color]),
      setTransform: () => {},
    };
  };

  const methods = {
    createLinearGradient: (...args) => named("g", "createLinearGradient", args),
    createRadialGradient: (...args) => named("g", "createRadialGradient", args),
    createConicGradient: (...args) => named("g", "createConicGradient", args),
    createPattern: (...args) => named("p", "createPattern", args.slice(1)),
    measureText: (text) => {
      log.push(["measureText", text]);
      return { width: String(text).length * 8 };
    },
    getImageData: (x, y, w, h) => {
      log.push(["getImageData", x, y, w, h]);
      return { width: w, height: h, data: new Uint8ClampedArray(Math.max(0, w * h * 4)) };
    },
    isPointInPath: () => false,
    getLineDash: () => state.lineDash ?? [],
  };

  const ctx = new Proxy(
    {},
    {
      get(_target, prop) {
        if (typeof prop !== "string") return undefined;
        if (prop === "canvas") return canvas;
        if (prop in methods) return methods[prop];
        if (prop in state) return state[prop];
        return (...args) => {
          if (prop === "setLineDash") state.lineDash = args[0];
          log.push([prop, ...args.map((arg) => arg?.id ?? arg)]);
        };
      },
      set(_target, prop, value) {
        state[prop] = value;
        log.push([prop, "=", value?.id ?? value]);
        return true;
      },
    },
  );

  canvas.getContext = () => ctx;

  Object.defineProperty(canvas, "log", { get: () => log });
  canvas.clearLog = () => {
    log = [];
  };

  return canvas;
}

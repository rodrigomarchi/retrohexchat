/**
 * Keeps a canvas's backing store matched to its CSS box.
 *
 * A window-manager resize (maximize, snap) can change the element's laid-out
 * size without firing a browser "resize" event, so the fit is driven by a
 * ResizeObserver on the host. `nextCanvasSize` is the pure decision; the
 * controller owns the observer and the DOM writes and is the reason the hook
 * itself holds no ResizeObserver.
 */

/**
 * @param {{clientWidth: number, clientHeight: number, backingWidth: number, backingHeight: number}} m
 * @returns {{width: number, height: number}|null} new backing size, or null to leave it
 */
export function nextCanvasSize({ clientWidth, clientHeight, backingWidth, backingHeight }) {
  if (
    clientWidth > 0 &&
    clientHeight > 0 &&
    (backingWidth !== clientWidth || backingHeight !== clientHeight)
  ) {
    return { width: clientWidth, height: clientHeight };
  }
  return null;
}

/**
 * @param {HTMLElement} el - the shell element the canvas is laid out inside
 * @param {HTMLCanvasElement} canvas
 * @param {{onResized?: Function}} [ports] - called after every fit (size change or not)
 */
export function createCanvasResizer(el, canvas, { onResized } = {}) {
  let observer = null;

  function fit() {
    if (!canvas) return;
    const clientWidth = canvas.clientWidth || el.clientWidth;
    const clientHeight = canvas.clientHeight || el.clientHeight;
    const size = nextCanvasSize({
      clientWidth,
      clientHeight,
      backingWidth: canvas.width,
      backingHeight: canvas.height,
    });
    if (size) {
      canvas.width = size.width;
      canvas.height = size.height;
    }
    onResized?.();
  }

  return {
    attach() {
      fit();
      if (typeof ResizeObserver !== "undefined") {
        observer = new ResizeObserver(() => fit());
        observer.observe(el);
      }
    },

    detach() {
      observer?.disconnect();
      observer = null;
    },

    fit,
  };
}

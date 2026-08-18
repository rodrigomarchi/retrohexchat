/**
 * Deriving the viewport state a phone needs — pure, no DOM.
 *
 * The app is fixed-positioned, so the address bar and the on-screen keyboard
 * move the visible area out from under it. The hook reads the live measurements
 * and applies the result; the arithmetic that turns them into a keyboard inset,
 * a mobile flag and the CSS variables lives here, where it can be tested against
 * plain numbers.
 *
 * @module ui/viewport
 */

export const MOBILE_BREAKPOINT = 768;
export const KEYBOARD_INSET_THRESHOLD = 80;

function round(value) {
  return Math.round(Number(value) || 0);
}

/**
 * @param {object} input
 * @param {number} input.innerWidth window.innerWidth
 * @param {number} input.innerHeight window.innerHeight
 * @param {{width?: number, height?: number, offsetTop?: number, offsetLeft?: number}|null} [input.visualViewport]
 * @param {boolean} input.editableFocused whether an editable element has focus
 * @returns {{width: number, height: number, visualWidth: number, visualHeight: number,
 *   offsetTop: number, offsetLeft: number, keyboardInset: number, mobile: boolean, keyboardOpen: boolean}}
 */
export function computeViewport({ innerWidth, innerHeight, visualViewport, editableFocused }) {
  const width = round(innerWidth);
  const height = round(innerHeight);
  const visualWidth = round(visualViewport?.width || width);
  const visualHeight = round(visualViewport?.height || height);
  const offsetTop = round(visualViewport?.offsetTop || 0);
  const offsetLeft = round(visualViewport?.offsetLeft || 0);
  const keyboardInset = Math.max(0, height - visualHeight - offsetTop);
  const mobile = width < MOBILE_BREAKPOINT;
  const keyboardOpen = mobile && editableFocused && keyboardInset >= KEYBOARD_INSET_THRESHOLD;

  return {
    width,
    height,
    visualWidth,
    visualHeight,
    offsetTop,
    offsetLeft,
    keyboardInset,
    mobile,
    keyboardOpen,
  };
}

/** The subset the server is told about, in the server's snake_case keys. */
export function viewportPayload(state) {
  return {
    width: state.width,
    height: state.height,
    visual_width: state.visualWidth,
    visual_height: state.visualHeight,
    mobile: state.mobile,
  };
}

/**
 * Whether a payload differs from the last one in a way worth telling the server.
 * Only the breakpoint-relevant fields count; every visual change still updates
 * the CSS variables.
 *
 * @param {object|null} prev
 * @param {object} next
 * @returns {boolean}
 */
export function viewportChanged(prev, next) {
  return (
    !prev || prev.width !== next.width || prev.height !== next.height || prev.mobile !== next.mobile
  );
}

/** The CSS custom properties the fixed layout reads, keyed by property name. */
export function viewportCssVars(state) {
  return {
    "--rhc-visual-viewport-height": `${state.visualHeight}px`,
    "--rhc-visual-viewport-width": `${state.visualWidth}px`,
    "--rhc-visual-viewport-offset-top": `${state.offsetTop}px`,
    "--rhc-visual-viewport-offset-left": `${state.offsetLeft}px`,
    "--rhc-keyboard-inset-bottom": `${state.keyboardInset}px`,
  };
}

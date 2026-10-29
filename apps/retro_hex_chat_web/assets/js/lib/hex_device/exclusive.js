/**
 * One sound at a time across the page: a Hex device that starts playing says
 * so on the window, and every other one that hears it stops — the radio when
 * a voice message starts, a voice message when the next one does.
 *
 * @module hex_device/exclusive
 */

const EVENT = "hex-device:play";

/**
 * Says `owner` is now playing, and calls `stop` whenever another device
 * starts. Returns the function that stops listening.
 *
 * @param {Window} win
 * @param {Element} owner - the device's root, which never stops itself
 * @param {() => void} stop
 * @returns {{announce: () => void, release: () => void}}
 */
export function claimSound(win, owner, stop) {
  const listener = (event) => {
    if (event.detail?.owner !== owner) stop();
  };
  win.addEventListener(EVENT, listener);
  return {
    announce: () => win.dispatchEvent(new win.CustomEvent(EVENT, { detail: { owner } })),
    release: () => win.removeEventListener(EVENT, listener),
  };
}

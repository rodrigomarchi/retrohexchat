/**
 * Reveals Markdown images only after the browser has a complete frame to paint.
 *
 * The server-rendered shell reserves the image's space and acts as the
 * placeholder. This controller only flips data state after load/decode; it does
 * not change fetch policy, so `loading="lazy"` stays browser-owned.
 *
 * @module chat/markdown_images
 */

const IMAGE_SELECTOR = ".chat-markdown-image-shell > img.chat-markdown-image";
const STATE_LOADING = "loading";
const STATE_LOADED = "loaded";
const STATE_FAILED = "failed";

/**
 * @param {ParentNode} root DOM subtree containing Markdown image shells.
 * @param {object} deps injectable browser primitives for tests.
 * @returns {{mount: Function, reconcile: Function, destroy: Function}}
 */
export function createMarkdownImageRevealer(root, deps = {}) {
  const doc = root?.ownerDocument || globalThis.document;
  const win = doc?.defaultView || globalThis;
  const MutationObserver = deps.MutationObserver || win.MutationObserver;

  let observer = null;
  const tracked = new Map();

  const shellFor = (img) => img.closest(".chat-markdown-image-shell");

  const setState = (img, state) => {
    const shell = shellFor(img);
    if (shell) shell.dataset.imageState = state;
    img.dataset.imageState = state;
  };

  const untrack = (img) => {
    const handlers = tracked.get(img);
    if (!handlers) return;

    img.removeEventListener("load", handlers.load);
    img.removeEventListener("error", handlers.error);
    tracked.delete(img);
  };

  const markLoaded = (img) => {
    untrack(img);
    setState(img, STATE_LOADED);
  };

  const markFailed = (img) => {
    untrack(img);
    setState(img, STATE_FAILED);
  };

  const revealDecoded = (img) => {
    if (typeof img.decode !== "function" || img.naturalWidth === 0) {
      markLoaded(img);
      return;
    }

    img.decode().then(
      () => markLoaded(img),
      () => markLoaded(img),
    );
  };

  const track = (img) => {
    if (tracked.has(img) || img.dataset.imageState === STATE_LOADED) return;
    if (img.dataset.imageState === STATE_FAILED) return;

    setState(img, STATE_LOADING);

    if (img.complete) {
      if (img.naturalWidth === 0) {
        markFailed(img);
      } else {
        revealDecoded(img);
      }
      return;
    }

    const handlers = {
      load: () => revealDecoded(img),
      error: () => markFailed(img),
    };

    tracked.set(img, handlers);
    img.addEventListener("load", handlers.load, { once: true });
    img.addEventListener("error", handlers.error, { once: true });
  };

  const dropDetached = () => {
    tracked.forEach((_handlers, img) => {
      if (!img.isConnected) untrack(img);
    });
  };

  const reconcile = () => {
    if (!root?.querySelectorAll) return;

    dropDetached();
    root.querySelectorAll(IMAGE_SELECTOR).forEach(track);
  };

  const controller = {
    mount() {
      reconcile();

      if (typeof MutationObserver === "function" && root) {
        observer = new MutationObserver(() => reconcile());
        observer.observe(root, { childList: true, subtree: true });
      }
    },

    reconcile,

    destroy() {
      observer?.disconnect();
      observer = null;

      tracked.forEach((_handlers, img) => untrack(img));
      tracked.clear();
    },
  };

  return controller;
}

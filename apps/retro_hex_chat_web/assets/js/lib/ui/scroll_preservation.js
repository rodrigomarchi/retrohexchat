/**
 * Preserve scroll positions across LiveView patches.
 *
 * LiveView may patch the descendants of a scroll container without updating the
 * hooked element itself, and a browser-generated scroll during the morph would
 * overwrite the reader's position. This coordinates a patch cycle across every
 * registered element: capture once at the boundary, restore after.
 *
 * The state that spans a patch — which elements were captured, which are
 * pending a restore — lives in a `createScrollPreserver()` closure rather than
 * at module scope, so a test drives a fresh one and the production singleton is
 * a plain const. The morphdom callbacks (`patchStart`, `patchEnd`,
 * `beforeElUpdated`) are wired into LiveSocket by the entrypoint; `register`
 * gives each hooked element its per-instance controller.
 *
 * @module ui/scroll_preservation
 */

const INSTANCE_KEY = Symbol("rhcPreserveScroll");

export function createScrollPreserver() {
  const savedScrollByKey = new Map();
  let patchActive = false;
  let patchDepth = 0;
  let patchId = 0;
  let capturedPatchKeys = new Set();
  let pendingRestoreInstances = new Set();

  function patchStart() {
    patchDepth += 1;
    if (patchDepth > 1) return;

    patchActive = true;
    patchId += 1;
    capturedPatchKeys = new Set();
    pendingRestoreInstances = new Set();
  }

  function patchEnd() {
    patchDepth = Math.max(0, patchDepth - 1);
    if (patchDepth > 0) return;

    for (const instance of pendingRestoreInstances) {
      instance.queueRestore();
    }

    patchActive = false;
    capturedPatchKeys = new Set();
    pendingRestoreInstances = new Set();
  }

  function beforeElUpdated(fromEl) {
    const els = new Set();
    const closest = fromEl.closest?.("[data-preserve-scroll-target]");

    if (closest) els.add(closest);
    if (fromEl.matches?.("[data-preserve-scroll-target]")) els.add(fromEl);
    fromEl.querySelectorAll?.("[data-preserve-scroll-target]").forEach((el) => els.add(el));

    for (const el of els) {
      el[INSTANCE_KEY]?.prepareForPatch();
    }
  }

  function register(el) {
    const instance = {
      el,

      init() {
        this.el[INSTANCE_KEY] = this;
        this.savedScroll = savedScrollByKey.get(this.scrollKey()) || null;
        this.restoreFrame = null;
        this.unmuteFrame = null;
        this.observedTarget = null;
        this.mutationObserver = null;
        this.ignoreScrollEvents = false;
        this.scrollListener = () => this.captureScroll();
        this.bindScrollTarget();
        this.queueRestore();
      },

      beforeUpdate() {
        this.cancelRestoreFrame();
        this.prepareForPatch();
      },

      updated() {
        this.bindScrollTarget();
        this.queueRestore();
      },

      destroy() {
        this.captureScroll({ force: true });
        delete this.el[INSTANCE_KEY];
        this.unbindScrollTarget();
        this.cancelRestoreFrame();
        this.cancelUnmuteFrame();
      },

      prepareForPatch() {
        this.bindScrollTarget();
        this.captureScrollForPatch();
        this.muteScrollEvents();
        if (patchActive) {
          pendingRestoreInstances.add(this);
        } else {
          this.queueRestore();
        }
      },

      captureScrollForPatch() {
        const captureKey = patchActive ? `${patchId}:${this.scrollKey()}` : null;
        if (captureKey && capturedPatchKeys.has(captureKey)) return;

        this.captureScroll({ force: true });
        if (captureKey) capturedPatchKeys.add(captureKey);
      },

      captureScroll({ force = false } = {}) {
        const target = this.scrollTarget();
        if (!target || (!force && this.ignoreScrollEvents)) return;

        this.savedScroll = { left: target.scrollLeft, top: target.scrollTop };
        savedScrollByKey.set(this.scrollKey(), this.savedScroll);
      },

      bindScrollTarget() {
        const target = this.scrollTarget();
        if (target === this.observedTarget) return;

        this.unbindScrollTarget();
        this.observedTarget = target;
        if (this.observedTarget) {
          this.observedTarget.addEventListener("scroll", this.scrollListener, { passive: true });

          if (typeof MutationObserver === "function") {
            this.mutationObserver = new MutationObserver(() => this.queueRestore());
            this.mutationObserver.observe(this.observedTarget, { childList: true, subtree: true });
          }
        }
      },

      unbindScrollTarget() {
        if (this.mutationObserver) {
          this.mutationObserver.disconnect();
          this.mutationObserver = null;
        }

        if (!this.observedTarget) return;

        this.observedTarget.removeEventListener("scroll", this.scrollListener);
        this.observedTarget = null;
      },

      queueRestore() {
        this.restoreSavedScroll();
        this.cancelRestoreFrame();
        this.restoreFrame = requestAnimationFrame(() => {
          this.restoreFrame = null;
          this.restoreSavedScroll();
        });
      },

      restoreSavedScroll() {
        const target = this.scrollTarget();
        if (!target || !this.savedScroll) return;

        const left = Math.min(
          this.savedScroll.left,
          Math.max(0, target.scrollWidth - target.clientWidth),
        );
        const top = Math.min(
          this.savedScroll.top,
          Math.max(0, target.scrollHeight - target.clientHeight),
        );
        if (target.scrollLeft === left && target.scrollTop === top) return;

        this.muteScrollEvents();
        target.scrollLeft = left;
        target.scrollTop = top;
      },

      cancelRestoreFrame() {
        if (!this.restoreFrame) return;

        cancelAnimationFrame(this.restoreFrame);
        this.restoreFrame = null;
      },

      muteScrollEvents() {
        this.cancelUnmuteFrame();
        this.ignoreScrollEvents = true;
        this.unmuteFrame = requestAnimationFrame(() => {
          this.unmuteFrame = requestAnimationFrame(() => {
            this.ignoreScrollEvents = false;
            this.unmuteFrame = null;
          });
        });
      },

      cancelUnmuteFrame() {
        if (!this.unmuteFrame) return;

        cancelAnimationFrame(this.unmuteFrame);
        this.unmuteFrame = null;
        this.ignoreScrollEvents = false;
      },

      scrollTarget() {
        const target = this.el.dataset.preserveScrollTarget || "parent";

        if (target === "self") return this.el;
        if (target === "parent") return this.el.parentElement;

        return document.querySelector(target);
      },

      scrollKey() {
        return this.el.dataset.preserveScrollKey || this.el.id;
      },
    };

    instance.init();
    return instance;
  }

  return { patchStart, patchEnd, beforeElUpdated, register };
}

/** The single preserver the app wires into LiveSocket and the hook registers with. */
export const scrollPreserver = createScrollPreserver();

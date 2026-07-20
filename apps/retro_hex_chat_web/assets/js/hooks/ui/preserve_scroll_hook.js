/**
 * Preserve a scroll container's position across LiveView patches.
 *
 * Use this on a stable child when the scrollable element is owned by a parent
 * component. By default the hook preserves its parent element.
 */
const savedScrollByKey = new Map();
const HOOK_INSTANCE_KEY = Symbol("rhcPreserveScrollHook");
let patchActive = false;
let patchDepth = 0;
let patchId = 0;
let capturedPatchKeys = new Set();
let pendingRestoreHooks = new Set();

// LiveView may patch descendants of a scroll container without updating the
// hooked element itself. Capture once at the patch boundary so browser-generated
// scroll events during the morph cannot overwrite the user's position.
export function preserveScrollPatchStart() {
  patchDepth += 1;
  if (patchDepth > 1) return;

  patchActive = true;
  patchId += 1;
  capturedPatchKeys = new Set();
  pendingRestoreHooks = new Set();
}

export function preserveScrollPatchEnd() {
  patchDepth = Math.max(0, patchDepth - 1);
  if (patchDepth > 0) return;

  for (const hook of pendingRestoreHooks) {
    hook.queueRestore();
  }

  patchActive = false;
  capturedPatchKeys = new Set();
  pendingRestoreHooks = new Set();
}

export function preserveScrollBeforeElUpdated(fromEl) {
  const hookEls = new Set();
  const closestHookEl = fromEl.closest?.("[data-preserve-scroll-target]");

  if (closestHookEl) hookEls.add(closestHookEl);
  if (fromEl.matches?.("[data-preserve-scroll-target]")) hookEls.add(fromEl);
  fromEl
    .querySelectorAll?.("[data-preserve-scroll-target]")
    .forEach((el) => hookEls.add(el));

  for (const el of hookEls) {
    el[HOOK_INSTANCE_KEY]?.prepareForPatch();
  }
}

const PreserveScrollHook = {
  mounted() {
    this.el[HOOK_INSTANCE_KEY] = this;
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

  destroyed() {
    this.captureScroll({ force: true });
    delete this.el[HOOK_INSTANCE_KEY];
    this.unbindScrollTarget();
    this.cancelRestoreFrame();
    this.cancelUnmuteFrame();
  },

  prepareForPatch() {
    this.bindScrollTarget();
    this.captureScrollForPatch();
    this.muteScrollEvents();
    if (patchActive) {
      pendingRestoreHooks.add(this);
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

    this.savedScroll = {
      left: target.scrollLeft,
      top: target.scrollTop,
    };
    savedScrollByKey.set(this.scrollKey(), this.savedScroll);
  },

  bindScrollTarget() {
    const target = this.scrollTarget();
    if (target === this.observedTarget) return;

    this.unbindScrollTarget();
    this.observedTarget = target;
    if (this.observedTarget) {
      this.observedTarget.addEventListener("scroll", this.scrollListener, {
        passive: true,
      });

      if (typeof MutationObserver === "function") {
        this.mutationObserver = new MutationObserver(() => this.queueRestore());
        this.mutationObserver.observe(this.observedTarget, {
          childList: true,
          subtree: true,
        });
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

export default PreserveScrollHook;

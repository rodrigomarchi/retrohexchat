/**
 * Fullscreen toggle for the virtual space shell.
 *
 * One translucent button both enters and exits fullscreen on the space shell
 * element. State is derived from the document's `fullscreenchange` (never
 * assumed from the click), so exiting via Esc or any other UA affordance keeps
 * the button glyph in sync — the `data-fullscreen` attribute on the button
 * drives the enter/exit icon swap in CSS. WebKit-prefixed fallbacks cover
 * Safari versions that predate the unprefixed API.
 * @module space/fullscreen
 */
import { log } from "../logger.js";

export class FullscreenToggleController {
  /**
   * @param {object} opts
   * @param {HTMLElement} opts.button the `[data-space-fullscreen-toggle]` element
   * @param {HTMLElement} opts.target the element to present fullscreen (the space shell)
   * @param {Document} [opts.doc] injected document (tests)
   */
  constructor({ button, target, doc } = {}) {
    this._button = button;
    this._target = target;
    this._doc = doc ?? document;
    this._onClick = this._onClick.bind(this);
    this._onChange = this._onChange.bind(this);
  }

  attach() {
    if (!this._button || !this._target) return;
    this._button.addEventListener("click", this._onClick);
    this._doc.addEventListener("fullscreenchange", this._onChange);
    this._doc.addEventListener("webkitfullscreenchange", this._onChange);
    this._sync();
  }

  detach() {
    if (!this._button) return;
    this._button.removeEventListener("click", this._onClick);
    this._doc.removeEventListener("fullscreenchange", this._onChange);
    this._doc.removeEventListener("webkitfullscreenchange", this._onChange);
  }

  _onClick() {
    if (this._active()) {
      const exit = this._doc.exitFullscreen ?? this._doc.webkitExitFullscreen;
      exit?.call(this._doc);
      return;
    }

    const request = this._target.requestFullscreen ?? this._target.webkitRequestFullscreen;
    const result = request?.call(this._target);
    // The UA may reject (permission, iframe policy); surface it, never swallow.
    result?.catch?.((error) => log.warn("[space] fullscreen request rejected", error));
  }

  _onChange() {
    this._sync();
  }

  _active() {
    const el = this._doc.fullscreenElement ?? this._doc.webkitFullscreenElement ?? null;
    return el === this._target;
  }

  _sync() {
    if (this._active()) this._button.setAttribute("data-fullscreen", "");
    else this._button.removeAttribute("data-fullscreen");
  }
}

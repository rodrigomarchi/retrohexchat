/**
 * Board modal state. Holds the currently open `space_modal` payload (title +
 * authorial board asset) and closes on Escape. The hook renders the asset from
 * the sprite atlas; this controller only owns open/close state.
 * @module space/modal
 */

export class ModalController {
  /** @param {{onChange?: (modal: object|null) => void, target?: EventTarget}} opts */
  constructor({ onChange, target } = {}) {
    this._onChange = onChange ?? (() => {});
    this._target = target ?? window;
    this._current = null;
    this._onKeyDown = this._onKeyDown.bind(this);
  }

  attach() {
    this._target.addEventListener("keydown", this._onKeyDown);
  }

  detach() {
    this._target.removeEventListener("keydown", this._onKeyDown);
  }

  open(payload) {
    this._current = payload;
    this._onChange(this._current);
  }

  close() {
    if (this._current === null) return;
    this._current = null;
    this._onChange(null);
  }

  isOpen() {
    return this._current !== null;
  }

  current() {
    return this._current;
  }

  _onKeyDown(event) {
    if (event.key === "Escape" && this.isOpen()) {
      event.preventDefault();
      this.close();
    }
  }
}

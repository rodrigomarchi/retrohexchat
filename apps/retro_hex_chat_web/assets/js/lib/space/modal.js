/**
 * Space modal state. Holds the currently open `space_modal` payload and closes
 * it on Escape. Two kinds: a board (title + an authorial asset the hook draws
 * from the atlas) and a `confirm` question a gate asks before it takes anyone
 * anywhere, whose Yes calls `onConfirm(action)`.
 *
 * A confirm answers Enter/`y` and Escape/`n`, listening in the capture phase
 * and stopping the key there: the line you type in below the map binds Enter
 * on the window, and a Yes must not also focus it.
 * @module space/modal
 */

const CONFIRM_KEYS = new Set(["Enter", "y", "Y"]);
const CANCEL_KEYS = new Set(["Escape", "n", "N"]);

export class ModalController {
  /**
   * @param {{onChange?: (modal: object|null) => void, onConfirm?: (action: string) => void, target?: EventTarget}} opts
   */
  constructor({ onChange, onConfirm, target } = {}) {
    this._onChange = onChange ?? (() => {});
    this._onConfirm = onConfirm ?? (() => {});
    this._target = target ?? window;
    this._current = null;
    this._onKeyDown = this._onKeyDown.bind(this);
  }

  attach() {
    this._target.addEventListener("keydown", this._onKeyDown, true);
  }

  detach() {
    this._target.removeEventListener("keydown", this._onKeyDown, true);
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

  /** Answer an open confirm with Yes: close it, then act on its action. */
  confirm() {
    const action = this._current?.kind === "confirm" ? this._current.action : null;
    this.close();
    if (action) this._onConfirm(action);
  }

  isOpen() {
    return this._current !== null;
  }

  current() {
    return this._current;
  }

  _onKeyDown(event) {
    if (!this.isOpen()) return;

    if (this._current.kind === "confirm") {
      if (CONFIRM_KEYS.has(event.key)) {
        this._swallow(event);
        this.confirm();
      } else if (CANCEL_KEYS.has(event.key)) {
        this._swallow(event);
        this.close();
      }
      return;
    }

    if (event.key === "Escape") {
      event.preventDefault();
      this.close();
    }
  }

  _swallow(event) {
    event.preventDefault();
    event.stopPropagation();
  }
}

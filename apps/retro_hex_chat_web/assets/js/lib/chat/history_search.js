/**
 * The reverse history-search panel (Ctrl+R) — a controller, no LiveView.
 *
 * Owns the `#hist-search-panel` DOM: showing and hiding it, binding the search
 * field, and writing a match back into the composer. The actual search is a
 * port (the history manager), and closing hands the value back through a
 * callback so the hook can push `input_changed` and re-fit the textarea.
 *
 * @module chat/history_search
 */

export function createHistorySearch({
  input,
  search,
  resize,
  onClose,
  panelId = "hist-search-panel",
}) {
  let active = false;
  let original;
  let inputHandler = null;
  let keydownHandler = null;

  const panel = () => document.getElementById(panelId);

  function setNoMatch(bar, visible) {
    const noMatch = bar?.querySelector(".history-no-match");
    if (!noMatch) return;
    noMatch.classList.toggle("history-no-match--visible", visible);
    noMatch.classList.toggle("u-hidden", !visible);
  }

  function onInput(query) {
    const bar = panel();

    if (!query) {
      setNoMatch(bar, false);
      return;
    }

    const match = search(query);
    if (match) {
      input.value = match;
      resize();
      setNoMatch(bar, false);
    } else {
      setNoMatch(bar, true);
    }
  }

  const controller = {
    get active() {
      return active;
    },

    toggle() {
      if (active) this.close(false);
      else this.open();
    },

    open() {
      const bar = panel();
      if (!bar) return;

      active = true;
      original = input.value;
      bar.classList.remove("u-hidden");
      bar.classList.add("hist-search-panel--open");
      setNoMatch(bar, false);

      const searchInput = bar.querySelector(".history-search-input");
      if (!searchInput) return;

      searchInput.value = "";
      searchInput.focus();

      if (inputHandler) {
        searchInput.removeEventListener("input", inputHandler);
        searchInput.removeEventListener("keydown", keydownHandler);
      }

      inputHandler = (e) => onInput(e.target.value);
      keydownHandler = (e) => {
        if (e.key === "Enter") {
          e.preventDefault();
          e.stopPropagation();
          this.close(false);
        } else if (e.key === "Escape") {
          e.preventDefault();
          e.stopPropagation();
          this.close(true);
        }
      };

      searchInput.addEventListener("input", inputHandler);
      searchInput.addEventListener("keydown", keydownHandler);
    },

    close(cancel) {
      active = false;
      const bar = panel();
      if (bar) {
        bar.classList.remove("hist-search-panel--open");
        bar.classList.add("u-hidden");
      }

      let committed;
      if (cancel && original !== undefined) {
        input.value = original;
        committed = original;
      } else if (!cancel) {
        committed = input.value;
      }

      original = undefined;
      onClose(committed);
    },
  };

  return controller;
}

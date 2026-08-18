/**
 * The formatting toolbar controller — no LiveView.
 *
 * Uses mousedown (not click) with preventDefault() to avoid stealing focus from
 * the chat input. Owns the compact popover, the B/I/U buttons, the colour
 * dropdown and swatch selection. The hook in hooks/chat/format_toolbar_hook.js
 * binds this to the toolbar element.
 */
import { insertAtCursor } from "./input.js";
import { IRC_FORMAT_CODES } from "./irc_format.js";
import { MARKDOWN_FORMATS, applyMarkdownFormat } from "./markdown_format.js";

export function createFormatToolbar(el) {
  const toolbar = {
    el,

    mount() {
      this.open = false;
      this.colorOpen = false;
      this.refreshElements();

      this._onMouseDown = (e) => this.handlePointerAction(e);
      this._onClick = (e) => this.handleClick(e);
      this._onKeyDown = (e) => this.handleKeyDown(e);
      this._onDocumentMouseDown = (e) => this.handleDocumentMouseDown(e);
      this._onDocumentKeyDown = (e) => this.handleDocumentKeyDown(e);

      this.el.addEventListener("mousedown", this._onMouseDown);
      this.el.addEventListener("click", this._onClick);
      this.el.addEventListener("keydown", this._onKeyDown);
      document.addEventListener("mousedown", this._onDocumentMouseDown);
      document.addEventListener("keydown", this._onDocumentKeyDown);
    },

    reconcile() {
      this.refreshElements();
      this.applyState();
    },

    destroy() {
      this.el.removeEventListener("mousedown", this._onMouseDown);
      this.el.removeEventListener("click", this._onClick);
      this.el.removeEventListener("keydown", this._onKeyDown);
      document.removeEventListener("mousedown", this._onDocumentMouseDown);
      document.removeEventListener("keydown", this._onDocumentKeyDown);
    },

    refreshElements() {
      this.toggle = this.el.querySelector("[data-format-toolbar-toggle]");
      this.panel = this.el.querySelector("[data-format-toolbar-panel]");
      this.colorButton = this.el.querySelector("[data-format-code='color']");
      this.colorDropdown = this.el.querySelector("[data-format-color-dropdown]");
    },

    handlePointerAction(e) {
      const action = this.resolveAction(e.target);
      if (!action) return;

      if (action.type === "close-panel") {
        e.preventDefault();
        return;
      }

      if (action.type === "live-action") {
        e.preventDefault();
        return;
      }

      e.preventDefault();
      this.runAction(action);
    },

    handleClick(e) {
      if (!(e.target instanceof Element)) return;

      const closePanel = e.target.closest("[data-format-toolbar-close]");
      if (closePanel && this.el.contains(closePanel)) {
        this.closePanel();
      }
    },

    handleKeyDown(e) {
      if (e.key !== "Enter" && e.key !== " ") return;

      const action = this.resolveAction(e.target);
      if (!action) return;
      if (action.type === "live-action") return;
      if (action.type === "close-panel") return;

      e.preventDefault();
      this.runAction(action);
    },

    handleDocumentMouseDown(e) {
      if (!this.el.contains(e.target)) {
        this.closePanel();
      }
    },

    handleDocumentKeyDown(e) {
      if (e.key === "Escape" && this.open) {
        e.preventDefault();
        this.closePanel({ focusInput: true });
      }
    },

    resolveAction(target) {
      if (!(target instanceof Element)) return null;

      const toggle = target.closest("[data-format-toolbar-toggle]");
      if (toggle && this.el.contains(toggle)) return { type: "toggle" };

      const swatch = target.closest("[data-format-color-swatch]");
      if (swatch && this.el.contains(swatch)) return { type: "color-swatch", el: swatch };

      const closePanel = target.closest("[data-format-toolbar-close]");
      if (closePanel && this.el.contains(closePanel)) return { type: "close-panel" };

      const liveAction = target.closest("[data-format-toolbar-live]");
      if (liveAction && this.el.contains(liveAction)) return { type: "live-action" };

      const btn = target.closest(".format-btn");
      if (btn && this.el.contains(btn)) return { type: "format", el: btn };

      return null;
    },

    runAction(action) {
      if (action.type === "toggle") {
        this.togglePanel();
        return;
      }

      if (action.type === "color-swatch") {
        this.insertColor(action.el);
        return;
      }

      if (action.type === "close-panel") {
        this.closePanel();
        return;
      }

      const formatCode = action.el.dataset.formatCode;
      if (formatCode === "color") {
        this.toggleColorDropdown();
        return;
      }

      this.insertFormatCode(formatCode);
    },

    togglePanel() {
      if (this.open) {
        this.closePanel();
      } else {
        this.openPanel();
      }
    },

    openPanel() {
      this.open = true;
      this.applyState();
    },

    closePanel({ focusInput = false } = {}) {
      this.open = false;
      this.colorOpen = false;
      this.applyState();

      if (focusInput) {
        this.focusInput();
      }
    },

    toggleColorDropdown() {
      this.colorOpen = !this.colorOpen;
      this.applyState();
    },

    closeColorDropdown() {
      this.colorOpen = false;
      this.applyState();
    },

    insertFormatCode(formatCode) {
      const markdownFormat = MARKDOWN_FORMATS[formatCode];
      if (markdownFormat) {
        this.insertMarkdownFormat(markdownFormat);
        return;
      }

      const code = IRC_FORMAT_CODES[formatCode];
      if (!code) return;

      const input = this.chatInput();
      if (input) {
        insertAtCursor(input, code);
        input.focus();
      }
    },

    insertMarkdownFormat(format) {
      const input = this.chatInput();
      if (!input) return;

      const result = applyMarkdownFormat(
        {
          value: input.value,
          selectionStart: input.selectionStart,
          selectionEnd: input.selectionEnd,
        },
        format,
      );

      input.value = result.value;
      input.selectionStart = result.selectionStart;
      input.selectionEnd = result.selectionEnd;
      input.dispatchEvent(new Event("input", { bubbles: true }));
      input.focus();
    },

    insertColor(swatch) {
      const colorCode = swatch.dataset.colorCode;
      if (colorCode === undefined) return;

      const input = this.chatInput();
      if (input) {
        insertAtCursor(input, "\x03" + colorCode);
        input.focus();
      }

      this.closeColorDropdown();
    },

    applyState() {
      if (this.panel) {
        this.panel.classList.toggle("u-hidden", !this.open);
        this.panel.setAttribute("aria-hidden", this.open ? "false" : "true");
      }

      if (this.toggle) {
        this.toggle.setAttribute("aria-expanded", this.open ? "true" : "false");
      }

      if (this.colorDropdown) {
        this.colorDropdown.classList.toggle("format-color-dropdown--open", this.colorOpen);
      }

      if (this.colorButton) {
        this.colorButton.setAttribute("aria-expanded", this.colorOpen ? "true" : "false");
      }
    },

    chatInput() {
      return document.getElementById("chat-input");
    },

    focusInput() {
      const input = this.chatInput();
      if (input) input.focus();
    },
  };

  return toolbar;
}

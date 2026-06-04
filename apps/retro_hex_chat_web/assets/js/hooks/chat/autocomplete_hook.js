/**
 * LiveView hook for autocomplete interaction and keyboard shortcuts.
 *
 * Combines autocomplete (/, @, #) triggers and keyboard shortcuts
 * (↑/↓ history, Tab completion, IRC formatting) into a single hook
 * since LiveView allows only one phx-hook per element.
 */
import {
  insertAtCursor,
  detectTrigger,
  getArgumentContext,
  computeMaxHeight,
  autoResize,
} from "../../lib/chat/input.js";
import { createHistoryManager, isSensitiveCommand } from "../../lib/chat/history.js";
import { SHORTCUT_FORMAT_MAP } from "../../lib/chat/irc_format.js";

const AutocompleteHook = {
  mounted() {
    this.inputEl = this.el;
    this.typingTimeout = null;
    this.isTyping = false;
    this.hasNavigated = false;
    this.tooltipVisible = false;
    this.tabCycleState = null;
    this.editMode = false;

    // Enhanced history via lib
    this.historyManager = createHistoryManager({});
    this.persistedHistory = this.historyManager.getHistory();

    // Push recent commands to server
    this.pushEvent("recent_commands_loaded", { commands: this.historyManager.getRecentCommands() });

    // Auto-resize: compute max height for 5 lines
    this.maxLines = 5;
    this.maxHeight = computeMaxHeight(this.inputEl, this.maxLines);
    this.formEl = this.inputEl.closest("form");

    if (this.formEl) {
      this.formEl.addEventListener("submit", () => {
        this.rememberSubmittedInput();
      });
    }

    // PM typing indicator — debounce input events + auto-resize
    this.inputEl.addEventListener("input", () => {
      const value = this.inputEl.value;
      this.tabCycleState = null;

      autoResize(this.inputEl, this.maxHeight);

      if (!value || value.startsWith("/")) return;

      if (!this.isTyping) {
        this.isTyping = true;
        this.pushEvent("pm_typing", {});
      }

      clearTimeout(this.typingTimeout);
      this.typingTimeout = setTimeout(() => {
        this.isTyping = false;
        this.pushEvent("pm_stop_typing", {});
      }, 3000);
    });

    this.inputEl.addEventListener("keyup", (e) => {
      if (["ArrowUp", "ArrowDown", "Tab", "Enter", "Escape"].includes(e.key)) return;

      const value = this.inputEl.value;
      const trigger = this.detectTrigger(value);

      if (trigger) {
        this.hasNavigated = false;
        this.pushEvent("autocomplete_query", trigger);
        this.checkSyntaxTooltip(value);
        return;
      }

      if (this.isDropdownVisible()) {
        this.pushEvent("autocomplete_close", {});
      }

      this.checkSyntaxTooltip(value);
    });

    this.inputEl.addEventListener("keydown", (e) => {
      if (e.key === "Escape") {
        if (this.historySearchActive) {
          e.preventDefault();
          e.stopPropagation();
          this.closeHistorySearch(true);
          return;
        }
        if (this.editMode) {
          e.preventDefault();
          e.stopPropagation();
          this.editMode = false;
          this.pushEvent("cancel_edit", {});
          return;
        }
        if (this.isDropdownVisible()) {
          e.preventDefault();
          e.stopPropagation();
          this.pushEvent("autocomplete_close", {});
          this.hasNavigated = false;
        } else if (this.tooltipVisible) {
          e.preventDefault();
          e.stopPropagation();
          this.pushEvent("syntax_tooltip_dismiss", {});
          this.tooltipVisible = false;
        }
        return;
      }

      if (e.key === "Enter") {
        if (e.shiftKey) return;

        e.preventDefault();

        if (this.isDropdownVisible() && this.hasNavigated) {
          this.pushEvent("autocomplete_select_current", {});
          this.hasNavigated = false;
          return;
        }

        if (this.isDropdownVisible()) {
          this.pushEvent("autocomplete_close", {});
        }

        if (this.isTyping) {
          this.isTyping = false;
          clearTimeout(this.typingTimeout);
          this.pushEvent("pm_stop_typing", {});
        }

        if (this.tooltipVisible) {
          this.pushEvent("syntax_tooltip_dismiss", {});
          this.tooltipVisible = false;
        }

        this.rememberSubmittedInput();

        const form = this.formEl || this.inputEl.closest("form");
        if (form) {
          form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
        }
      }

      // Ctrl+R — reverse history search
      if (e.key === "r" && e.ctrlKey && !e.altKey && !e.metaKey && !e.shiftKey) {
        e.preventDefault();
        this.toggleHistorySearch();
        return;
      }

      // Ctrl+Up/Down — enhanced history with draft preservation
      if (e.key === "ArrowUp" && e.ctrlKey) {
        e.preventDefault();
        this.historyUp();
        return;
      }

      if (e.key === "ArrowDown" && e.ctrlKey) {
        e.preventDefault();
        this.historyDown();
        return;
      }

      // Arrow keys — navigate dropdown if visible, otherwise history/edit
      if (e.key === "ArrowUp") {
        e.preventDefault();
        if (this.isDropdownVisible()) {
          this.hasNavigated = true;
          this.pushEvent("autocomplete_navigate", { direction: "up" });
          this.scrollSelectedIntoView();
        } else if (this.inputEl.value === "") {
          // Empty input + ↑ = trigger edit mode for last own message
          this.pushEvent("edit_last_message", {});
        } else {
          this.pushEvent("history_navigate", { direction: "up" });
        }
        return;
      }

      if (e.key === "ArrowDown") {
        e.preventDefault();
        if (this.isDropdownVisible()) {
          this.hasNavigated = true;
          this.pushEvent("autocomplete_navigate", { direction: "down" });
          this.scrollSelectedIntoView();
        } else {
          this.pushEvent("history_navigate", { direction: "down" });
        }
        return;
      }

      if (e.key === "Tab") {
        e.preventDefault();

        if (this.isDropdownVisible()) {
          this.pushEvent("autocomplete_select_current", {});
          this.hasNavigated = false;
          return;
        }

        if (this.tabCycleState) {
          this.tabCycleState.index =
            (this.tabCycleState.index + 1) % this.tabCycleState.matches.length;
          const match = this.tabCycleState.matches[this.tabCycleState.index];
          const suffix = this.tabCycleState.isStart ? ": " : " ";
          this.inputEl.value = match + suffix;
          this.inputEl.dispatchEvent(new Event("input", { bubbles: true }));
          const state = this.tabCycleState;
          setTimeout(() => {
            this.tabCycleState = state;
          }, 0);
          return;
        }

        const value = this.inputEl.value;
        const isStart = true;
        this.pushEvent("tab_complete", { partial: value, is_start: isStart });
        return;
      }

      // IRC formatting shortcuts (Ctrl+Shift+key)
      if (e.ctrlKey && e.shiftKey && !e.altKey && !e.metaKey) {
        const code = SHORTCUT_FORMAT_MAP[e.key.toLowerCase()];
        if (code) {
          e.preventDefault();
          e.stopPropagation();
          this.insertAtCursor(code);
        }
      }
    });

    // Handle server events
    this.handleEvent("tab_matches", ({ matches, is_start }) => {
      if (matches.length === 0) return;

      this.tabCycleState = {
        original: this.inputEl.value,
        matches: matches,
        index: 0,
        isStart: is_start,
      };

      const suffix = is_start ? ": " : " ";
      this.inputEl.value = matches[0] + suffix;
      this.inputEl.dispatchEvent(new Event("input", { bubbles: true }));
      const state = this.tabCycleState;
      setTimeout(() => {
        this.tabCycleState = state;
      }, 0);
    });

    this.handleEvent("set_input", ({ value }) => {
      this.inputEl.value = value;
      this.inputEl.dispatchEvent(new Event("input", { bubbles: true }));
      autoResize(this.inputEl, this.maxHeight);
    });

    this.handleEvent("insert_emoji", ({ char }) => {
      this.insertAtCursor(char);
      autoResize(this.inputEl, this.maxHeight);
      this.inputEl.focus();
    });

    this.handleEvent("enter_edit_mode", ({ content }) => {
      this.editMode = true;
      this.inputEl.value = content;
      this.inputEl.dispatchEvent(new Event("input", { bubbles: true }));
      autoResize(this.inputEl, this.maxHeight);
      this.inputEl.focus();
    });

    this.handleEvent("exit_edit_mode", () => {
      this.editMode = false;
    });

    this.handleEvent("focus_input", () => {
      this.inputEl.focus();
    });

    this.handleEvent("clear_input", () => {
      this.inputEl.value = "";
      this.inputEl.dispatchEvent(new Event("input", { bubbles: true }));
      autoResize(this.inputEl, this.maxHeight);
      if (this.tooltipVisible) {
        this.pushEvent("syntax_tooltip_dismiss", {});
        this.tooltipVisible = false;
      }
      if (this.isDropdownVisible()) {
        this.pushEvent("autocomplete_close", {});
        this.hasNavigated = false;
      }
    });
  },

  updated() {
    const dropdown = document.getElementById("autocomplete-dropdown");
    if (!dropdown) return;

    const rect = dropdown.getBoundingClientRect();
    if (rect.top < 0) {
      const windowEl = dropdown.querySelector(".window");
      if (windowEl) {
        const available = rect.bottom;
        if (available > 60) {
          windowEl.style.maxHeight = available + "px";
        }
      }
    }
  },

  // ── Syntax tooltip ────────────────────────────────────

  checkSyntaxTooltip(value) {
    if (!value || !value.startsWith("/")) {
      if (this.tooltipVisible) {
        this.pushEvent("syntax_tooltip_dismiss", {});
        this.tooltipVisible = false;
      }
      return;
    }

    // Show tooltip as soon as command name has 2+ chars, even without space
    const spaceIdx = value.indexOf(" ");
    let command, args;

    if (spaceIdx > 1) {
      command = value.slice(1, spaceIdx);
      args = value.slice(spaceIdx + 1);
    } else if (spaceIdx === -1 && value.length > 2) {
      command = value.slice(1);
      args = "";
    } else {
      return;
    }

    this.tooltipVisible = true;
    this.pushEvent("syntax_tooltip_query", { command, args });
  },

  // ── Dropdown helpers ────────────────────────────────────

  isDropdownVisible() {
    return !!document.getElementById("autocomplete-dropdown");
  },

  scrollSelectedIntoView() {
    requestAnimationFrame(() => {
      const item = document.querySelector("#autocomplete-dropdown .autocomplete-item.selected");
      if (item) item.scrollIntoView({ block: "nearest" });
    });
  },

  // ── Delegated methods ──────────────────────────────────

  detectTrigger(value) {
    return detectTrigger(
      value,
      this.inputEl.selectionStart || (value ? value.length : 0),
      getArgumentContext,
    );
  },

  insertAtCursor(text) {
    insertAtCursor(this.inputEl, text);
  },

  getArgumentContext(cmdName) {
    return getArgumentContext(cmdName);
  },

  isSensitiveCommand(text) {
    return isSensitiveCommand(text);
  },

  // ── History (delegated) ────────────────────────────────

  rememberSubmittedInput() {
    const value = this.inputEl.value.trimEnd();
    if (value.trim()) {
      this.historyManager.save(value);
      this.persistedHistory = this.historyManager.getHistory();
    }
    if (value.startsWith("/") && !isSensitiveCommand(value)) {
      const cmdName = value.slice(1).split(/\s+/)[0].toLowerCase();
      if (cmdName) {
        this.historyManager.saveRecentCommand(cmdName);
        this.pushEvent("recent_commands_loaded", {
          commands: this.historyManager.getRecentCommands(),
        });
      }
    }

    this.historyManager.resetBrowsing();
  },

  historyUp() {
    const result = this.historyManager.up(this.inputEl.value, this.inputEl.selectionStart);
    if (result) {
      this.inputEl.value = result.value;
      this.inputEl.dispatchEvent(new Event("input", { bubbles: true }));
      autoResize(this.inputEl, this.maxHeight);
    }
  },

  historyDown() {
    const result = this.historyManager.down();
    if (result) {
      this.inputEl.value = result.value;
      if (result.cursor !== undefined) {
        this.inputEl.selectionStart = result.cursor;
        this.inputEl.selectionEnd = result.cursor;
      }
      this.inputEl.dispatchEvent(new Event("input", { bubbles: true }));
      autoResize(this.inputEl, this.maxHeight);
    }
  },

  // ── History search (DOM-coupled) ───────────────────────

  historySearchActive: false,

  toggleHistorySearch() {
    if (this.historySearchActive) {
      this.closeHistorySearch(false);
    } else {
      this.openHistorySearch();
    }
  },

  openHistorySearch() {
    const bar = document.getElementById("hist-search-panel");
    if (!bar) return;

    this.historySearchActive = true;
    this.historySearchOriginal = this.inputEl.value;

    bar.classList.remove("u-hidden");
    bar.classList.add("hist-search-panel--open");

    const noMatch = bar.querySelector(".history-no-match");
    if (noMatch) noMatch.classList.add("u-hidden");

    const searchInput = bar.querySelector(".history-search-input");
    if (searchInput) {
      searchInput.value = "";
      searchInput.focus();

      if (this._histSearchInputHandler) {
        searchInput.removeEventListener("input", this._histSearchInputHandler);
        searchInput.removeEventListener("keydown", this._histSearchKeydownHandler);
      }

      this._histSearchInputHandler = (e) => {
        this.onHistorySearchInput(e.target.value);
      };
      this._histSearchKeydownHandler = (e) => {
        if (e.key === "Enter") {
          e.preventDefault();
          e.stopPropagation();
          this.closeHistorySearch(false);
        } else if (e.key === "Escape") {
          e.preventDefault();
          e.stopPropagation();
          this.closeHistorySearch(true);
        }
      };

      searchInput.addEventListener("input", this._histSearchInputHandler);
      searchInput.addEventListener("keydown", this._histSearchKeydownHandler);
    }
  },

  closeHistorySearch(cancel) {
    this.historySearchActive = false;
    const bar = document.getElementById("hist-search-panel");
    if (bar) {
      bar.classList.remove("hist-search-panel--open");
      bar.classList.add("u-hidden");
    }

    if (cancel && this.historySearchOriginal !== undefined) {
      this.inputEl.value = this.historySearchOriginal;
      this.pushEvent("input_changed", { input: this.historySearchOriginal });
    } else if (!cancel) {
      this.pushEvent("input_changed", { input: this.inputEl.value });
    }
    this.historySearchOriginal = undefined;
    this.inputEl.focus();
    autoResize(this.inputEl, this.maxHeight);
  },

  onHistorySearchInput(query) {
    const bar = document.getElementById("hist-search-panel");
    const noMatch = bar ? bar.querySelector(".history-no-match") : null;

    if (!query) {
      if (noMatch) {
        noMatch.classList.remove("history-no-match--visible");
        noMatch.classList.add("u-hidden");
      }
      return;
    }

    const match = this.historyManager.search(query);

    if (match) {
      this.inputEl.value = match;
      autoResize(this.inputEl, this.maxHeight);
      if (noMatch) {
        noMatch.classList.remove("history-no-match--visible");
        noMatch.classList.add("u-hidden");
      }
    } else {
      if (noMatch) {
        noMatch.classList.add("history-no-match--visible");
        noMatch.classList.remove("u-hidden");
      }
    }
  },

  // ── Compat aliases (used by tests) ─────────────────────

  loadPersistedHistory() {
    this.historyManager.load();
    this.persistedHistory = this.historyManager.getHistory();
    return this.persistedHistory;
  },

  saveToPersistedHistory(text) {
    this.historyManager.save(text);
    this.persistedHistory = this.historyManager.getHistory();
  },

  loadRecentCommands() {
    return this.historyManager.getRecentCommands();
  },

  saveRecentCommand(cmdName) {
    this.historyManager.saveRecentCommand(cmdName);
  },

  computeMaxHeight() {
    this.maxHeight = computeMaxHeight(this.inputEl, this.maxLines || 5);
  },

  autoResize() {
    autoResize(this.inputEl, this.maxHeight);
  },
};

export default AutocompleteHook;

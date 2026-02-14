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
} from "../lib/input.js";
import { createHistoryManager, isSensitiveCommand } from "../lib/history.js";
import { SHORTCUT_FORMAT_MAP } from "../lib/irc_format.js";

const AutocompleteHook = {
  mounted() {
    this.inputEl = this.el;
    this.typingTimeout = null;
    this.isTyping = false;
    this.dropdownVisible = false;
    this.tooltipVisible = false;
    this.tabCycleState = null;

    // Enhanced history via lib
    this.historyManager = createHistoryManager({});
    this.persistedHistory = this.historyManager.getHistory();

    // Push recent commands to server
    this.pushEvent("recent_commands_loaded", { commands: this.historyManager.getRecentCommands() });

    // Auto-resize: compute max height for 5 lines
    this.maxLines = 5;
    this.maxHeight = computeMaxHeight(this.inputEl, this.maxLines);

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

    this.inputEl.addEventListener("keyup", () => {
      const value = this.inputEl.value;
      const trigger = this.detectTrigger(value);

      if (trigger) {
        this.pushEvent("autocomplete_query", trigger);
        return;
      }

      if (this.dropdownVisible) {
        this.pushEvent("autocomplete_close", {});
      }

      if (!this.dropdownVisible) {
        this.checkSyntaxTooltip(value);
      }
    });

    this.inputEl.addEventListener("keydown", (e) => {
      if (e.key === "Escape") {
        if (this.historySearchActive) {
          e.preventDefault();
          this.closeHistorySearch(true);
          return;
        }
        if (this.dropdownVisible) {
          e.preventDefault();
          this.pushEvent("autocomplete_close", {});
        } else if (this.tooltipVisible) {
          e.preventDefault();
          this.pushEvent("syntax_tooltip_dismiss", {});
          this.tooltipVisible = false;
        }
        return;
      }

      if (e.key === "Enter") {
        if (e.shiftKey) return;

        e.preventDefault();

        if (this.isTyping) {
          this.isTyping = false;
          clearTimeout(this.typingTimeout);
          this.pushEvent("pm_stop_typing", {});
        }

        if (this.dropdownVisible) return;

        const value = this.inputEl.value;
        if (value.trim()) {
          this.historyManager.save(value);
          this.persistedHistory = this.historyManager.getHistory();
        }
        if (value.startsWith("/")) {
          const cmdName = value.slice(1).split(" ")[0];
          if (cmdName) this.historyManager.saveRecentCommand(cmdName);
        }

        this.historyManager.resetBrowsing();

        const form = this.inputEl.closest("form");
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

      // Arrow keys — navigate dropdown if visible, otherwise history
      if (e.key === "ArrowUp") {
        e.preventDefault();
        if (this.dropdownVisible) {
          this.pushEvent("autocomplete_navigate", { direction: "up" });
        } else {
          this.pushEvent("history_navigate", { direction: "up" });
        }
        return;
      }

      if (e.key === "ArrowDown") {
        e.preventDefault();
        if (this.dropdownVisible) {
          this.pushEvent("autocomplete_navigate", { direction: "down" });
        } else {
          this.pushEvent("history_navigate", { direction: "down" });
        }
        return;
      }

      if (e.key === "Tab") {
        e.preventDefault();

        if (this.dropdownVisible) {
          this.pushEvent("autocomplete_select_current", {});
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
    this.handleEvent("autocomplete_results", ({ results }) => {
      this.dropdownVisible = results.length > 0;
      if (this.dropdownVisible && this.tooltipVisible) {
        this.tooltipVisible = false;
      }
    });

    this.handleEvent("autocomplete_closed", () => {
      this.dropdownVisible = false;
    });

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
    this.historySearchActive = true;
    this.historySearchOriginal = this.inputEl.value;

    const bar = document.getElementById("hist-search-panel");
    if (bar) {
      bar.style.display = "flex";
      const searchInput = bar.querySelector(".history-search-input");
      if (searchInput) {
        searchInput.value = "";
        searchInput.focus();
        searchInput.addEventListener("input", (e) => {
          this.onHistorySearchInput(e.target.value);
        });
        searchInput.addEventListener("keydown", (e) => {
          if (e.key === "Enter") {
            e.preventDefault();
            this.closeHistorySearch(false);
          } else if (e.key === "Escape") {
            e.preventDefault();
            this.closeHistorySearch(true);
          }
        });
      }
    }
  },

  closeHistorySearch(cancel) {
    this.historySearchActive = false;
    const bar = document.getElementById("hist-search-panel");
    if (bar) bar.style.display = "none";

    if (cancel && this.historySearchOriginal !== undefined) {
      this.inputEl.value = this.historySearchOriginal;
      this.inputEl.dispatchEvent(new Event("input", { bubbles: true }));
    }
    this.historySearchOriginal = undefined;
    this.inputEl.focus();
    autoResize(this.inputEl, this.maxHeight);
  },

  onHistorySearchInput(query) {
    const bar = document.getElementById("hist-search-panel");
    const noMatch = bar ? bar.querySelector(".history-no-match") : null;

    if (!query) {
      if (noMatch) noMatch.style.display = "none";
      return;
    }

    const match = this.historyManager.search(query);

    if (match) {
      this.inputEl.value = match;
      this.inputEl.dispatchEvent(new Event("input", { bubbles: true }));
      autoResize(this.inputEl, this.maxHeight);
      if (noMatch) noMatch.style.display = "none";
    } else {
      if (noMatch) noMatch.style.display = "inline";
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

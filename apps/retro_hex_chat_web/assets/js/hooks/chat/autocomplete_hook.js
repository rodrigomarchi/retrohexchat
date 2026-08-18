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
  parseSlashCommand,
} from "../../lib/chat/input.js";
import { createHistoryManager, isSensitiveCommand } from "../../lib/chat/history.js";
import { INTENT, resolveComposerKey } from "../../lib/chat/composer.js";

const MOBILE_BREAKPOINT = 768;
const DESKTOP_MAX_LINES = 5;
const MOBILE_MAX_LINES = 3;

const AutocompleteHook = {
  mounted() {
    this.inputEl = this.el;
    this.typingTimeout = null;
    this.isTyping = false;
    this.hasNavigated = false;
    this.tooltipVisible = false;
    this.tabCycleState = null;
    this.editMode = false;

    // Enhanced history via lib. Durable state comes from the server; this hook
    // keeps only an in-memory copy for fast Ctrl+Up/Ctrl+R interactions.
    this.historyDatasetKey = null;
    this.historyManager = createHistoryManager({});
    this.syncHistoryFromDataset();

    // Auto-resize: mobile keeps the composer compact so autocomplete, reply and
    // syntax panels still have room above the keyboard.
    this.configureTextareaSizing();
    autoResize(this.inputEl, this.maxHeight);
    this.onViewportResize = () => {
      this.configureTextareaSizing();
      autoResize(this.inputEl, this.maxHeight);
    };
    window.addEventListener("resize", this.onViewportResize);
    window.addEventListener("orientationchange", this.onViewportResize);
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

    this.inputEl.addEventListener("keydown", (e) => this._handleComposerKeydown(e));

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

    // LiveView skips attribute patches on a focused input, so a placeholder
    // change (e.g. /join switching the active channel while typing) never
    // lands through the DOM diff — the server pushes it explicitly instead.
    this.handleEvent("composer_placeholder", ({ placeholder }) => {
      this.serverPlaceholder = placeholder;
      this.inputEl.placeholder = placeholder;
      autoResize(this.inputEl, this.maxHeight);
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

  destroyed() {
    window.removeEventListener("resize", this.onViewportResize);
    window.removeEventListener("orientationchange", this.onViewportResize);
    clearTimeout(this.typingTimeout);
  },

  // ── Composer keydown (resolver-driven) ─────────────────

  _handleComposerKeydown(e) {
    const intents = resolveComposerKey(e, {
      historySearchActive: this.historySearchActive,
      editMode: this.editMode,
      dropdownVisible: this.isDropdownVisible(),
      hasNavigated: this.hasNavigated,
      isTyping: this.isTyping,
      tooltipVisible: this.tooltipVisible,
      tabCycleActive: !!this.tabCycleState,
      value: this.inputEl.value,
    });
    this._applyComposerIntents(e, intents);
  },

  _applyComposerIntents(e, intents) {
    for (const intent of intents) {
      switch (intent.type) {
        case INTENT.PREVENT_DEFAULT:
          e.preventDefault();
          break;
        case INTENT.STOP_PROPAGATION:
          e.stopPropagation();
          break;
        case INTENT.PUSH:
          this.pushEvent(intent.event, intent.payload);
          break;
        case INTENT.SET_STATE:
          Object.assign(this, intent.patch);
          break;
        case INTENT.ACTION:
          this._runComposerAction(intent.name, intent.args);
          break;
      }
    }
  },

  _runComposerAction(name, args) {
    switch (name) {
      case "closeHistorySearch":
        this.closeHistorySearch(...args);
        break;
      case "toggleHistorySearch":
        this.toggleHistorySearch();
        break;
      case "historyUp":
        this.historyUp();
        break;
      case "historyDown":
        this.historyDown();
        break;
      case "scrollSelectedIntoView":
        this.scrollSelectedIntoView();
        break;
      case "rememberSubmittedInput":
        this.rememberSubmittedInput();
        break;
      case "insertAtCursor":
        this.insertAtCursor(...args);
        break;
      case "stopTyping":
        clearTimeout(this.typingTimeout);
        this.pushEvent("pm_stop_typing", {});
        break;
      case "submitForm": {
        const form = this.formEl || this.inputEl.closest("form");
        if (form) form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
        break;
      }
      case "tabCycle":
        this._advanceTabCycle();
        break;
    }
  },

  _advanceTabCycle() {
    this.tabCycleState.index = (this.tabCycleState.index + 1) % this.tabCycleState.matches.length;
    const match = this.tabCycleState.matches[this.tabCycleState.index];
    const suffix = this.tabCycleState.isStart ? ": " : " ";
    this.inputEl.value = match + suffix;
    this.inputEl.dispatchEvent(new Event("input", { bubbles: true }));
    const state = this.tabCycleState;
    setTimeout(() => {
      this.tabCycleState = state;
    }, 0);
  },

  updated() {
    this.syncHistoryFromDataset();

    // LiveView's focused-input handling can re-apply a stale placeholder from
    // its cached tree on later patches; while focused, the pushed value wins.
    // Unfocused patches apply normally and become the new source of truth
    // (they also carry mode placeholders like "Notice message").
    if (document.activeElement === this.inputEl) {
      if (this.serverPlaceholder && this.inputEl.placeholder !== this.serverPlaceholder) {
        this.inputEl.placeholder = this.serverPlaceholder;
      }
    } else {
      this.serverPlaceholder = this.inputEl.placeholder;
    }

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
    const result = parseSlashCommand(value);

    if (result.kind === "none") {
      if (this.tooltipVisible) {
        this.pushEvent("syntax_tooltip_dismiss", {});
        this.tooltipVisible = false;
      }
      return;
    }

    if (result.kind === "pending") return;

    this.tooltipVisible = true;
    this.pushEvent("syntax_tooltip_query", { command: result.command, args: result.args });
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

  syncHistoryFromDataset() {
    const inputHistory = this.el.dataset.inputHistory || "";
    const recentCommands = this.el.dataset.recentCommands || "";
    const datasetKey = `${inputHistory}\n${recentCommands}`;

    if (datasetKey === this.historyDatasetKey) return;

    this.historyDatasetKey = datasetKey;
    this.historyManager.load({
      history: this.readJsonList(inputHistory),
      recentCommands: this.readJsonList(recentCommands),
    });
    this.persistedHistory = this.historyManager.getHistory();
  },

  readJsonList(raw) {
    if (!raw) return [];

    try {
      const decoded = JSON.parse(raw);
      return Array.isArray(decoded) ? decoded : [];
    } catch {
      return [];
    }
  },

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

  configureTextareaSizing() {
    this.maxLines = this.maxLinesForViewport();
    this.maxHeight = computeMaxHeight(this.inputEl, this.maxLines);
  },

  maxLinesForViewport() {
    return window.innerWidth < MOBILE_BREAKPOINT ? MOBILE_MAX_LINES : DESKTOP_MAX_LINES;
  },
};

export default AutocompleteHook;

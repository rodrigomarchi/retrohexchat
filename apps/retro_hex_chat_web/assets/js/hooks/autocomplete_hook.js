/**
 * LiveView hook for autocomplete interaction and keyboard shortcuts.
 *
 * Combines autocomplete (/, @, #) triggers and keyboard shortcuts
 * (↑/↓ history, Tab completion, IRC formatting) into a single hook
 * since LiveView allows only one phx-hook per element.
 */
const AutocompleteHook = {
  mounted() {
    this.inputEl = this.el;
    this.typingTimeout = null;
    this.isTyping = false;
    this.dropdownVisible = false;
    this.tabCycleState = null;

    // Load recent commands from localStorage
    this.recentCommands = this.loadRecentCommands();
    this.pushEvent("recent_commands_loaded", { commands: this.recentCommands });

    // PM typing indicator — debounce input events
    this.inputEl.addEventListener("input", () => {
      const value = this.inputEl.value;
      // Clear tab cycling state on any input change
      this.tabCycleState = null;

      // Don't send typing for commands or empty input
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
      const value = this.inputEl.value;
      const trigger = this.detectTrigger(value);

      if (trigger) {
        this.pushEvent("autocomplete_query", trigger);
        return;
      }

      // No trigger detected — close if open
      if (this.dropdownVisible) {
        this.pushEvent("autocomplete_close", {});
      }
    });

    this.inputEl.addEventListener("keydown", (e) => {
      if (e.key === "Escape") {
        if (this.dropdownVisible) {
          e.preventDefault();
          this.pushEvent("autocomplete_close", {});
        }
        return;
      }

      if (e.key === "Enter") {
        // Clear typing indicator on submit
        if (this.isTyping) {
          this.isTyping = false;
          clearTimeout(this.typingTimeout);
          this.pushEvent("pm_stop_typing", {});
        }

        if (this.dropdownVisible) {
          // Let the server handle the selection via autocomplete_select
          // (the currently selected item is tracked server-side)
          return;
        }

        // Save command to recent commands on execution
        const value = this.inputEl.value;
        if (value.startsWith("/")) {
          const cmdName = value.slice(1).split(" ")[0];
          if (cmdName) this.saveRecentCommand(cmdName);
        }
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
          // Select the currently highlighted item in dropdown
          this.pushEvent("autocomplete_select_current", {});
          return;
        }

        // Tab cycling for nick completion (no dropdown)
        if (this.tabCycleState) {
          // Cycle to next match
          this.tabCycleState.index =
            (this.tabCycleState.index + 1) % this.tabCycleState.matches.length;
          const match = this.tabCycleState.matches[this.tabCycleState.index];
          const suffix = this.tabCycleState.isStart ? ": " : " ";
          this.inputEl.value = match + suffix;
          this.inputEl.dispatchEvent(new Event("input", { bubbles: true }));
          // Re-set tabCycleState since input event clears it
          // We need to preserve it across the synthetic input event
          const state = this.tabCycleState;
          setTimeout(() => { this.tabCycleState = state; }, 0);
          return;
        }

        // Request tab completion from server
        const value = this.inputEl.value;
        const isStart = true; // Tab complete is from start of input
        this.pushEvent("tab_complete", { partial: value, is_start: isStart });
        return;
      }

      // IRC formatting shortcuts (Ctrl+Shift+key)
      if (e.ctrlKey && e.shiftKey && !e.altKey && !e.metaKey) {
        const formatCodes = {
          b: "\x02", // Bold
          y: "\x1D", // Italic (stYle)
          u: "\x1F", // Underline
          d: "\x03", // Color (Dye)
          v: "\x16", // Reverse (reVerse)
          x: "\x0F", // Reset (Xclear)
        };

        const code = formatCodes[e.key.toLowerCase()];
        if (code) {
          e.preventDefault();
          e.stopPropagation();
          this.insertAtCursor(code);
        }
      }
    });

    // Handle server events
    this.handleEvent("autocomplete_results", ({ results, mode }) => {
      this.dropdownVisible = results.length > 0;
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
      // Preserve tab cycle state after synthetic input
      const state = this.tabCycleState;
      setTimeout(() => { this.tabCycleState = state; }, 0);
    });

    this.handleEvent("set_input", ({ value }) => {
      this.inputEl.value = value;
      this.inputEl.dispatchEvent(new Event("input", { bubbles: true }));
    });
  },

  updated() {
    // Viewport boundary detection for autocomplete dropdown
    const dropdown = document.getElementById("autocomplete-dropdown");
    if (!dropdown) return;

    const rect = dropdown.getBoundingClientRect();
    if (rect.top < 0) {
      // Dropdown extends above viewport — constrain max-height
      const windowEl = dropdown.querySelector(".window");
      if (windowEl) {
        const available = rect.bottom;
        if (available > 60) {
          windowEl.style.maxHeight = available + "px";
        }
      }
    }
  },

  detectTrigger(value) {
    if (!value) return null;

    // Command trigger: "/" at position 0
    if (value.startsWith("/") && !value.includes(" ")) {
      const partial = value.slice(1);
      return { type: "command", partial: partial };
    }

    // Command argument trigger: "/command " followed by partial arg
    if (value.startsWith("/")) {
      const spaceIdx = value.indexOf(" ");
      if (spaceIdx > 1) {
        const cmdName = value.slice(1, spaceIdx);
        const argText = value.slice(spaceIdx + 1);
        const argContext = this.getArgumentContext(cmdName);
        if (argContext && argText.length >= 0) {
          return { type: argContext, partial: argText, command: cmdName };
        }
      }
    }

    // Nick trigger: "@" at word boundary
    const cursorPos = this.inputEl.selectionStart || value.length;
    const textBeforeCursor = value.slice(0, cursorPos);

    // Scan backward for @ at word boundary
    for (let i = textBeforeCursor.length - 1; i >= 0; i--) {
      const ch = textBeforeCursor[i];
      if (ch === " " || ch === "\t") break;
      if (ch === "@") {
        const isWordBoundary = i === 0 || /\s/.test(textBeforeCursor[i - 1]);
        if (isWordBoundary) {
          const partial = textBeforeCursor.slice(i + 1);
          if (partial.length >= 1) {
            return { type: "nick", partial: partial };
          }
        }
        break;
      }
    }

    // Channel trigger: "#" at word boundary
    for (let i = textBeforeCursor.length - 1; i >= 0; i--) {
      const ch = textBeforeCursor[i];
      if (ch === " " || ch === "\t") break;
      if (ch === "#") {
        const isWordBoundary = i === 0 || /\s/.test(textBeforeCursor[i - 1]);
        if (isWordBoundary) {
          const partial = textBeforeCursor.slice(i + 1);
          if (partial.length >= 1) {
            return { type: "channel", partial: partial };
          }
        }
        break;
      }
    }

    return null;
  },

  insertAtCursor(text) {
    const el = this.inputEl;
    const start = el.selectionStart;
    const end = el.selectionEnd;
    const value = el.value;
    el.value = value.slice(0, start) + text + value.slice(end);
    el.selectionStart = el.selectionEnd = start + text.length;
    el.dispatchEvent(new Event("input", { bubbles: true }));
  },

  getArgumentContext(cmdName) {
    const nickAll = ["msg", "query", "whois", "whowas", "notice", "ctcp", "invite"];
    const nickCurrent = ["kick", "ban"];
    const channel = ["join", "part", "topic", "mode"];

    if (nickAll.includes(cmdName)) return "arg_nick";
    if (nickCurrent.includes(cmdName)) return "arg_nick";
    if (channel.includes(cmdName)) return "arg_channel";
    return null;
  },

  loadRecentCommands() {
    try {
      const stored = localStorage.getItem("retro_hex_chat_recent_commands");
      return stored ? JSON.parse(stored) : [];
    } catch {
      return [];
    }
  },

  saveRecentCommand(cmdName) {
    let recents = this.loadRecentCommands();
    recents = recents.filter((c) => c !== cmdName);
    recents.unshift(cmdName);
    recents = recents.slice(0, 5);
    this.recentCommands = recents;
    try {
      localStorage.setItem(
        "retro_hex_chat_recent_commands",
        JSON.stringify(recents),
      );
    } catch {
      // localStorage might be full or unavailable
    }
  },
};

export default AutocompleteHook;

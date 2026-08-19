/**
 * The chat composer's keydown resolver — a pure map from a key event and the
 * composer's state to an ordered list of intents.
 *
 * The autocomplete hook's keydown was a ~230-line block that interleaved state
 * reads (dropdown open? edit mode? tab cycling?) with side effects (pushEvent,
 * form submit, DOM writes, timers). This is the decision half: given the event
 * fields and a snapshot of state, it returns what should happen, in order. The
 * hook interprets the intents — that is where the DOM and LiveView live.
 *
 * @module chat/composer
 */
import { SHORTCUT_FORMAT_MAP } from "./irc_format.js";

/** Intent kinds the hook interprets. */
export const INTENT = {
  PREVENT_DEFAULT: "preventDefault",
  STOP_PROPAGATION: "stopPropagation",
  PUSH: "push", // { event, payload }
  SET_STATE: "setState", // { patch }
  ACTION: "action", // { name, args }
};

const preventDefault = () => ({ type: INTENT.PREVENT_DEFAULT });
const stopPropagation = () => ({ type: INTENT.STOP_PROPAGATION });
const push = (event, payload = {}) => ({ type: INTENT.PUSH, event, payload });
const setState = (patch) => ({ type: INTENT.SET_STATE, patch });
const action = (name, ...args) => ({ type: INTENT.ACTION, name, args });

/**
 * @param {{key: string, shiftKey?: boolean, ctrlKey?: boolean, altKey?: boolean, metaKey?: boolean}} event
 * @param {object} state
 * @param {boolean} state.historySearchActive
 * @param {boolean} state.editMode
 * @param {boolean} state.dropdownVisible
 * @param {boolean} state.hasNavigated
 * @param {boolean} state.isTyping
 * @param {boolean} state.tooltipVisible
 * @param {boolean} state.tabCycleActive
 * @param {string} state.value
 * @returns {object[]} ordered intents
 */
export function resolveComposerKey(event, state) {
  const { key } = event;

  if (key === "Escape") return escapeIntents(state);
  if (key === "Enter" && !event.shiftKey) return enterIntents(state);
  if (key === "Enter") return []; // shift+enter: newline, untouched

  if (key === "r" && event.ctrlKey && !event.altKey && !event.metaKey && !event.shiftKey) {
    return [preventDefault(), action("toggleHistorySearch")];
  }

  if (key === "ArrowUp" && event.ctrlKey) return [preventDefault(), action("historyUp")];
  if (key === "ArrowDown" && event.ctrlKey) return [preventDefault(), action("historyDown")];

  if (key === "ArrowUp") return arrowIntents(state, "up");
  if (key === "ArrowDown") return arrowIntents(state, "down");

  if (key === "Tab") return tabIntents(state);

  if (event.ctrlKey && event.shiftKey && !event.altKey && !event.metaKey) {
    const code = SHORTCUT_FORMAT_MAP[key.toLowerCase()];
    if (code) return [preventDefault(), stopPropagation(), action("insertAtCursor", code)];
  }

  return [];
}

function escapeIntents(state) {
  if (state.historySearchActive) {
    return [preventDefault(), stopPropagation(), action("closeHistorySearch", true)];
  }
  if (state.editMode) {
    return [
      preventDefault(),
      stopPropagation(),
      setState({ editMode: false }),
      push("cancel_edit"),
    ];
  }
  if (state.dropdownVisible) {
    return [
      preventDefault(),
      stopPropagation(),
      push("autocomplete_close"),
      setState({ hasNavigated: false }),
    ];
  }
  if (state.tooltipVisible) {
    return [
      preventDefault(),
      stopPropagation(),
      push("syntax_tooltip_dismiss"),
      setState({ tooltipVisible: false }),
    ];
  }
  return [];
}

function enterIntents(state) {
  const intents = [preventDefault()];

  if (state.dropdownVisible && state.hasNavigated) {
    intents.push(push("autocomplete_select_current"), setState({ hasNavigated: false }));
    return intents;
  }

  if (state.dropdownVisible) {
    intents.push(push("autocomplete_close"));
  }

  if (state.isTyping) {
    intents.push(action("stopTyping"));
  }

  if (state.tooltipVisible) {
    intents.push(push("syntax_tooltip_dismiss"), setState({ tooltipVisible: false }));
  }

  intents.push(action("rememberSubmittedInput"), action("submitForm"));
  return intents;
}

function arrowIntents(state, direction) {
  const intents = [preventDefault()];

  if (state.dropdownVisible) {
    intents.push(
      setState({ hasNavigated: true }),
      push("autocomplete_navigate", { direction }),
      action("scrollSelectedIntoView"),
    );
    return intents;
  }

  if (direction === "up" && state.value === "") {
    intents.push(push("edit_last_message"));
    return intents;
  }

  intents.push(push("history_navigate", { direction }));
  return intents;
}

function tabIntents(state) {
  const intents = [preventDefault()];

  if (state.dropdownVisible) {
    intents.push(push("autocomplete_select_current"), setState({ hasNavigated: false }));
    return intents;
  }

  if (state.tabCycleActive) {
    intents.push(action("tabCycle"));
    return intents;
  }

  intents.push(push("tab_complete", { partial: state.value, is_start: true }));
  return intents;
}

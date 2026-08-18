/**
 * Mapping a connection state to what the banner and overlay show — pure.
 *
 * The state machine lives in connection_state_machine.js; this turns the state
 * it reports into a view descriptor (banner variant and text, overlay text, and
 * whether the shell is disabled), which the hook applies to the DOM. Translated
 * here so the strings stay with the mapping.
 *
 * @module connection/connection_view
 */
import { t, jt } from "../i18n.js";

const DISABLING_STATES = ["disconnected", "reconnecting", "cancelled", "failed"];

/**
 * @param {string} state
 * @param {{attempt?: number, maxAttempts?: number, remaining?: number}} [data]
 * @returns {{
 *   banner: {visible: boolean, variant: string|null, text: string},
 *   overlay: {visible: boolean, info: string, countdown: string, action: string},
 *   shellDisabled: boolean,
 * }}
 */
export function connectionView(state, data = {}) {
  const view = {
    banner: { visible: false, variant: null, text: "" },
    overlay: { visible: false, info: "", countdown: "", action: "" },
    shellDisabled: DISABLING_STATES.includes(state),
  };

  switch (state) {
    case "disconnected":
      view.banner = {
        visible: true,
        variant: "disconnected",
        text: t("⚠️ Disconnected — Reconnecting..."),
      };
      break;

    case "reconnected":
      view.banner = { visible: true, variant: "reconnected", text: t("✓ Reconnected!") };
      break;

    case "reconnecting":
      view.overlay = {
        visible: true,
        info: jt`Reconnection attempt ${data.attempt} of ${data.maxAttempts}`,
        countdown: jt`Reconnecting in ${data.remaining}s...`,
        action: t("Cancel"),
      };
      break;

    case "cancelled":
      view.overlay = {
        visible: true,
        info: "",
        countdown: t("Reconnection cancelled. Refresh to try again."),
        action: t("Refresh"),
      };
      break;

    // connected, connecting, failed — nothing visible
  }

  return view;
}

import MenuBarHook from "./ui/menu_bar_hook";
import WindowManagerHook from "./ui/window_manager_hook";
import ClockHook from "./connection/clock_hook";
import FocusChatInputOnClickHook from "./ui/focus_chat_input_on_click_hook";
import HelpNavHook from "./help/help_nav_hook";

// Keep the help bundle lean: import only the hooks the help desktop needs
// (window manager + menu bar + clock + toolbar history), not the full app.js.
// FocusChatInputOnClickHook rides along with the About dialog, which every
// shell renders — leaving it out logged an unknown hook on every page load.
export const helpHooks = {
  MenuBarHook: MenuBarHook,
  WindowManagerHook: WindowManagerHook,
  ClockHook: ClockHook,
  FocusChatInputOnClickHook: FocusChatInputOnClickHook,
  HelpNavHook: HelpNavHook,
};

export function buildHelpHooks() {
  return helpHooks;
}

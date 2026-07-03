import MenuBarHook from "./ui/menu_bar_hook";
import WindowManagerHook from "./ui/window_manager_hook";
import ClockHook from "./connection/clock_hook";
import HelpNavHook from "./help/help_nav_hook";

// Keep the help bundle lean: import only the hooks the help desktop needs
// (window manager + menu bar + clock + toolbar history), not the full app.js.
export const helpHooks = {
  MenuBarHook: MenuBarHook,
  WindowManagerHook: WindowManagerHook,
  ClockHook: ClockHook,
  HelpNavHook: HelpNavHook,
};

export function buildHelpHooks() {
  return helpHooks;
}

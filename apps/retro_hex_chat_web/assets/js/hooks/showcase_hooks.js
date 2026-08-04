import MenuBarHook from "./ui/menu_bar_hook";
import WindowManagerHook from "./ui/window_manager_hook";
import FocusChatInputOnClickHook from "./ui/focus_chat_input_on_click_hook";
import ClockHook from "./connection/clock_hook";
import HighlightHook from "./showcase/highlight_hook";

// The desktop demo page renders a real taskbar tray, clock included, so the
// showcase bundle needs ClockHook the same way the app and help bundles do.
export const showcaseHooks = {
  MenuBarHook: MenuBarHook,
  WindowManagerHook: WindowManagerHook,
  FocusChatInputOnClickHook: FocusChatInputOnClickHook,
  ClockHook: ClockHook,
  Highlight: HighlightHook,
};

export function buildShowcaseHooks() {
  return showcaseHooks;
}

import MenuBarHook from "./ui/menu_bar_hook";
import WindowManagerHook from "./ui/window_manager_hook";
import FocusChatInputOnClickHook from "./ui/focus_chat_input_on_click_hook";
import HighlightHook from "./showcase/highlight_hook";

export const showcaseHooks = {
  MenuBarHook: MenuBarHook,
  WindowManagerHook: WindowManagerHook,
  FocusChatInputOnClickHook: FocusChatInputOnClickHook,
  Highlight: HighlightHook,
};

export function buildShowcaseHooks() {
  return showcaseHooks;
}

import MenuBarHook from "./ui/menu_bar_hook";
import HighlightHook from "./showcase/highlight_hook";

export const showcaseHooks = {
  MenuBarHook: MenuBarHook,
  Highlight: HighlightHook,
};

export function buildShowcaseHooks() {
  return showcaseHooks;
}

import CharCounterHook from "./ui/char_counter_hook";
import ClockHook from "./connection/clock_hook";
import ConnectFormHook from "./connection/connect_form_hook";
import ConnectionStatusHook from "./connection/connection_status_hook";
import ContextMenuHook from "./ui/context_menu_hook";
import AutocompleteHook from "./chat/autocomplete_hook";
import EmojiPickerHook from "./chat/emoji_picker_hook";
import FormatToolbarHook from "./chat/format_toolbar_hook";
import KeyboardHook from "./input/keyboard_hook";
import LagHook from "./connection/lag_hook";
import NotifyListHook from "./notifications/notify_list_hook";
import PasteHook from "./chat/paste_hook";
import ChatViewportHook from "./chat/chat_viewport_hook";
import ChatPaginationHook from "./chat/chat_pagination_hook";
import SearchHighlightHook from "./chat/search_highlight_hook";
import ShortcutDispatcherHook from "./input/shortcut_dispatcher_hook";
import SoundHook from "./input/sound_hook";
import DocumentTitleHook from "./notifications/document_title_hook";
import MenuBarHook from "./ui/menu_bar_hook";
import MenuRepositionHook from "./ui/menu_reposition_hook";
import InfiniteScrollHook from "./ui/infinite_scroll_hook";
import PreserveScrollHook from "./ui/preserve_scroll_hook";
import ToolbarGroupHook from "./ui/toolbar_group_hook";
import ConversationsHook from "./ui/conversations_hook";
import NicklistHook from "./ui/nicklist_hook";
import ContextualTipsHook from "./ui/contextual_tips_hook";
import NickChangeFormHook from "./chat/nick_change_form_hook";
import URLCatcherHook from "./ui/url_catcher_hook";
import ViewportDetectHook from "./ui/viewport_detect_hook";
import WindowManagerHook from "./ui/window_manager_hook";
import FocusChatInputOnClickHook from "./ui/focus_chat_input_on_click_hook";
import AutoFocusHook from "./ui/auto_focus_hook";

export const criticalHooks = {
  AutoFocusHook: AutoFocusHook,
  CharCounterHook: CharCounterHook,
  ClockHook: ClockHook,
  ConnectFormHook: ConnectFormHook,
  ConnectionStatusHook: ConnectionStatusHook,
  ContextMenuHook: ContextMenuHook,
  ContextualTipsHook: ContextualTipsHook,
  AutocompleteHook: AutocompleteHook,
  EmojiPickerHook: EmojiPickerHook,
  FocusChatInputOnClickHook: FocusChatInputOnClickHook,
  FormatToolbarHook: FormatToolbarHook,
  KeyboardHook: KeyboardHook,
  LagHook: LagHook,
  NickChangeFormHook: NickChangeFormHook,
  NotifyListHook: NotifyListHook,
  PasteHook: PasteHook,
  ChatViewportHook: ChatViewportHook,
  ChatPaginationHook: ChatPaginationHook,
  SearchHighlightHook: SearchHighlightHook,
  ShortcutDispatcherHook: ShortcutDispatcherHook,
  SoundHook: SoundHook,
  DocumentTitleHook: DocumentTitleHook,
  MenuBarHook: MenuBarHook,
  MenuRepositionHook: MenuRepositionHook,
  InfiniteScrollHook: InfiniteScrollHook,
  PreserveScrollHook: PreserveScrollHook,
  ToolbarGroupHook: ToolbarGroupHook,
  ConversationsHook: ConversationsHook,
  NicklistHook: NicklistHook,
  URLCatcherHook: URLCatcherHook,
  ViewportDetectHook: ViewportDetectHook,
  WindowManagerHook: WindowManagerHook,
};

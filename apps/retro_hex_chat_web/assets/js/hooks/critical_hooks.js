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
import ScrollHook from "./chat/scroll_hook";
import SearchHighlightHook from "./chat/search_highlight_hook";
import ShortcutDispatcherHook from "./input/shortcut_dispatcher_hook";
import SoundHook from "./input/sound_hook";
import TitleFlashHook from "./notifications/title_flash_hook";
import MenuBarHook from "./ui/menu_bar_hook";
import ToolbarGroupHook from "./ui/toolbar_group_hook";
import ConversationsHook from "./ui/conversations_hook";
import NicklistHook from "./ui/nicklist_hook";
import ContextualTipsHook from "./ui/contextual_tips_hook";
import MessageInteractionsHook from "./chat/message_interactions_hook";
import NickChangeFormHook from "./chat/nick_change_form_hook";
import P2PCapabilityHook from "./p2p/p2p_capability_hook";
import P2PChatFormHook from "./p2p/p2p_chat_form_hook";
import P2PSessionHook from "./p2p/p2p_session_hook";
import URLCatcherHook from "./ui/url_catcher_hook";
import ArcadeIframeHook, { ArcadeSessionHook } from "./games/arcade_iframe_hook";
import ArcadeGameHook from "./games/arcade_game_hook";
import ArcadeTimerHook from "./games/arcade_timer_hook";
import GameSessionHook from "./games/game_session_hook";
import ViewportDetectHook from "./ui/viewport_detect_hook";
import WindowManagerHook from "./ui/window_manager_hook";

const AutoFocusHook = {
  mounted() {
    requestAnimationFrame(() => this.el.focus());
  },
};

const FocusChatInputOnClickHook = {
  mounted() {
    this._onClick = () => {
      setTimeout(() => document.getElementById("chat-input")?.focus(), 150);
    };
    this.el.addEventListener("click", this._onClick);
  },

  destroyed() {
    this.el.removeEventListener("click", this._onClick);
  },
};

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
  ArcadeIframe: ArcadeIframeHook,
  ArcadeSession: ArcadeSessionHook,
  ArcadeGame: ArcadeGameHook,
  ArcadeTimer: ArcadeTimerHook,
  GameSessionHook: GameSessionHook,
  FormatToolbarHook: FormatToolbarHook,
  KeyboardHook: KeyboardHook,
  LagHook: LagHook,
  MessageInteractionsHook: MessageInteractionsHook,
  NickChangeFormHook: NickChangeFormHook,
  P2PCapabilityHook: P2PCapabilityHook,
  P2PChatFormHook: P2PChatFormHook,
  P2PSessionHook: P2PSessionHook,
  NotifyListHook: NotifyListHook,
  PasteHook: PasteHook,
  ScrollHook: ScrollHook,
  SearchHighlightHook: SearchHighlightHook,
  ShortcutDispatcherHook: ShortcutDispatcherHook,
  SoundHook: SoundHook,
  TitleFlashHook: TitleFlashHook,
  MenuBarHook: MenuBarHook,
  ToolbarGroupHook: ToolbarGroupHook,
  ConversationsHook: ConversationsHook,
  NicklistHook: NicklistHook,
  URLCatcherHook: URLCatcherHook,
  ViewportDetectHook: ViewportDetectHook,
  WindowManagerHook: WindowManagerHook,
};

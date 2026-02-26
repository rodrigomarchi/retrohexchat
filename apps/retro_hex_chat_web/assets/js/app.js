// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";
import CharCounterHook from "./hooks/ui/char_counter_hook";
import ClockHook from "./hooks/connection/clock_hook";
import ConnectFormHook from "./hooks/connection/connect_form_hook";
import ConnectionBannerHook from "./hooks/notifications/connection_banner_hook";
import ContextMenuHook from "./hooks/ui/context_menu_hook";
import AutocompleteHook from "./hooks/chat/autocomplete_hook";
import EmojiPickerHook from "./hooks/chat/emoji_picker_hook";
import FormatToolbarHook from "./hooks/chat/format_toolbar_hook";
import KeyboardHook from "./hooks/input/keyboard_hook";
import LagHook from "./hooks/connection/lag_hook";
import NotifyListHook from "./hooks/notifications/notify_list_hook";
import PasteHook from "./hooks/chat/paste_hook";
import ReconnectHook from "./hooks/connection/reconnect_hook";
import ScrollHook from "./hooks/chat/scroll_hook";
import SearchHighlightHook from "./hooks/chat/search_highlight_hook";
import ShortcutDispatcherHook from "./hooks/input/shortcut_dispatcher_hook";
import SoundHook from "./hooks/input/sound_hook";
import TitleFlashHook from "./hooks/notifications/title_flash_hook";
import ToolbarGroupHook from "./hooks/ui/toolbar_group_hook";
import ConversationsHook from "./hooks/ui/conversations_hook";
import ContextualTipsHook from "./hooks/ui/contextual_tips_hook";
import NotificationDispatcherHook from "./hooks/notifications/notification_dispatcher_hook";
import MessageInteractionsHook from "./hooks/chat/message_interactions_hook";
import NickChangeFormHook from "./hooks/chat/nick_change_form_hook";
import P2PCapabilityHook from "./hooks/p2p/p2p_capability_hook";
import P2PDiagramHook from "./hooks/p2p/p2p_diagram_hook";
import P2PSessionHook from "./hooks/p2p/p2p_session_hook";
import URLCatcherHook from "./hooks/ui/url_catcher_hook";
import FileTransferHook from "./hooks/p2p/file_transfer_hook";
import ArcadeIframeHook, { ArcadeSessionHook } from "./hooks/games/arcade_iframe_hook";
import GameCanvasHook from "./hooks/games/game_canvas_hook";
import GameSessionHook from "./hooks/games/game_session_hook";
import GameWebRTCHook from "./hooks/games/game_webrtc_hook";
import WebRTCHook from "./hooks/p2p/webrtc_hook";
import MediaHook from "./hooks/p2p/media_hook";
import { getClientInfo } from "./lib/connection/client_info";

const AutoFocusHook = {
  mounted() {
    requestAnimationFrame(() => this.el.focus());
  },
};

const Hooks = {
  AutoFocusHook: AutoFocusHook,
  CharCounterHook: CharCounterHook,
  ClockHook: ClockHook,
  ConnectFormHook: ConnectFormHook,
  ConnectionBannerHook: ConnectionBannerHook,
  ContextMenuHook: ContextMenuHook,
  ContextualTipsHook: ContextualTipsHook,
  AutocompleteHook: AutocompleteHook,
  EmojiPickerHook: EmojiPickerHook,
  FileTransferHook: FileTransferHook,
  ArcadeIframe: ArcadeIframeHook,
  ArcadeSession: ArcadeSessionHook,
  GameCanvasHook: GameCanvasHook,
  GameSessionHook: GameSessionHook,
  GameWebRTCHook: GameWebRTCHook,
  FormatToolbarHook: FormatToolbarHook,
  KeyboardHook: KeyboardHook,
  LagHook: LagHook,
  MediaHook: MediaHook,
  MessageInteractionsHook: MessageInteractionsHook,
  NickChangeFormHook: NickChangeFormHook,
  P2PCapabilityHook: P2PCapabilityHook,
  P2PDiagramHook: P2PDiagramHook,
  P2PSessionHook: P2PSessionHook,
  NotificationDispatcherHook: NotificationDispatcherHook,
  NotifyListHook: NotifyListHook,
  PasteHook: PasteHook,
  ReconnectHook: ReconnectHook,
  ScrollHook: ScrollHook,
  SearchHighlightHook: SearchHighlightHook,
  ShortcutDispatcherHook: ShortcutDispatcherHook,
  SoundHook: SoundHook,
  TitleFlashHook: TitleFlashHook,
  ToolbarGroupHook: ToolbarGroupHook,
  ConversationsHook: ConversationsHook,
  URLCatcherHook: URLCatcherHook,
  WebRTCHook: WebRTCHook,
};

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: () => ({
    _csrf_token: document.querySelector("meta[name='csrf-token']").getAttribute("content"),
    timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || "Etc/UTC",
    client_info: JSON.stringify(getClientInfo()),
  }),
  hooks: Hooks,
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({ detail: reloader }) => {
    reloader.enableServerLogs();

    let keyDown;
    window.addEventListener("keydown", (e) => (keyDown = e.key));
    window.addEventListener("keyup", (_e) => (keyDown = null));
    window.addEventListener(
      "click",
      (e) => {
        if (keyDown === "c") {
          e.preventDefault();
          e.stopImmediatePropagation();
          reloader.openEditorAtCaller(e.target);
        } else if (keyDown === "d") {
          e.preventDefault();
          e.stopImmediatePropagation();
          reloader.openEditorAtDef(e.target);
        }
      },
      true,
    );

    window.liveReloader = reloader;
  });
}

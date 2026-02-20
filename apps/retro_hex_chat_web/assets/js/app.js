// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";
import ChannelListFormHook from "./hooks/channel_list_form_hook";
import CharCounterHook from "./hooks/char_counter_hook";
import ClockHook from "./hooks/clock_hook";
import ConnectFormHook from "./hooks/connect_form_hook";
import ConnectionBannerHook from "./hooks/connection_banner_hook";
import ContextMenuHook from "./hooks/context_menu_hook";
import AutocompleteHook from "./hooks/autocomplete_hook";
import EmojiPickerHook from "./hooks/emoji_picker_hook";
import FormatToolbarHook from "./hooks/format_toolbar_hook";
import KeyboardHook from "./hooks/keyboard_hook";
import LagHook from "./hooks/lag_hook";
import NicklistHook from "./hooks/nicklist_hook";
import NotifyListHook from "./hooks/notify_list_hook";
import PasteHook from "./hooks/paste_hook";
import ReconnectHook from "./hooks/reconnect_hook";
import ScrollHook from "./hooks/scroll_hook";
import SearchHighlightHook from "./hooks/search_highlight_hook";
import ShortcutDispatcherHook from "./hooks/shortcut_dispatcher_hook";
import SoundHook from "./hooks/sound_hook";
import TitleFlashHook from "./hooks/title_flash_hook";
import TreebarHook from "./hooks/treebar_hook";
import ContextualTipsHook from "./hooks/contextual_tips_hook";
import NotificationDispatcherHook from "./hooks/notification_dispatcher_hook";
import MessageInteractionsHook from "./hooks/message_interactions_hook";
import NickChangeFormHook from "./hooks/nick_change_form_hook";
import P2PCapabilityHook from "./hooks/p2p_capability_hook";
import P2PSessionHook from "./hooks/p2p_session_hook";
import URLCatcherHook from "./hooks/url_catcher_hook";
import FileTransferHook from "./hooks/file_transfer_hook";
import WebRTCHook from "./hooks/webrtc_hook";
import MediaHook from "./hooks/media_hook";

const AutoFocusHook = {
  mounted() {
    requestAnimationFrame(() => this.el.focus());
  },
};

const Hooks = {
  AutoFocusHook: AutoFocusHook,
  ChannelListFormHook: ChannelListFormHook,
  CharCounterHook: CharCounterHook,
  ClockHook: ClockHook,
  ConnectFormHook: ConnectFormHook,
  ConnectionBannerHook: ConnectionBannerHook,
  ContextMenuHook: ContextMenuHook,
  ContextualTipsHook: ContextualTipsHook,
  AutocompleteHook: AutocompleteHook,
  EmojiPickerHook: EmojiPickerHook,
  FileTransferHook: FileTransferHook,
  FormatToolbarHook: FormatToolbarHook,
  KeyboardHook: KeyboardHook,
  LagHook: LagHook,
  MediaHook: MediaHook,
  MessageInteractionsHook: MessageInteractionsHook,
  NickChangeFormHook: NickChangeFormHook,
  NicklistHook: NicklistHook,
  P2PCapabilityHook: P2PCapabilityHook,
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
  TreebarHook: TreebarHook,
  URLCatcherHook: URLCatcherHook,
  WebRTCHook: WebRTCHook,
};

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
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

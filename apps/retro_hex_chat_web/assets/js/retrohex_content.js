// Showcase LiveView — its own LiveSocket for the /showcase route, with the
// showcase's hooks only, so it stays apart from app.js and its registry. The
// handshake time and the Win98 chrome are the app's; the locale catalog is
// not loaded, because the showcase is written in English on purpose.

import "phoenix_html";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import { buildShowcaseHooks } from "./hooks/showcase_hooks";
import { LONG_POLL_FALLBACK_MS } from "./lib/system/socket_timing";
import { keepDisclosureStateAcrossPatch } from "./lib/ui/disclosure_state";
import { installRetroChrome } from "./lib/ui/retro_chrome";

const Hooks = buildShowcaseHooks();

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: LONG_POLL_FALLBACK_MS,
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
  dom: { onBeforeElUpdated: keepDisclosureStateAcrossPatch },
});

liveSocket.connect();
window.liveSocket = liveSocket;
// Win98 tooltips over every `title`, the arrows of every up-down field, and
// how popovers close and place themselves — the same as the app's pages.
installRetroChrome(document);

// Help documentation LiveView bundle.
// It intentionally excludes showcase-only syntax highlighting.

import "phoenix_html";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import { buildHelpHooks } from "./hooks/help_hooks";
import { createPlausibleTracker } from "./lib/analytics/plausible";
import { installPopoverBehaviour, keepDisclosureStateAcrossPatch } from "./lib/ui/popover";
import { installRetroTooltips } from "./lib/ui/tooltip";

const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content") || "";
const Hooks = buildHelpHooks();

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
  dom: { onBeforeElUpdated: keepDisclosureStateAcrossPatch },
});

liveSocket.connect();
window.liveSocket = liveSocket;
installPopoverBehaviour(document);

installRetroTooltips(document);

const plausibleEnv = document.querySelector('meta[name="plausible-env"]')?.content || "prod";
const plausible = createPlausibleTracker({
  domain: "retrohexchat.app",
  defaultProps: { env: plausibleEnv },
});
plausible.attachAutoTracking();
window.plausible = plausible;

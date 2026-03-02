// Showcase LiveView — minimal LiveSocket for /showcase route.
// This is isolated from the main app.js and its hooks.

import "phoenix_html";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import hljs from "highlight.js/lib/core";
import elixir from "highlight.js/lib/languages/elixir";
import xml from "highlight.js/lib/languages/xml";

hljs.registerLanguage("elixir", elixir);
hljs.registerLanguage("xml", xml);
hljs.registerLanguage("heex", (hljs) => {
  const elixirLang = elixir(hljs);
  const xmlLang = xml(hljs);
  return {
    name: "HEEx",
    subLanguage: ["xml", "elixir"],
    contains: [...xmlLang.contains, ...elixirLang.contains],
  };
});

import MenuBarHook from "./hooks/ui/menu_bar_hook";

// Hook to highlight code blocks after LiveView mounts/updates.
const Hooks = {
  MenuBarHook: MenuBarHook,
  Highlight: {
    mounted() {
      this.highlightAll();
    },
    updated() {
      this.highlightAll();
    },
    highlightAll() {
      this.el.querySelectorAll("pre code").forEach((block) => {
        // Reset highlight state so hljs re-processes on navigation
        delete block.dataset.highlighted;
        hljs.highlightElement(block);
      });
    },
  },
};

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
});

liveSocket.connect();
window.liveSocket = liveSocket;

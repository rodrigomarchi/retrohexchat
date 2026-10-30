// The surfaces' entrypoint — a call, a game, a space in a tab of its own: the
// application's LiveSocket, connected at once. The desktop has its own entry
// (`desktop.js`) and imports the same socket from `lib/system/live_boot.js`.

import { registerServiceWorker } from "./lib/system/service_worker.js";
import { bootLiveSocket } from "./lib/system/live_boot";

await bootLiveSocket();

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

// Registered from the app bundle and not from the public pages: every reader
// and every crawler downloads those, and the worker is only of use to somebody
// who signed in. A failure here never changes what is on screen.
registerServiceWorker();

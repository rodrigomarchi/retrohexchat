/**
 * LiveSocket for the connect window on the public pages.
 *
 * This module is never part of the public bundle's critical path: it is pulled
 * in by a dynamic import the first time a reader touches the connect window, so
 * a visitor who only reads — or a crawler — pays nothing for it. The landing
 * page is already a dead-rendered LiveView (`data-phx-main` is in the HTML), so
 * connecting here hydrates the markup that is on screen rather than replacing
 * it.
 *
 * The fast paths — auto-login and one-click trusted terminal — never reach this
 * module. They POST the hidden session form directly, because the server
 * authorises them from the trusted-device cookie alone.
 */
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import { buildConnectHooks } from "./hooks/connect_hooks";

let liveSocket = null;

export function bootConnectLiveSocket() {
  if (liveSocket) return liveSocket;

  const csrfToken =
    document.querySelector("meta[name='csrf-token']")?.getAttribute("content") || "";

  liveSocket = new LiveSocket("/live", Socket, {
    longPollFallbackMs: 2500,
    params: { _csrf_token: csrfToken },
    hooks: buildConnectHooks(),
  });

  liveSocket.connect();
  window.liveSocket = liveSocket;

  return liveSocket;
}

/**
 * Resolves once the LiveView has actually joined, not merely once connect() was
 * called — connect() returns immediately and the socket opens later. Anything
 * that hands work to LiveView (replaying a held submit) has to wait for this,
 * or it runs against a page LiveView is not yet driving.
 *
 * `phx-connected` on the main view is the observable signal for that join.
 */
export function whenLiveViewJoined({ timeoutMs = 10000 } = {}) {
  const joined = () =>
    document.querySelector("[data-phx-main]")?.classList.contains("phx-connected") === true;

  return new Promise((resolve, reject) => {
    if (joined()) return resolve();

    const deadline = performance.now() + timeoutMs;
    const poll = () => {
      if (joined()) return resolve();
      if (performance.now() > deadline) {
        return reject(new Error("LiveView did not join before the timeout"));
      }
      requestAnimationFrame(poll);
    };

    requestAnimationFrame(poll);
  });
}

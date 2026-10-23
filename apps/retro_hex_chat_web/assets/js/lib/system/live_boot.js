/**
 * The application's LiveSocket: every hook, the uploaders, the progress bar,
 * the locale catalog and the chrome that needs the app.
 *
 * Shared by the two ways a page starts. The surfaces (`app.js`) boot it at
 * once; the desktop (`desktop.js`) imports this module when the page has a
 * reason to — so a reader of a page of the site, or a crawler, gets the page
 * from the first bundle alone and the chat when they reach for it.
 */
import "phoenix_html";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../../../vendor/topbar";
import {
  buildHooks,
  preserveScrollBeforeElUpdated,
  preserveScrollPatchEnd,
  preserveScrollPatchStart,
} from "../../hooks/registry";
import { getClientInfo } from "../connection/client_info";
import { loadCurrentLocaleCatalog } from "../i18n";
import { S3DirectUploader } from "../uploads/s3_direct";
import { loadRetroChrome } from "../ui/retro_chrome_loader";
import { keepDisclosureStateAcrossPatch } from "../ui/disclosure_state";
import { LONG_POLL_FALLBACK_MS } from "./socket_timing";

let liveSocket = null;

/** Connect the LiveSocket once; later calls return the same one. */
export async function bootLiveSocket() {
  if (liveSocket) return liveSocket;

  liveSocket = new LiveSocket("/live", Socket, {
    longPollFallbackMs: LONG_POLL_FALLBACK_MS,
    params: () => ({
      _csrf_token: document.querySelector("meta[name='csrf-token']").getAttribute("content"),
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || "Etc/UTC",
      client_info: JSON.stringify(getClientInfo()),
      // The socket's own URL is /live/websocket: the address the reader is on
      // is what names the locale (`Live.PutLocale` `:path`).
      page_path: window.location.pathname,
    }),
    hooks: buildHooks(),
    uploaders: {
      S3Direct: S3DirectUploader,
    },
    dom: {
      onPatchStart: preserveScrollPatchStart,
      onBeforeElUpdated(fromEl, toEl) {
        preserveScrollBeforeElUpdated(fromEl, toEl);
        keepDisclosureStateAcrossPatch(fromEl, toEl);
      },
      onPatchEnd: preserveScrollPatchEnd,
    },
  });

  // Show progress bar on live navigation and form submits
  topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
  window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
  window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

  await loadCurrentLocaleCatalog();

  liveSocket.connect();

  // Win98 tooltips over every `title`, the arrows of every up-down field, and how
  // popovers close and place themselves.
  loadRetroChrome(document);

  // expose liveSocket on window for web console debug logs and latency simulation:
  // >> liveSocket.enableDebug()
  // >> liveSocket.enableLatencySim(1000)
  window.liveSocket = liveSocket;

  return liveSocket;
}

/**
 * Resolves once the LiveView has actually joined, not merely once connect() was
 * called — connect() returns immediately and the socket opens later. Anything
 * that hands work to LiveView (replaying a held submit) has to wait for this,
 * or it runs against a page LiveView is not yet driving.
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

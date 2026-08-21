// Grafana Faro RUM entrypoint, loaded as its own <script type="module"> by every
// layout that opts into real-user monitoring (chat, landing, help).
//
// Deliberately tiny. The SDK it eventually loads is 262 KB — bigger than the app
// bundle — so nothing here imports it statically: the gate answers from the
// faro-* metas and the hostname first, and only a page that will actually send
// telemetry, once it has gone idle, pays for the download.
import { scheduleRum } from "./lib/telemetry/faro_gate";

scheduleRum({
  win: window,
  doc: document,
  load: () => import("./lib/telemetry/faro_sdk").then((module) => module.bootFaro()),
});

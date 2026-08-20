// Standalone Grafana Faro RUM entrypoint, loaded as its own <script type="module">
// by every layout that opts into real-user monitoring (chat, landing, help). It
// is self-contained (bundles the Faro SDK) and self-gating: a no-op unless the
// faro-enabled meta is "true" and the page is off localhost. Keeping RUM in its
// own module decouples it from each page's bundle and its size budget.
import { getWebInstrumentations, initializeFaro } from "@grafana/faro-web-sdk";
import { TracingInstrumentation } from "@grafana/faro-web-tracing";

import { createFaro } from "./lib/telemetry/faro";

createFaro({
  initializeFaro,
  buildInstrumentations: () => [
    ...getWebInstrumentations({ captureConsole: true }),
    new TracingInstrumentation(),
  ],
  win: window,
  doc: document,
}).boot();

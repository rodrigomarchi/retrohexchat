// Standalone Grafana Faro RUM entrypoint, loaded as its own <script type="module">
// by every layout that opts into real-user monitoring (chat, landing, help). It
// is self-contained (bundles the Faro SDK) and self-gating: a no-op unless the
// faro-enabled meta is "true" and the page is off localhost. Keeping RUM in its
// own module decouples it from each page's bundle and its size budget.
import { getWebInstrumentations, initializeFaro } from "@grafana/faro-web-sdk";
import { getDefaultOTELInstrumentations, TracingInstrumentation } from "@grafana/faro-web-tracing";
import { DocumentLoadInstrumentation } from "@opentelemetry/instrumentation-document-load";

import { createFaro } from "./lib/telemetry/faro";

createFaro({
  initializeFaro,
  buildInstrumentations: () => [
    ...getWebInstrumentations({ captureConsole: true }),
    // Faro's tracing only auto-instruments fetch/XHR by default, so a static
    // landing page or the websocket-driven chat produced almost no spans. Adding
    // document-load emits a trace on every page view (load timing + resource
    // spans), which is the frontend RUM signal that reaches Tempo.
    new TracingInstrumentation({
      instrumentations: [...getDefaultOTELInstrumentations(), new DocumentLoadInstrumentation()],
    }),
  ],
  win: window,
  doc: document,
}).boot();

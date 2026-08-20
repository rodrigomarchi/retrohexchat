// Standalone Grafana Faro RUM entrypoint, loaded as its own <script type="module">
// by every layout that opts into real-user monitoring (chat, landing, help). It
// is self-contained (bundles the Faro SDK) and self-gating: a no-op unless the
// faro-enabled meta is "true" and the page is off localhost. Keeping RUM in its
// own module decouples it from each page's bundle and its size budget.
import { getWebInstrumentations, initializeFaro } from "@grafana/faro-web-sdk";
import { getDefaultOTELInstrumentations, TracingInstrumentation } from "@grafana/faro-web-tracing";
import { DocumentLoadInstrumentation } from "@opentelemetry/instrumentation-document-load";

import { createFaro, viewNameForPath } from "./lib/telemetry/faro";

// Don't trace the telemetry beacon itself (or the Plausible one) — that would
// create a span for every span export and bloat Tempo with self-referential noise.
const IGNORED_TRACE_URLS = [/\/faro\/collect/, /\/api\/event/];

const faro = createFaro({
  initializeFaro,
  buildInstrumentations: () => [
    ...getWebInstrumentations({ captureConsole: true }),
    // Faro's tracing only auto-instruments fetch/XHR by default, so a static
    // landing page or the websocket-driven chat produced almost no spans. Adding
    // document-load emits a trace on every page view (load timing + resource
    // spans), which is the frontend RUM signal that reaches Tempo.
    new TracingInstrumentation({
      instrumentations: [
        ...getDefaultOTELInstrumentations({ ignoreUrls: IGNORED_TRACE_URLS }),
        new DocumentLoadInstrumentation(),
      ],
    }),
  ],
  win: window,
  doc: document,
}).boot();

// Group RUM by logical route rather than by raw URL. The initial view is set on
// load; LiveView patch/redirect navigations update it when the path changes.
if (faro?.api?.setView) {
  let lastView = viewNameForPath(window.location.pathname);
  faro.api.setView({ name: lastView });

  window.addEventListener("phx:page-loading-stop", (event) => {
    const kind = event?.detail?.kind;
    if (kind !== "patch" && kind !== "redirect") return;
    const view = viewNameForPath(window.location.pathname);
    if (view === lastView) return;
    lastView = view;
    faro.api.setView({ name: view });
  });
}

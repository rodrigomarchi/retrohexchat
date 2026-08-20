/**
 * @file Wires the real Grafana Faro SDK into the injectable bootstrap.
 *
 * This is the only module that imports the Faro SDK, so app.js loads it with a
 * dynamic import() and esbuild keeps the SDK in its own async chunk (see the
 * `app-faro_boot-*` entry in scripts/bundle_budget.cjs). The gating logic lives
 * in faro.js, which is unit-tested without the SDK.
 */
import { getWebInstrumentations, initializeFaro } from "@grafana/faro-web-sdk";
import { TracingInstrumentation } from "@grafana/faro-web-tracing";

import { createFaro } from "./faro";

/**
 * Boot Faro RUM against the live document/window and SDK.
 *
 * @returns {unknown | null} The Faro instance, or null when it did not start.
 */
export function bootFaro() {
  return createFaro({
    initializeFaro,
    buildInstrumentations: () => [
      ...getWebInstrumentations({ captureConsole: true }),
      new TracingInstrumentation(),
    ],
    win: window,
    doc: document,
  }).boot();
}

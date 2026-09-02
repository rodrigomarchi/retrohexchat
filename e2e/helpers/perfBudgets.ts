/**
 * What a surface is allowed to weigh in a real browser.
 *
 * A budget catches a regression; it does not describe today. Each number is the
 * target plus roughly 10% headroom — the same contract
 * `assets/scripts/bundle_budget.cjs` holds the JS bundles to, and the mirror of
 * `test/support/perf_budgets.ex` on the Elixir side.
 *
 * Baselines measured against production on 2026-08-20, from the load test whose
 * RUM showed LCP p50 of 2664 ms on /chat with 82% of it spent rendering rather
 * than waiting on the server:
 *
 *   surface     document (raw)   DOM nodes
 *   /connect         191_772 B       1_804
 *   /chat            568_352 B           —
 *   help             611_705 B       6_049
 */
export const PERF_BUDGETS = {
  connect: { navBytes: 115_000, domNodes: 1_060 },
  // The help index draws a row per topic, so the node count moves when topics
  // are added — and adding one is mandatory for anything with a control
  // surface. 2_900 was the count when the number was set; the session-card and
  // space-card topics took it to 2_917. Raised deliberately, with the room a
  // few more topics need. A jump this gate should catch is a page that grew
  // without anyone deciding to grow it, not nine nodes per documented feature.
  help: { navBytes: 300_000, domNodes: 3_100 },
  // /chat only exists after a connected mount, so its node count is measured
  // once the desktop has rendered rather than off the dead render.
  chat: { domNodes: 4_200 },
} as const;

/** First paint and largest paint, against a local server on loopback. */
export const VITALS_BUDGETS = {
  fcp: 1_500,
  lcp: 2_500,
} as const;

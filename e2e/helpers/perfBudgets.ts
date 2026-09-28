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
  // The help index draws a row per topic, so both numbers move when topics are
  // added — and adding one is mandatory for anything with a control surface. A
  // jump this gate should catch is a page that grew without anyone deciding to
  // grow it, not a kilobyte per documented feature.
  //
  // Measured 2026-09-28 at 297 topics: 303_678 B raw, 21_619 B on the wire,
  // 3_030 nodes. The wire cost is what it is because the rows are near-identical
  // markup and compress by 93%; the node count is the half no compressor gives
  // back, and the half these numbers really guard. This pair had drifted below
  // its own Elixir mirror (`test/support/perf_budgets.ex`, 310_000) and was the
  // only one of the two failing. Both now say the same thing, with room for
  // roughly twenty-five more topics.
  //
  // What neither number answers: the index draws every one of 297 topics on a
  // page somebody opened to find one. Another raise is the wrong answer to that;
  // the right one is a decision about what the index shows.
  help: { navBytes: 330_000, domNodes: 3_200 },
  // /chat only exists after a connected mount, so its node count is measured
  // once the desktop has rendered rather than off the dead render.
  chat: { domNodes: 4_200 },
} as const;

/** First paint and largest paint, against a local server on loopback. */
export const VITALS_BUDGETS = {
  fcp: 1_500,
  lcp: 2_500,
} as const;

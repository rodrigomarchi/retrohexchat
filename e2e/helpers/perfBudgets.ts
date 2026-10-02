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
  // Measured 2026-10-02 at 297 topics: 243_104 B raw, 3_042 nodes — down from
  // 303_678 B on 2026-09-28 with the page unchanged. What left was repeated
  // `class` attributes, which were a quarter of the document: the rows now carry
  // project classes and the stylesheet says once what the markup was saying 296
  // times. The node count did not move, and could not: naming a class removes
  // bytes, never elements.
  //
  // That is why the node count is the half these numbers really guard. The byte
  // count compresses away — the rows are near-identical markup — while every
  // node costs parse and layout on the main thread no compressor gives back.
  // Keep this pair equal to its Elixir mirror (`test/support/perf_budgets.ex`);
  // they drifted apart once and only one of the two was failing.
  //
  // What neither number answers: the index draws every one of 297 topics on a
  // page somebody opened to find one. Another raise is the wrong answer to that;
  // the right one is a decision about what the index shows.
  //
  // Measured, so the decision can be made with a number: the tree is 175_341 B
  // of the page and the Win98 chrome is the other 151_582 B. Showing only the
  // open section and its siblings would put a topic page near 186_000 B — a
  // third off again, and the node count with it. The cost is a behaviour: the
  // tree is native `<details>` with no JS, so a collapsed section emptied of its
  // children turns the browser's free toggle into a dead click, and would need
  // `phx-click`, an `expanded_categories` assign and two new `HelpTopics`
  // functions (`topics_by_category/0` is pinned by `help_topics_test.exs` as an
  // exact partition, so it cannot be the one that changes). Crawlability is not
  // the blocker — the sitemap carries every topic URL either way.
  help: { navBytes: 265_000, domNodes: 3_200 },
  // /chat only exists after a connected mount, so its node count is measured
  // once the desktop has rendered rather than off the dead render.
  chat: { domNodes: 4_200 },
} as const;

/** First paint and largest paint, against a local server on loopback. */
export const VITALS_BUDGETS = {
  fcp: 1_500,
  lcp: 2_500,
} as const;

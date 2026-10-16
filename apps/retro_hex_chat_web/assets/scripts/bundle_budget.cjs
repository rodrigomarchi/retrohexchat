const { execFileSync } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const zlib = require("node:zlib");

const KIB = 1024;
const ASSETS_ROOT = path.resolve(__dirname, "..");
const REPO_ROOT = path.resolve(ASSETS_ROOT, "../../..");
const OUTDIR = fs.mkdtempSync(path.join(os.tmpdir(), "retro-hex-bundle-budget-"));

// Every entry the browser can load on its own. desktop.js is measured with the
// same splitting flags production builds it with, so its lazy chunks show up as
// chunks here instead of hiding inside the entry.
const ENTRIES = [
  {
    entry: "js/app.js",
    chunkNames: "chunks/app-[name]-[hash]",
    metafile: path.join(OUTDIR, "meta-app.json"),
  },
  {
    entry: "js/desktop.js",
    chunkNames: "chunks/desktop-[name]-[hash]",
    metafile: path.join(OUTDIR, "meta-desktop.json"),
  },
  {
    entry: "js/faro_entry.js",
    chunkNames: "chunks/faro-[name]-[hash]",
    metafile: path.join(OUTDIR, "meta-faro.json"),
  },
];

// A budget catches regressions; it does not describe today's size. Each number
// here is the current size plus roughly 10% headroom, so an ordinary change
// passes and a step-change has to be argued for.
const BUDGETS = {
  // 469.6kb before the one desktop; the window manager every screen shares then
  // gained what the desktop needs on its first paint — the window in front named
  // by the server, the focus reported as an address, a window started minimized
  // without its animation — about 2kb that cannot be lazy, because the manager
  // places the windows before anything else runs.
  entry: 475 * KIB,
  entryGzip: 130 * KIB,
  localeChunk: 20 * KIB,
  featureChunk: 50 * KIB,
  asyncChunk: 85 * KIB,
  // The desktop's critical path. This is the number that matters most on this
  // project: every reader of every page and every crawler downloads it, while
  // the chat's LiveSocket is only paid for once the page has a reason to start
  // it. Keeping it near 10% of app.js is the whole reason the socket is a lazy
  // chunk.
  publicEntry: 90 * KIB,
  publicEntryGzip: 20 * KIB,
  // The RUM entrypoint is a gate, not a bundle: it reads three metas, decides
  // whether this page sends telemetry at all, and only then imports the SDK.
  // It went unmeasured until 2026-08-20, by which time it had grown to 262 KB
  // — larger than app.js — and was downloading on every page view regardless
  // of whether RUM was even enabled. Keep it small enough that it cannot.
  faroEntry: 4 * KIB,
  faroEntryGzip: 2 * KIB,
};

// Chunks that legitimately exceed the generic feature budget. The generic
// budget stays tight on purpose: raising it for everyone would let the next new
// hook ship at 100kb unnoticed. An entry here needs a reason — a number raised
// without one turns the budget into a rubber stamp.
const CHUNK_OVERRIDES = [
  {
    pattern: /^desktop-live_boot-/,
    budget: 475 * KIB,
    reason:
      "the chat's LiveSocket and every critical hook — app.js's body, started by the desktop " +
      "only once the page has a reason to (lib/site/boot_policy.js); same budget as app.js",
  },
  {
    pattern: /^app-space_canvas_hook-/,
    budget: 124 * KIB,
    reason:
      "isometric renderer: tile/sprite pipeline, collision, camera, animation clock, and the " +
      "focus ring and prompt every frame draws over what the use button reaches",
  },
  {
    pattern: /^desktop-space_canvas_hook-/,
    budget: 137 * KIB,
    reason:
      "the same modules as app-space_canvas_hook (121kb there): measured unminified, and in " +
      "the desktop's chunk graph esbuild renames more of their identifiers apart",
  },
  {
    pattern: /^app-group_call_webrtc_hook-/,
    budget: 85 * KIB,
    reason: "SFU client: transport, simulcast, device management, layout engine",
  },
  {
    pattern: /^desktop-group_call_webrtc_hook-/,
    budget: 88 * KIB,
    reason:
      "the same modules as app-group_call_webrtc_hook, with the desktop chunk graph's longer " +
      "renamed identifiers (unminified)",
  },
  {
    pattern: /^faro-faro_sdk-/,
    budget: 780 * KIB,
    reason: "Grafana Faro SDK + OTel tracing: fetched only when RUM is on, and only once idle",
  },
];

const LOCALE_CHUNK_PATTERN =
  /^(app|desktop)-(ar|bn|de|es|fr|hi|id|it|ja|ko|nl|pl|pt_BR|pt_PT|ru|tr|ur|vi|zh_hans|zh_hant)-/;
const FEATURE_CHUNK_PATTERN = /^(app|desktop)-.*hook-/;

function kib(bytes) {
  return `${(bytes / KIB).toFixed(1)}kb`;
}

function outputLine(message) {
  process.stdout.write(`${message}\n`);
}

function errorLine(message) {
  process.stderr.write(`${message}\n`);
}

function budgetFor(filename) {
  if (filename === "app.js") return BUDGETS.entry;
  if (filename === "desktop.js") return BUDGETS.publicEntry;
  if (filename === "faro_entry.js") return BUDGETS.faroEntry;

  const override = CHUNK_OVERRIDES.find((entry) => entry.pattern.test(filename));
  if (override) return override.budget;

  if (LOCALE_CHUNK_PATTERN.test(filename)) return BUDGETS.localeChunk;
  if (FEATURE_CHUNK_PATTERN.test(filename)) return BUDGETS.featureChunk;
  return BUDGETS.asyncChunk;
}

function overrideReasonFor(filename) {
  const override = CHUNK_OVERRIDES.find((entry) => entry.pattern.test(filename));
  return override ? override.reason : null;
}

function runEsbuild({ entry, chunkNames, metafile }) {
  execFileSync(
    path.join(ASSETS_ROOT, "node_modules/.bin/esbuild"),
    [
      entry,
      "--bundle",
      "--target=es2022",
      "--format=esm",
      "--splitting",
      `--chunk-names=${chunkNames}`,
      `--outdir=${OUTDIR}`,
      "--external:/fonts/*",
      "--external:/images/*",
      `--metafile=${metafile}`,
      "--log-level=silent",
    ],
    {
      cwd: ASSETS_ROOT,
      env: {
        ...process.env,
        NODE_PATH: path.join(REPO_ROOT, "deps"),
      },
      stdio: "pipe",
    },
  );
}

function outputRows(meta) {
  return Object.entries(meta.outputs)
    .filter(([, output]) => output.bytes > 0)
    .map(([file, output]) => {
      const filename = path.basename(file);
      const bytes = output.bytes;
      const gzipBytes = zlib.gzipSync(fs.readFileSync(file)).length;
      const budget = budgetFor(filename);

      return {
        file,
        filename,
        bytes,
        gzipBytes,
        budget,
        overBudget: bytes > budget,
      };
    })
    .sort((a, b) => b.bytes - a.bytes);
}

function checkGzipEntry(rows, filename, budget, failures) {
  const entry = rows.find((row) => row.filename === filename);

  if (!entry) {
    failures.push(`${filename} was not emitted by esbuild`);
    return;
  }

  if (entry.gzipBytes > budget) {
    failures.push(
      `${entry.filename} gzip is ${kib(entry.gzipBytes)}, ` +
        `${kib(entry.gzipBytes - budget)} over its ${kib(budget)} budget`,
    );
  }
}

function checkBudget(rows) {
  const failures = [];

  checkGzipEntry(rows, "app.js", BUDGETS.entryGzip, failures);
  checkGzipEntry(rows, "desktop.js", BUDGETS.publicEntryGzip, failures);
  checkGzipEntry(rows, "faro_entry.js", BUDGETS.faroEntryGzip, failures);

  for (const row of rows) {
    if (row.overBudget) {
      const reason = overrideReasonFor(row.filename);
      failures.push(
        `${row.filename} is ${kib(row.bytes)}, ` +
          `${kib(row.bytes - row.budget)} over its ${kib(row.budget)} budget` +
          (reason ? ` (raised budget: ${reason})` : ""),
      );
    }
  }

  return failures;
}

function main() {
  try {
    const rows = [];
    for (const config of ENTRIES) {
      runEsbuild(config);
      rows.push(...outputRows(JSON.parse(fs.readFileSync(config.metafile, "utf8"))));
    }
    rows.sort((a, b) => b.bytes - a.bytes);
    const failures = checkBudget(rows);

    outputLine("Bundle budget report:");
    for (const row of rows.slice(0, 12)) {
      outputLine(`  ${row.filename}: ${kib(row.bytes)} raw, ${kib(row.gzipBytes)} gzip`);
    }

    if (failures.length > 0) {
      errorLine("Bundle budget failed:");
      for (const failure of failures) errorLine(`  - ${failure}`);
      process.exitCode = 1;
    } else {
      outputLine("Bundle budget passed.");
    }
  } finally {
    if (!process.env.KEEP_BUNDLE_BUDGET_OUTPUT) {
      fs.rmSync(OUTDIR, { recursive: true, force: true });
    }
  }
}

main();

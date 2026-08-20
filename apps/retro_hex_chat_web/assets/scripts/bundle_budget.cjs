const { execFileSync } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const zlib = require("node:zlib");

const KIB = 1024;
const ASSETS_ROOT = path.resolve(__dirname, "..");
const REPO_ROOT = path.resolve(ASSETS_ROOT, "../../..");
const OUTDIR = fs.mkdtempSync(path.join(os.tmpdir(), "retro-hex-bundle-budget-"));

// Every entry the browser can load on its own. public_pages.js is measured with
// the same splitting flags production builds it with, so its lazy chunk shows up
// as a chunk here instead of hiding inside the entry.
const ENTRIES = [
  {
    entry: "js/app.js",
    chunkNames: "chunks/app-[name]-[hash]",
    metafile: path.join(OUTDIR, "meta-app.json"),
  },
  {
    entry: "js/public_pages.js",
    chunkNames: "chunks/public-[name]-[hash]",
    metafile: path.join(OUTDIR, "meta-public.json"),
  },
];

// A budget catches regressions; it does not describe today's size. Each number
// here is the current size plus roughly 10% headroom, so an ordinary change
// passes and a step-change has to be argued for.
const BUDGETS = {
  entry: 470 * KIB,
  entryGzip: 130 * KIB,
  localeChunk: 20 * KIB,
  featureChunk: 50 * KIB,
  asyncChunk: 85 * KIB,
  // The public pages' critical path. This is the number that matters most on
  // this project: every reader and every crawler downloads it, while the app
  // bundle is only paid for by people who already signed in. Keeping it near
  // 10% of app.js is the whole reason the connect LiveSocket is a lazy chunk.
  publicEntry: 80 * KIB,
  publicEntryGzip: 18 * KIB,
};

// Chunks that legitimately exceed the generic feature budget. The generic
// budget stays tight on purpose: raising it for everyone would let the next new
// hook ship at 100kb unnoticed. An entry here needs a reason — a number raised
// without one turns the budget into a rubber stamp.
const CHUNK_OVERRIDES = [
  {
    pattern: /^public-connect_boot-/,
    budget: 350 * KIB,
    reason: "connect window LiveSocket: phoenix + phoenix_live_view, loaded only on first touch",
  },
  {
    pattern: /^app-space_canvas_hook-/,
    budget: 120 * KIB,
    reason: "isometric renderer: tile/sprite pipeline, collision, camera, animation clock",
  },
  {
    pattern: /^app-group_call_webrtc_hook-/,
    budget: 85 * KIB,
    reason: "SFU client: transport, simulcast, device management, layout engine",
  },
];

const LOCALE_CHUNK_PATTERN =
  /^app-(ar|bn|de|es|fr|hi|id|it|ja|ko|nl|pl|pt_BR|pt_PT|ru|tr|ur|vi|zh_hans|zh_hant)-/;
const FEATURE_CHUNK_PATTERN = /^app-.*hook-/;

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
  if (filename === "public_pages.js") return BUDGETS.publicEntry;

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
  checkGzipEntry(rows, "public_pages.js", BUDGETS.publicEntryGzip, failures);

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

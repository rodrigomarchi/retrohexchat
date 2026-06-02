const { execFileSync } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const zlib = require("node:zlib");

const KIB = 1024;
const ASSETS_ROOT = path.resolve(__dirname, "..");
const REPO_ROOT = path.resolve(ASSETS_ROOT, "../../..");
const OUTDIR = fs.mkdtempSync(path.join(os.tmpdir(), "retro-hex-bundle-budget-"));
const METAFILE = path.join(OUTDIR, "meta.json");

const BUDGETS = {
  entry: 390 * KIB,
  entryGzip: 130 * KIB,
  localeChunk: 20 * KIB,
  featureChunk: 40 * KIB,
  asyncChunk: 85 * KIB,
};

const LOCALE_CHUNK_PATTERN =
  /^v2-(ar|bn|de|es|fr|hi|id|it|ja|ko|nl|pl|pt_BR|pt_PT|ru|tr|ur|vi|zh_hans|zh_hant)-/;
const FEATURE_CHUNK_PATTERN = /^v2-.*hook-/;

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
  if (filename === "v2_app.js") return BUDGETS.entry;
  if (LOCALE_CHUNK_PATTERN.test(filename)) return BUDGETS.localeChunk;
  if (FEATURE_CHUNK_PATTERN.test(filename)) return BUDGETS.featureChunk;
  return BUDGETS.asyncChunk;
}

function runEsbuild() {
  execFileSync(
    path.join(ASSETS_ROOT, "node_modules/.bin/esbuild"),
    [
      "js/v2_app.js",
      "--bundle",
      "--target=es2022",
      "--format=esm",
      "--splitting",
      "--chunk-names=chunks/v2-[name]-[hash]",
      `--outdir=${OUTDIR}`,
      "--external:/fonts/*",
      "--external:/images/*",
      `--metafile=${METAFILE}`,
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

function checkBudget(rows) {
  const failures = [];
  const entry = rows.find((row) => row.filename === "v2_app.js");

  if (!entry) {
    failures.push("v2_app.js was not emitted by esbuild");
  } else if (entry.gzipBytes > BUDGETS.entryGzip) {
    failures.push(
      `${entry.filename} gzip is ${kib(entry.gzipBytes)} over budget ${kib(BUDGETS.entryGzip)}`,
    );
  }

  for (const row of rows) {
    if (row.overBudget) {
      failures.push(`${row.filename} is ${kib(row.bytes)} over budget ${kib(row.budget)}`);
    }
  }

  return failures;
}

function main() {
  try {
    runEsbuild();

    const meta = JSON.parse(fs.readFileSync(METAFILE, "utf8"));
    const rows = outputRows(meta);
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

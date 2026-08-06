#!/usr/bin/env node
/**
 * Regenerate (or verify) the generated half of e2e/TEST_CATALOG.md from the
 * `@flow` headers in e2e/tests/*.spec.ts.
 *
 *   node scripts/catalog.mjs           # rewrite the generated block
 *   node scripts/catalog.mjs --check   # fail if the block is out of date
 *
 * The specs are the source of truth. A catalog maintained by hand drifts the
 * moment someone adds a test and forgets the table: before this generator
 * existed, 23 spec files had no catalog row at all and the stated spec/test
 * counts were both wrong.
 *
 * Everything outside the BEGIN/END markers is hand-written and preserved.
 */

import { readFileSync, readdirSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const E2E_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const TESTS_DIR = join(E2E_ROOT, "tests");
const CATALOG = join(E2E_ROOT, "TEST_CATALOG.md");

const BEGIN = "<!-- BEGIN GENERATED INDEX -->";
const END = "<!-- END GENERATED INDEX -->";

// Presentation order only. Sections not listed here are appended alphabetically,
// so adding one never breaks the generator — it just lands at the end.
const SECTION_ORDER = [
  "Auth And Lifecycle",
  "Chat Foundation",
  "UI Features Browser Regression",
  "G - Command Surface, Help, Autocomplete, Validation",
  "H - Channels, Server Messages, Local Window State",
  "I - Channel Modes, Privileges, Moderation",
  "J - User Commands, Privacy, Presence",
  "K - NickServ And ChanServ",
  "L - Config, Scripting, Timers, Custom Menus",
  "M - Admin, Server Operations, Bots",
  "N - P2P, File, Call, Game",
  "O - Chat UI Micro-Journeys",
  "P - Persistence, Reconnect, History, No-Focus-Steal",
];

function specFiles() {
  return readdirSync(TESTS_DIR)
    .filter((name) => name.endsWith(".spec.ts"))
    .sort();
}

function parseSpec(name) {
  const body = readFileSync(join(TESTS_DIR, name), "utf8");
  const header = body.match(/^\/\*\*([\s\S]*?)\*\//);
  const testCount = (body.match(/^\s*test\(/gm) || []).length;

  if (!header) return { name, sections: [], flows: [], testCount };

  const lines = header[1].split("\n").map((line) => line.replace(/^\s*\*\s?/, ""));
  const flows = [];
  let section = "Uncategorised";

  for (const line of lines) {
    const heading = line.match(/^@section\s+(.+?)\s*$/);
    if (heading) {
      section = heading[1];
      continue;
    }
    const flow = line.match(/^@flow\s+(\S+)\s+\[(\w+)\]\s+(.+?)\s*$/);
    if (flow) {
      flows.push({ id: flow[1], status: flow[2], text: flow[3], section });
    }
  }
  return { name, flows, testCount };
}

function escapeCell(text) {
  return text.replace(/\|/g, "\\|");
}

/**
 * Order flows the way a reader scans them: A, B, ... H, then L9 before L10,
 * then UI11 before UI11a. Specs are read alphabetically, so without this the
 * index would be sorted by filename and the IDs would look shuffled.
 */
function compareFlowIds(a, b) {
  const parse = (id) => {
    const m = id.match(/^([A-Za-z]*)(\d*)(.*)$/);
    return { alpha: m[1], num: m[2] ? Number(m[2]) : -1, rest: m[3] };
  };
  const left = parse(a);
  const right = parse(b);
  return (
    left.alpha.localeCompare(right.alpha) ||
    left.num - right.num ||
    left.rest.localeCompare(right.rest)
  );
}

function buildIndex(specs) {
  const bySection = new Map();
  const undocumented = [];

  for (const spec of specs) {
    if (!spec.flows.length) {
      undocumented.push(spec);
      continue;
    }
    for (const flow of spec.flows) {
      if (!bySection.has(flow.section)) bySection.set(flow.section, []);
      bySection.get(flow.section).push({ ...flow, spec: spec.name });
    }
  }

  const known = SECTION_ORDER.filter((s) => bySection.has(s));
  const extra = [...bySection.keys()].filter((s) => !SECTION_ORDER.includes(s)).sort();
  const ordered = [...known, ...extra];

  const totalFlows = [...bySection.values()].reduce((sum, rows) => sum + rows.length, 0);
  const totalTests = specs.reduce((sum, s) => sum + s.testCount, 0);
  const blocked = [...bySection.values()]
    .flat()
    .filter((flow) => flow.status !== "done").length;

  const out = [];
  out.push(BEGIN);
  out.push("");
  out.push("## Coverage");
  out.push("");
  out.push(`- **${specs.length} spec files** under \`e2e/tests/\`.`);
  out.push(`- **${totalTests} Playwright \`test()\` cases**.`);
  out.push(`- **${totalFlows} documented flows**, ${totalFlows - blocked} done, ${blocked} not done.`);
  out.push(
    `- **${undocumented.length} spec files carry no \`@flow\` header** ` +
      "(listed at the end — each one is a gap, not a decision).",
  );
  out.push("");
  out.push("## Flow index");
  out.push("");
  out.push("Grouped by section. Every row comes from an `@flow` line in the spec itself.");
  out.push("");

  for (const section of ordered) {
    const rows = bySection.get(section).sort((a, b) => compareFlowIds(a.id, b.id));
    out.push(`### ${section}`);
    out.push("");
    out.push("| # | Flow | Spec file | Status |");
    out.push("| --- | --- | --- | --- |");
    for (const row of rows) {
      out.push(
        `| ${row.id} | ${escapeCell(row.text)} | \`tests/${row.spec}\` | ${row.status} |`,
      );
    }
    out.push("");
  }

  out.push("## Spec files with no documented flows");
  out.push("");
  if (undocumented.length === 0) {
    out.push("None. Every spec documents its own flows.");
  } else {
    out.push(
      "These run in the suite but describe nothing. Add an `@flow` header to each, " +
        "then regenerate:",
    );
    out.push("");
    for (const spec of undocumented) {
      const plural = spec.testCount === 1 ? "case" : "cases";
      out.push(`- \`tests/${spec.name}\` (${spec.testCount} \`test()\` ${plural})`);
    }
  }
  out.push("");
  out.push(END);

  return out.join("\n");
}

function main() {
  const specs = specFiles().map(parseSpec);
  const generated = buildIndex(specs);
  const current = readFileSync(CATALOG, "utf8");

  const start = current.indexOf(BEGIN);
  const finish = current.indexOf(END);
  if (start === -1 || finish === -1) {
    process.stderr.write(
      `TEST_CATALOG.md is missing the ${BEGIN} / ${END} markers; cannot place the index.\n`,
    );
    process.exit(1);
  }

  const next = current.slice(0, start) + generated + current.slice(finish + END.length);

  if (process.argv.includes("--check")) {
    if (next !== current) {
      process.stderr.write(
        "TEST_CATALOG.md is out of date with the @flow headers in e2e/tests/.\n" +
          "Run `make e2e.catalog` and commit the result.\n",
      );
      process.exit(1);
    }
    process.stdout.write("TEST_CATALOG.md is in sync with the spec headers.\n");
    return;
  }

  writeFileSync(CATALOG, next);
  process.stdout.write(`TEST_CATALOG.md regenerated from ${specs.length} spec files.\n`);
}

main();

#!/usr/bin/env node
/**
 * Cuts the suite into feature batches, from the `@section` header each spec
 * already carries.
 *
 *   node scripts/batches.mjs --list        # every batch, its sections and size
 *   node scripts/batches.mjs <batch>       # the spec paths, space separated
 *   node scripts/batches.mjs <batch> --mobile    # its mobile-chrome half, if any
 *   node scripts/batches.mjs --check       # every spec lands in exactly one batch
 *   node scripts/batches.mjs --names       # batch names, in running order
 *
 * The whole suite in one command takes ~36 minutes on one worker, which is long
 * enough that a red run tells you nothing you can act on: the failure is a
 * filename in a wall of output, and the next attempt costs another 36 minutes.
 * A batch names a feature, finishes in minutes, and is re-runnable while the
 * cause is still in your head.
 *
 * Sections, not `--shard`: a shard is a number, and a number cannot tell you
 * that channel modes are broken. Deriving from the headers also means a spec
 * added tomorrow is picked up without editing a list here — and `--check`
 * fails loudly if its section is one nobody assigned, rather than letting it
 * quietly belong to no batch at all.
 */

import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { parseSpec, specFiles } from "./catalog.mjs";

/**
 * Running order, and it carries weight.
 *
 * `foundation` first: if connect and register are broken every later batch is
 * noise. `media` late: section N is WebRTC, the long pole, and it must not
 * delay the signal from the cheap batches. `admin` last: it holds the specs
 * that mutate the server globally — the provisioning script's fixed bot names,
 * registration closed server-wide, the nuke safety path — so whatever they
 * leave behind lands on nothing.
 */
const BATCHES = [
  {
    name: "foundation",
    sections: [
      "Auth And Lifecycle",
      "Chat Foundation",
      "P - Performance Budgets",
    ],
  },
  {
    name: "commands",
    sections: [
      "G - Command Surface, Help, Autocomplete, Validation",
      "Q - Catalog, Help, Parser, And Command Surface",
      "L - Config, Scripting, Timers, Custom Menus",
    ],
  },
  {
    name: "channels",
    sections: [
      "H - Channels, Server Messages, Local Window State",
      "I - Channel Modes, Privileges, Moderation",
    ],
  },
  {
    name: "services",
    sections: [
      "K - NickServ And ChanServ",
      "X - Channel Modes, Services, Permissions, Persistence Edges",
    ],
  },
  {
    name: "presence",
    sections: [
      "J - User Commands, Privacy, Presence",
      "W - Presence, Identity, Nick Changes, Whois/Whowas",
    ],
  },
  {
    name: "messages",
    sections: ["O - Chat UI Micro-Journeys", "S - Message Lifecycle Additions"],
  },
  {
    name: "shell",
    sections: [
      "T - Desktop Shell, Menus, Toolbars, Dialogs, And Keyboard",
      "U - Dialog CRUD And Settings Depth",
      "UI Features Browser Regression",
    ],
  },
  {
    name: "persistence",
    sections: [
      "V - Conversations, Tabs, Unread, Mute, And No-Focus-Steal Depth",
      "P - Persistence, Reconnect, History, No-Focus-Steal",
      "AA - Reconnect, Multi-Context, Browser State, And Destructive Safety",
    ],
  },
  {
    name: "security",
    sections: ["R/Y - Security, Safety, And Rendering Additions"],
  },
  {
    name: "media",
    sections: ["N - P2P, File, Call, Game", "SP - Virtual Spaces"],
  },
  {
    name: "public",
    sections: [
      "PW - Public Pages, Landing, And Showcase",
      "MB - Mobile & Touch",
      "LC - Localization",
    ],
  },
  {
    name: "admin",
    sections: [
      "M - Admin, Server Operations, Bots",
      "Y - Bot And Automation Edges",
    ],
  },
];

// playwright.config.ts splits its two projects on the filename, so a batch
// holding mobile specs has to run twice — once per project — or Playwright
// silently runs each spec under whichever project matches and reports the
// other as "no tests found".
const MOBILE = /mobile.*\.spec\.ts$/;

/**
 * Which section a spec belongs to, for the purpose of running it.
 *
 * A header may carry more than one `@section` — four specs do, because a flow
 * about `/perform` on reconnect is honestly both configuration and
 * persistence, and the catalog files each flow under the heading above it.
 * A *run* has no such luxury: a file executes once or it executes twice. The
 * first heading wins, which is the one the spec leads with and the area whose
 * name is in the filename.
 */
function specsBySection() {
  const bySection = new Map();
  const bad = [];

  for (const name of specFiles()) {
    const spec = parseSpec(name);
    if (!spec.sections.length) {
      bad.push(name);
      continue;
    }
    const section = spec.sections[0];
    if (!bySection.has(section)) bySection.set(section, []);
    bySection.get(section).push(spec);
  }

  return { bySection, bad };
}

function batchSpecs(bySection, batch) {
  return batch.sections.flatMap((section) => bySection.get(section) ?? []);
}

function fail(message) {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

function check() {
  const { bySection, bad } = specsBySection();

  if (bad.length) {
    fail(
      "Every spec needs an @section header to be batched. These have none:\n" +
        bad.map((name) => `  ${name}`).join("\n"),
    );
  }

  const assigned = new Set(BATCHES.flatMap((batch) => batch.sections));
  const orphans = [...bySection.keys()].filter((s) => !assigned.has(s));
  if (orphans.length) {
    fail(
      "These @section values belong to no batch, so a sweep would skip them:\n" +
        orphans.map((s) => `  ${s}`).join("\n") +
        "\nAdd the section to a batch in scripts/batches.mjs.",
    );
  }

  const seen = new Map();
  for (const batch of BATCHES) {
    for (const section of batch.sections) {
      if (seen.has(section)) {
        fail(
          `Section "${section}" is in both ${seen.get(section)} and ${batch.name}; ` +
            "a spec must run in exactly one batch.",
        );
      }
      seen.set(section, batch.name);
    }
  }

  const files = BATCHES.reduce(
    (total, batch) => total + batchSpecs(bySection, batch).length,
    0,
  );
  const tests = BATCHES.reduce(
    (total, batch) =>
      total +
      batchSpecs(bySection, batch).reduce((n, spec) => n + spec.testCount, 0),
    0,
  );
  const all = specFiles().length;

  if (files !== all) {
    fail(`The batches cover ${files} spec files, but tests/ holds ${all}.`);
  }

  process.stdout.write(
    `${BATCHES.length} batches cover all ${files} spec files (${tests} tests).\n`,
  );
}

function list() {
  const { bySection } = specsBySection();
  for (const [index, batch] of BATCHES.entries()) {
    const specs = batchSpecs(bySection, batch);
    const tests = specs.reduce((n, spec) => n + spec.testCount, 0);
    process.stdout.write(
      `${String(index + 1).padStart(2)}. ${batch.name.padEnd(12)} ` +
        `${String(specs.length).padStart(3)} files ${String(tests).padStart(3)} tests  ` +
        `${batch.sections.join(" | ")}\n`,
    );
  }
}

function find(name) {
  const batch = BATCHES.find((candidate) => candidate.name === name);
  if (!batch) {
    fail(
      `Unknown batch "${name}". Known: ${BATCHES.map((b) => b.name).join(", ")}`,
    );
  }
  return batch;
}

function main() {
  const args = process.argv.slice(2);

  if (args.includes("--check")) return check();
  if (args.includes("--list")) return list();
  if (args.includes("--names")) {
    return process.stdout.write(`${BATCHES.map((b) => b.name).join(" ")}\n`);
  }

  const name = args.find((arg) => !arg.startsWith("--"));
  if (!name) {
    fail(
      "usage: node scripts/batches.mjs <batch> | --list | --names | --check",
    );
  }

  const batch = find(name);
  const { bySection } = specsBySection();
  const specs = batchSpecs(bySection, batch).map(
    (spec) => `tests/${spec.name}`,
  );

  // A batch that mixes the two projects prints only its desktop half here; the
  // mobile half is asked for separately with --mobile, so the caller runs two
  // commands and neither reports the other's specs as missing.
  const wanted = specs.filter((path) =>
    args.includes("--mobile") ? MOBILE.test(path) : !MOBILE.test(path),
  );

  process.stdout.write(`${wanted.join(" ")}\n`);
}

if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  main();
}

export { BATCHES };

const fs = require("node:fs");
const path = require("node:path");

const ASSETS_ROOT = path.resolve(__dirname, "..");
const REPO_ROOT = path.resolve(ASSETS_ROOT, "../../..");
const JS_ROOT = path.join(ASSETS_ROOT, "js");
const WEB_LIB_ROOT = path.join(REPO_ROOT, "apps/retro_hex_chat_web/lib/retro_hex_chat_web");
const CONTRACT_DOC = "docs/AGENT-GUIDE.md §15";

const ALLOWED_DYNAMIC_IMPORT_FILES = new Set([
  "js/hooks/lazy_feature_hooks.js",
  // Game engines stay lazy-loaded behind the canvas hooks; this loader is the
  // shared catalog for P2P and solo runtimes.
  "js/lib/games/engine_loader.js",
  "js/lib/i18n.js",
  // The public pages defer their LiveSocket until a reader touches the connect
  // window, so the critical bundle stays a fraction of the app's.
  "js/public_pages.js",
]);

const ALLOWED_LAZY_FACADE_FILES = new Set([
  "js/hooks/lazy_feature_hook.js",
  "js/hooks/lazy_feature_hooks.js",
]);

const HOOK_BUILDER_FILES = [
  "js/hooks/critical_hooks.js",
  "js/hooks/lazy_feature_hooks.js",
  "js/hooks/help_hooks.js",
  "js/hooks/showcase_hooks.js",
  "js/hooks/connect_hooks.js",
];

const NON_IMPLEMENTATION_HOOK_FILES = new Set([
  "js/hooks/registry.js",
  "js/hooks/critical_hooks.js",
  "js/hooks/lazy_feature_hooks.js",
  "js/hooks/lazy_feature_hook.js",
  "js/hooks/help_hooks.js",
  "js/hooks/showcase_hooks.js",
  "js/hooks/connect_hooks.js",
]);

// ─── Thinness ratchets ──────────────────────────────────────────────────────
//
// AGENT-GUIDE §15 governs how hooks are *loaded*. These three govern what may
// live *inside* one: a hook binds listeners, registers handleEvent, pushes
// events, and drives a controller from lib/. Everything else — decisions,
// calculations, state machines — belongs in a module that knows nothing about
// LiveView and can therefore be tested without one.
//
// Each ratchet carries the count measured when it was introduced. The number is
// allowed to fall and never to rise, so the standard arrives file by file
// instead of demanding one impossible commit. Lowering a baseline after a
// package lands is part of that package, not a follow-up.

// A hook longer than this is carrying something that is not one of the four.
const HOOK_LINE_LIMIT = 200;

// Every entry is a hook still above the limit, with the package that resolves
// it. Delete the entry in the same commit that shrinks the file — an override
// that outlives its reason is how a budget stops meaning anything.
const HOOK_LINE_OVERRIDES = new Map([
  [
    "js/hooks/group_call/group_call_webrtc_hook.js",
    "W5 extracted quality/payload/reactions/layout/tiles/media-state decisions to " +
      "lib/group_call/*; the residual is live-RTCPeerConnection and tile-DOM plumbing " +
      "whose controller extraction is deferred (see js-hooks-ledger.md)",
  ],
  [
    "js/hooks/lobby/lobby_webrtc_hook.js",
    "W4 extracts the negotiation rules to lib/p2p/negotiation.js",
  ],
  [
    "js/hooks/p2p/file_transfer_hook.js",
    "W6 moves the transfer state machine to lib/p2p/transfer_session.js",
  ],
  [
    "js/hooks/chat/autocomplete_hook.js",
    "W7 extracts the composer key resolver to lib/chat/composer.js",
  ],
  ["js/hooks/chat/chat_viewport_hook.js", "W7 splits scrolling from reader interactions"],
  [
    "js/hooks/space/space_canvas_hook.js",
    "W8 moves loading/modal rendering behind the controllers",
  ],
  [
    "js/hooks/chat/format_toolbar_hook.js",
    "W2 moves the markdown transforms to lib/chat/markdown_format.js",
  ],
  [
    "js/hooks/group_call/group_call_prejoin_hook.js",
    "W2 extracts device constraints and error copy",
  ],
  ["js/hooks/ui/contextual_tips_hook.js", "W8 extracts the tip queue to lib/ui/tip_queue.js"],
  ["js/hooks/connection/connection_status_hook.js", "W8 extracts the state-to-view mapping"],
]);

// Primitives that are a controller in disguise. setInterval and
// requestAnimationFrame are deliberately absent: in a genuinely thin hook like
// clock or lag the timer *is* the effect, and banning them would buy indirection
// and nothing else.
const FORBIDDEN_HOOK_PRIMITIVES = [
  { pattern: /\bnew RTCPeerConnection\b/, name: "new RTCPeerConnection" },
  { pattern: /\.getContext\(/, name: "canvas getContext()" },
  { pattern: /\bnew ResizeObserver\b/, name: "new ResizeObserver" },
  { pattern: /\bnew MutationObserver\b/, name: "new MutationObserver" },
  { pattern: /\bnavigator\.mediaDevices\b/, name: "navigator.mediaDevices" },
  { pattern: /\bnavigator\.clipboard\b/, name: "navigator.clipboard" },
];

const FORBIDDEN_PRIMITIVE_OVERRIDES = new Map([
  ["js/hooks/chat/search_highlight_hook.js", "W8"],
  ["js/hooks/chat/chat_viewport_hook.js", "W7"],
  ["js/hooks/group_call/group_call_prejoin_hook.js", "W2"],
  ["js/hooks/group_call/group_call_webrtc_hook.js", "W5"],
  ["js/hooks/space/space_canvas_hook.js", "W8"],
]);

// A test that reaches for hook._privateMethod is testing something the hook
// should not own. The count is the honest measure of how much logic is still
// trapped; it reaches zero when the extraction is done.
const MAX_HOOK_PRIVATE_CALLS = 201;

// Mutable module scope in lib/ is shared state no test can reset between cases.
// The three that remain are deliberate, not accidental: public_manager holds the
// single window manager the entry bundle and the lazy hook chunk must share;
// interactive coordinates tooltip/hover/context-menu state across the chat hooks;
// tips holds the tip-seen state for the one contextual-tips hook. Each is a
// singleton by design, not logic trapped in the wrong layer.
const LIB_MODULE_STATE_OVERRIDES = new Set([
  "js/lib/ui/tips.js",
  "js/lib/chat/interactive.js",
  "js/lib/window_manager/public_manager.js",
]);

const LIVESOCKET_ENTRYPOINTS = {
  "js/app.js": {
    registryImport: "./hooks/registry",
    hookBuilder: "buildHooks",
  },
  "js/help_live.js": {
    registryImport: "./hooks/help_hooks",
    hookBuilder: "buildHelpHooks",
  },
  "js/retrohex_content.js": {
    registryImport: "./hooks/showcase_hooks",
    hookBuilder: "buildShowcaseHooks",
  },
  "js/connect_boot.js": {
    registryImport: "./hooks/connect_hooks",
    hookBuilder: "buildConnectHooks",
  },
};

function main() {
  const failures = [];

  const appJs = readAsset("js/app.js");
  const registryJs = readAsset("js/hooks/registry.js");
  const criticalJs = readAsset("js/hooks/critical_hooks.js");
  const lazyJs = readAsset("js/hooks/lazy_feature_hooks.js");

  checkAppEntrypoint(appJs, failures);
  checkRegistry(registryJs, failures);
  checkLiveSocketEntrypoints(failures);
  checkHookFileClassification(failures);
  checkLazyFacadeUsage(failures);
  checkDynamicImports(failures);
  checkHookLineBudget(failures);
  checkForbiddenHookPrimitives(failures);
  checkHookTestWhiteBox(failures);
  checkLibModuleState(failures);

  const criticalHooks = parseHookObjectKeys(criticalJs, "criticalHooks", failures);
  const helpHooks = parseHookObjectKeys(readAsset("js/hooks/help_hooks.js"), "helpHooks", failures);
  const showcaseHooks = parseHookObjectKeys(
    readAsset("js/hooks/showcase_hooks.js"),
    "showcaseHooks",
    failures,
  );
  const connectHooks = parseHookObjectKeys(
    readAsset("js/hooks/connect_hooks.js"),
    "connectHooks",
    failures,
  );
  const lazyHooks = parseLazyFeatureHooks(lazyJs, failures);
  checkHookSets(criticalHooks, lazyHooks, failures);
  checkPhxHookUsage(
    new Set([...criticalHooks, ...helpHooks, ...showcaseHooks, ...connectHooks, ...lazyHooks]),
    failures,
  );

  if (failures.length > 0) {
    process.stderr.write(`LiveView hooks contract failed. See ${CONTRACT_DOC}.\n`);
    for (const failure of failures) {
      process.stderr.write(`  - ${failure}\n`);
    }
    process.exitCode = 1;
    return;
  }

  process.stdout.write("LiveView hooks contract passed.\n");
}

function checkAppEntrypoint(source, failures) {
  if (!source.includes('import { buildHooks } from "./hooks/registry"')) {
    failures.push("js/app.js must import buildHooks only from ./hooks/registry.");
  }

  const importPattern = /import\s+(?:[^"']+\s+from\s+)?["']([^"']+)["']/g;
  for (const match of source.matchAll(importPattern)) {
    const importPath = match[1];
    if (importPath.startsWith("./hooks/") && importPath !== "./hooks/registry") {
      failures.push(
        `js/app.js imports ${importPath}; hook implementations must go through hooks/registry.js.`,
      );
    }
  }

  if (!source.includes("hooks: Hooks")) {
    failures.push("js/app.js must pass the buildHooks result to LiveSocket as hooks: Hooks.");
  }
}

function checkLiveSocketEntrypoints(failures) {
  for (const [rel, config] of Object.entries(LIVESOCKET_ENTRYPOINTS)) {
    const source = readAsset(rel);
    const imports = [...source.matchAll(/import\s+(?:[^"']+\s+from\s+)?["']([^"']+)["']/g)].map(
      (match) => match[1],
    );

    if (!imports.includes(config.registryImport)) {
      failures.push(`${rel} must import ${config.hookBuilder} from ${config.registryImport}.`);
    }

    for (const importPath of imports) {
      if (importPath.startsWith("./hooks/") && importPath !== config.registryImport) {
        failures.push(
          `${rel} imports ${importPath}; LiveSocket entrypoints must import only their hook registry builder.`,
        );
      }
    }

    if (!source.includes(`${config.hookBuilder}()`)) {
      failures.push(`${rel} must build its hooks with ${config.hookBuilder}().`);
    }

    if (/hooks\s*:\s*\{/.test(source)) {
      failures.push(`${rel} must not inline a hooks object in LiveSocket options.`);
    }
  }
}

function checkHookFileClassification(failures) {
  const builderSource = HOOK_BUILDER_FILES.map(readAsset).join("\n");
  const hooksRoot = path.join(JS_ROOT, "hooks");

  for (const file of listFiles(hooksRoot, (filename) => filename.endsWith(".js"))) {
    const rel = assetRel(file);
    if (NON_IMPLEMENTATION_HOOK_FILES.has(rel)) continue;

    const importPath = `./${rel.replace(/^js\/hooks\//, "").replace(/\.js$/, "")}`;
    if (!builderSource.includes(`"${importPath}"`) && !builderSource.includes(`'${importPath}'`)) {
      failures.push(
        `${rel} is not referenced by a hook builder; classify it in a hooks/*_hooks.js builder.`,
      );
    }
  }
}

function checkRegistry(source, failures) {
  if (!source.includes('import { criticalHooks } from "./critical_hooks"')) {
    failures.push("hooks/registry.js must import criticalHooks from ./critical_hooks.");
  }

  if (!source.includes('import { lazyFeatureHooks } from "./lazy_feature_hooks"')) {
    failures.push("hooks/registry.js must import lazyFeatureHooks from ./lazy_feature_hooks.");
  }

  if (!source.includes("...criticalHooks") || !source.includes("...lazyFeatureHooks")) {
    failures.push(
      "hooks/registry.js buildHooks() must combine criticalHooks and lazyFeatureHooks.",
    );
  }
}

function checkLazyFacadeUsage(failures) {
  for (const file of listFiles(JS_ROOT, (filename) => filename.endsWith(".js"))) {
    const rel = assetRel(file);
    const source = fs.readFileSync(file, "utf8");
    if (!source.includes("lazyFeatureHook(")) continue;
    if (!ALLOWED_LAZY_FACADE_FILES.has(rel)) {
      failures.push(
        `${rel} calls lazyFeatureHook(); lazy hooks are allowed only in lazy_feature_hooks.js.`,
      );
    }
  }
}

function checkDynamicImports(failures) {
  for (const file of listFiles(JS_ROOT, (filename) => filename.endsWith(".js"))) {
    const rel = assetRel(file);
    const source = fs.readFileSync(file, "utf8");
    const executableSource = stripComments(source);

    if (!/\bimport\s*\(/.test(executableSource)) continue;
    if (!ALLOWED_DYNAMIC_IMPORT_FILES.has(rel)) {
      failures.push(
        `${rel} uses import(); dynamic imports must be added to the approved allowlist.`,
      );
    }
  }
}

function hookImplementationFiles() {
  const hooksRoot = path.join(JS_ROOT, "hooks");

  return listFiles(hooksRoot, (filename) => filename.endsWith(".js")).filter(
    (file) => !NON_IMPLEMENTATION_HOOK_FILES.has(assetRel(file)),
  );
}

function checkHookLineBudget(failures) {
  const over = new Set();

  for (const file of hookImplementationFiles()) {
    const rel = assetRel(file);
    const lines = fs.readFileSync(file, "utf8").split("\n").length;
    if (lines <= HOOK_LINE_LIMIT) continue;

    over.add(rel);
    if (HOOK_LINE_OVERRIDES.has(rel)) continue;

    failures.push(
      `${rel} is ${lines} lines, over the ${HOOK_LINE_LIMIT}-line hook budget. ` +
        "Move the decisions into a lib/ module, or add an override naming the package that will.",
    );
  }

  for (const rel of HOOK_LINE_OVERRIDES.keys()) {
    if (over.has(rel)) continue;
    failures.push(
      `${rel} is within the hook budget; drop its HOOK_LINE_OVERRIDES entry in this commit.`,
    );
  }
}

function checkForbiddenHookPrimitives(failures) {
  const used = new Set();

  for (const file of hookImplementationFiles()) {
    const rel = assetRel(file);
    const source = stripComments(fs.readFileSync(file, "utf8"));
    const found = FORBIDDEN_HOOK_PRIMITIVES.filter((primitive) => primitive.pattern.test(source));
    if (found.length === 0) continue;

    used.add(rel);
    if (FORBIDDEN_PRIMITIVE_OVERRIDES.has(rel)) continue;

    failures.push(
      `${rel} uses ${found.map((primitive) => primitive.name).join(", ")}; ` +
        "that belongs to a controller in lib/, which the hook then creates and destroys.",
    );
  }

  for (const rel of FORBIDDEN_PRIMITIVE_OVERRIDES.keys()) {
    if (used.has(rel)) continue;
    failures.push(
      `${rel} no longer uses a forbidden primitive; drop its FORBIDDEN_PRIMITIVE_OVERRIDES entry.`,
    );
  }
}

function checkHookTestWhiteBox(failures) {
  const testRoot = path.join(ASSETS_ROOT, "test/hooks");
  if (!fs.existsSync(testRoot)) return;

  let calls = 0;

  for (const file of listFiles(testRoot, (filename) => filename.endsWith(".js"))) {
    const source = fs.readFileSync(file, "utf8");
    calls += (source.match(/hook\._[a-zA-Z]/g) || []).length;
  }

  if (calls > MAX_HOOK_PRIVATE_CALLS) {
    failures.push(
      `test/hooks reaches into hook private methods ${calls} times, over the ceiling of ` +
        `${MAX_HOOK_PRIVATE_CALLS}. Test the lib/ module the logic belongs to instead.`,
    );
  }

  if (calls < MAX_HOOK_PRIVATE_CALLS) {
    failures.push(
      `test/hooks is down to ${calls} private-method calls; lower MAX_HOOK_PRIVATE_CALLS to ` +
        `${calls} in this commit so the ratchet holds.`,
    );
  }
}

function checkLibModuleState(failures) {
  const libRoot = path.join(JS_ROOT, "lib");

  for (const file of listFiles(libRoot, (filename) => filename.endsWith(".js"))) {
    const rel = assetRel(file);
    if (LIB_MODULE_STATE_OVERRIDES.has(rel)) continue;

    const source = stripComments(fs.readFileSync(file, "utf8"));
    if (!/^(let|var)\s/m.test(source)) continue;

    failures.push(
      `${rel} declares mutable module scope; keep that state inside a create*() closure ` +
        "so two tests cannot contaminate each other.",
    );
  }
}

function stripComments(source) {
  return source.replace(/\/\*[\s\S]*?\*\//g, "").replace(/(^|[^:])\/\/.*$/gm, "$1");
}

function parseHookObjectKeys(source, exportName, failures) {
  const startMarker = `export const ${exportName} = {`;
  const start = source.indexOf(startMarker);
  if (start === -1) {
    failures.push(`hooks/${exportName}.js export ${exportName} was not found.`);
    return new Set();
  }

  const end = source.indexOf("};", start);
  if (end === -1) {
    failures.push(`${exportName} object is not closed with };.`);
    return new Set();
  }

  const body = source.slice(start + startMarker.length, end);
  const keys = new Set();
  const keyPattern = /^\s{2}([A-Za-z][A-Za-z0-9_]*)\s*:/gm;

  for (const match of body.matchAll(keyPattern)) {
    keys.add(match[1]);
  }

  if (keys.size === 0) {
    failures.push(`${exportName} must declare at least one hook.`);
  }

  return keys;
}

function parseLazyFeatureHooks(source, failures) {
  const hooks = new Set();
  const entryPattern =
    /^\s{2}([A-Za-z][A-Za-z0-9_]*)\s*:\s*lazyFeatureHook\(\{([\s\S]*?)^\s{2}\}\),/gm;

  for (const match of source.matchAll(entryPattern)) {
    const hookName = match[1];
    const body = match[2];
    hooks.add(hookName);

    requireStringProperty(body, hookName, "name", failures);
    requireStringProperty(body, hookName, "reason", failures);

    const declaredName = stringPropertyValue(body, "name");
    if (declaredName && declaredName !== hookName) {
      failures.push(
        `lazyFeatureHooks.${hookName} declares name "${declaredName}". It must match the registry key.`,
      );
    }

    if (!/loader\s*:\s*\(\)\s*=>\s*import\(/.test(body)) {
      failures.push(`lazyFeatureHooks.${hookName} must declare loader: () => import(...).`);
    }

    const serverEvents = arrayPropertyValues(body, "serverEvents");
    const readyEvent = stringPropertyValue(body, "readyEvent");
    const hasReadyEvent = Boolean(readyEvent);
    const safeWithoutReady = /safeWithoutReady\s*:\s*true\b/.test(body);
    const hasSafeWithoutReadyReason = /safeWithoutReadyReason\s*:/.test(body);

    if (safeWithoutReady || hasSafeWithoutReadyReason) {
      failures.push(
        `lazyFeatureHooks.${hookName} uses safeWithoutReady; server-pushed lazy hooks must use readyEvent.`,
      );
    }

    if (serverEvents.length > 0 && !hasReadyEvent) {
      failures.push(
        `lazyFeatureHooks.${hookName} handles serverEvents and must declare readyEvent.`,
      );
    }

    if (hasReadyEvent) {
      checkReadyEventContract(hookName, readyEvent, failures);
    }
  }

  if (hooks.size === 0) {
    failures.push(
      "lazy_feature_hooks.js must declare lazyFeatureHooks entries with lazyFeatureHook(...).",
    );
  }

  return hooks;
}

function checkHookSets(criticalHooks, lazyHooks, failures) {
  for (const hookName of criticalHooks) {
    if (lazyHooks.has(hookName)) {
      failures.push(`${hookName} is declared as both critical and lazyFeature.`);
    }
  }
}

function checkReadyEventContract(hookName, readyEvent, failures) {
  const escapedEvent = escapeRegExp(readyEvent);
  const pushPattern = new RegExp(`pushEvent\\(\\s*["']${escapedEvent}["']`);
  const configuredMediaReadyPattern = new RegExp(
    `createRtcMediaHook\\(\\{[\\s\\S]*?clientEvents\\s*:\\s*\\{[\\s\\S]*?ready\\s*:\\s*["']${escapedEvent}["']`,
  );
  const handlePattern = new RegExp(`handle_event\\(\\s*["']${escapedEvent}["']`);

  if (
    !treeContains(JS_ROOT, (filename) => filename.endsWith(".js"), pushPattern) &&
    !treeContains(JS_ROOT, (filename) => filename.endsWith(".js"), configuredMediaReadyPattern)
  ) {
    failures.push(
      `lazyFeatureHooks.${hookName} declares readyEvent "${readyEvent}" but no asset hook pushes it.`,
    );
  }

  if (
    !treeContains(
      WEB_LIB_ROOT,
      (filename) => filename.endsWith(".ex") || filename.endsWith(".heex"),
      handlePattern,
    )
  ) {
    failures.push(
      `lazyFeatureHooks.${hookName} declares readyEvent "${readyEvent}" but no LiveView handles it.`,
    );
  }
}

function checkPhxHookUsage(registryHooks, failures) {
  const files = listFiles(
    WEB_LIB_ROOT,
    (filename) => filename.endsWith(".heex") || filename.endsWith(".ex"),
  );
  const hookPattern = /phx-hook\s*=\s*"([^"]+)"/g;

  for (const file of files) {
    const source = fs.readFileSync(file, "utf8");
    for (const match of source.matchAll(hookPattern)) {
      const hookName = match[1];
      if (registryHooks.has(hookName)) continue;

      failures.push(
        `${repoRel(file)}:${lineNumber(source, match.index)} uses phx-hook="${hookName}" without a main registry entry or entrypoint exception.`,
      );
    }
  }
}

function requireStringProperty(source, hookName, property, failures) {
  if (!stringPropertyValue(source, property)) {
    failures.push(`lazyFeatureHooks.${hookName} must declare non-empty ${property}.`);
  }
}

function stringPropertyValue(source, property) {
  const pattern = new RegExp(`${property}\\s*:\\s*"([^"]+)"`);
  return source.match(pattern)?.[1] || null;
}

function arrayPropertyValues(source, property) {
  const pattern = new RegExp(`${property}\\s*:\\s*\\[([\\s\\S]*?)\\]`);
  const body = source.match(pattern)?.[1];
  if (!body) return [];

  return [...body.matchAll(/"([^"]+)"/g)].map((match) => match[1]);
}

function treeContains(dir, predicate, pattern) {
  for (const file of listFiles(dir, predicate)) {
    const source = fs.readFileSync(file, "utf8");
    if (pattern.test(source)) return true;
  }

  return false;
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function readAsset(relPath) {
  return fs.readFileSync(path.join(ASSETS_ROOT, relPath), "utf8");
}

function listFiles(dir, predicate) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...listFiles(fullPath, predicate));
    } else if (predicate(fullPath)) {
      files.push(fullPath);
    }
  }

  return files;
}

function assetRel(file) {
  return toPosix(path.relative(ASSETS_ROOT, file));
}

function repoRel(file) {
  return toPosix(path.relative(REPO_ROOT, file));
}

function toPosix(file) {
  return file.split(path.sep).join("/");
}

function lineNumber(source, index) {
  return source.slice(0, index).split("\n").length;
}

main();

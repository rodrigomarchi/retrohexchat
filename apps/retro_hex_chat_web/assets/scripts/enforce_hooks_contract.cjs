const fs = require("node:fs");
const path = require("node:path");

const ASSETS_ROOT = path.resolve(__dirname, "..");
const REPO_ROOT = path.resolve(ASSETS_ROOT, "../../..");
const JS_ROOT = path.join(ASSETS_ROOT, "js");
const WEB_LIB_ROOT = path.join(REPO_ROOT, "apps/retro_hex_chat_web/lib/retro_hex_chat_web");
const CONTRACT_DOC = "docs/046-liveview-js-hook-loading-standard.md";

const ALLOWED_DYNAMIC_IMPORT_FILES = new Set([
  "js/hooks/lazy_feature_hooks.js",
  "js/hooks/games/game_canvas_hook.js",
  "js/lib/i18n.js",
]);

const ALLOWED_LAZY_FACADE_FILES = new Set([
  "js/hooks/lazy_feature_hook.js",
  "js/hooks/lazy_feature_hooks.js",
]);

const ENTRYPOINT_SCOPED_HOOKS = new Set([
  // Showcase route uses a separate LiveSocket in retrohex_content.js.
  "Highlight",
]);

function main() {
  const failures = [];

  const appJs = readAsset("js/app.js");
  const registryJs = readAsset("js/hooks/registry.js");
  const criticalJs = readAsset("js/hooks/critical_hooks.js");
  const lazyJs = readAsset("js/hooks/lazy_feature_hooks.js");

  checkAppEntrypoint(appJs, failures);
  checkRegistry(registryJs, failures);
  checkLazyFacadeUsage(failures);
  checkDynamicImports(failures);

  const criticalHooks = parseHookObjectKeys(criticalJs, "criticalHooks", failures);
  const lazyHooks = parseLazyFeatureHooks(lazyJs, failures);
  checkHookSets(criticalHooks, lazyHooks, failures);
  checkPhxHookUsage(new Set([...criticalHooks, ...lazyHooks]), failures);

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
    if (!source.includes("import(")) continue;
    if (!ALLOWED_DYNAMIC_IMPORT_FILES.has(rel)) {
      failures.push(
        `${rel} uses import(); dynamic imports must be added to the approved allowlist.`,
      );
    }
  }
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
  const handlePattern = new RegExp(`handle_event\\(\\s*["']${escapedEvent}["']`);

  if (!treeContains(JS_ROOT, (filename) => filename.endsWith(".js"), pushPattern)) {
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
      if (registryHooks.has(hookName) || ENTRYPOINT_SCOPED_HOOKS.has(hookName)) continue;

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

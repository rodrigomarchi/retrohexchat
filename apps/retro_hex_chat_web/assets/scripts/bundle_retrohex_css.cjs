const fs = require("fs");
const path = require("path");

const assetsRoot = path.resolve(__dirname, "..");
const entryPath = path.join(assetsRoot, "css", "retrohex.css");
const outputDir = path.join(assetsRoot, "css", ".generated");
const outputPath = path.join(outputDir, "retrohex.css");
const cssRoot = path.join(assetsRoot, "css");

function bundle() {
  const entry = fs.readFileSync(entryPath, "utf8");

  const bundled = entry.replace(
    /^@import\s+"(\.\/retrohex\/[^"]+\.css)";\s*$/gm,
    (_match, importPath) => {
      const resolved = path.resolve(cssRoot, importPath);

      if (!resolved.startsWith(path.join(cssRoot, "retrohex") + path.sep)) {
        throw new Error(`Refusing to import CSS outside source modules: ${importPath}`);
      }

      return fs.readFileSync(resolved, "utf8").trimEnd();
    },
  );

  fs.mkdirSync(outputDir, { recursive: true });
  fs.writeFileSync(outputPath, `${bundled.trimEnd()}\n`);
}

bundle();

// `--watch` keeps the generated bundle in sync while the dev server runs, so
// Tailwind's own watcher always reads an entrypoint with the source modules
// already inlined.
if (process.argv.includes("--watch")) {
  let pending = null;

  const rebuild = () => {
    clearTimeout(pending);
    pending = setTimeout(() => {
      try {
        bundle();
        process.stdout.write("[bundle_retrohex_css] rebuilt css/.generated/retrohex.css\n");
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        process.stderr.write(`[bundle_retrohex_css] ${message}\n`);
      }
    }, 50);
  };

  fs.watch(entryPath, rebuild);
  fs.watch(path.join(cssRoot, "retrohex"), { recursive: true }, rebuild);
}

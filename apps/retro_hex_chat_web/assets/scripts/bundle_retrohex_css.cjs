const fs = require("fs");
const path = require("path");

const assetsRoot = path.resolve(__dirname, "..");
const entryPath = path.join(assetsRoot, "css", "retrohex.css");
const outputDir = path.join(assetsRoot, "css", ".generated");
const outputPath = path.join(outputDir, "retrohex.css");
const cssRoot = path.join(assetsRoot, "css");

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

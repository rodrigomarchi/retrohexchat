/**
 * Captures a real screenshot of every game in the public catalogue.
 *
 *   make games.shots                       # every game
 *   make games.shots ONLY=doom-shareware   # just these slugs (comma-separated)
 *
 * The list of games comes from `RetroHexChatWeb.GameCatalog.capture_targets/0`,
 * written to JSON by the make target, so a game added to a catalogue is a game
 * this captures without an edit here.
 *
 * - Arcade games run on the public static host, exactly as a player gets them.
 *   A game is ready when its canvas has grown past the loader's 300x150 and the
 *   loader's "Downloading…" text is gone; Quake takes two minutes over the WAN.
 * - Multiplayer games run on the local e2e server (`E2E_BASE_URL`, default
 *   :4003), which must be up: playing needs a nickname, so the script registers
 *   a throwaway one, opens each game and starts a match against the AI.
 *
 * A single frame is a gamble — the DOOM demo is as likely to show a wall as a
 * room — so several frames are taken a few seconds apart and the one with the
 * most detail (the largest PNG) is kept. Chromium itself converts it to WebP,
 * which spares the repository an image toolchain.
 *
 * A game the capture cannot reach (a 195 MB download, an engine that will not
 * start headless) takes a published screenshot instead:
 *
 *   node scripts/capture-game-shots.mjs --import <slug> <file> <source-url> [x,y,w,h]
 *
 * which crops and converts it the same way and records where it came from.
 *
 * Every picture also gets a share card, `og/<slug>.jpg`: 1200x630, the game
 * centred on black, JPEG because LinkedIn and WhatsApp do not reliably show
 * WebP. `--og` rebuilds the cards from the WebP files already there.
 *
 * Writes `apps/retro_hex_chat_web/priv/static/images/games/<slug>.webp` and
 * merges each size into `manifest.json` there, which the catalogue reads at
 * compile time.
 */
import { chromium } from "@playwright/test";
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const outDir = path.resolve(
  here,
  "../../apps/retro_hex_chat_web/priv/static/images/games",
);
const manifestPath = path.join(outDir, "manifest.json");
const baseURL =
  process.env.E2E_BASE_URL ||
  `http://localhost:${process.env.E2E_PORT || "4003"}`;

const cli = process.argv.slice(2);
const importing = cli[0] === "--import";
const rebuildingCards = cli[0] === "--og";
const [targetsPath] = cli;
const only = (process.env.ONLY || "").split(",").filter(Boolean);
const targets =
  importing || rebuildingCards
    ? []
    : JSON.parse(readFileSync(targetsPath, "utf8")).filter(
        (t) => only.length === 0 || only.includes(t.slug),
      );

// Width the page renders the picture at, at most. Larger only costs bytes.
const MAX_WIDTH = 960;
const WEBP_QUALITY = 0.82;
const CARD_WIDTH = 1200;
const CARD_HEIGHT = 630;
const CARD_QUALITY = 0.85;
// The static host serves a few hundred KB/s and LibreQuake's data is 195 MB,
// so a game may take many minutes to arrive. SHOTS_TIMEOUT_MIN raises it.
const GAME_TIMEOUT = Number(process.env.SHOTS_TIMEOUT_MIN || 20) * 60_000;
const ARCADE_FRAMES = 5;
const ARCADE_FRAME_GAP = 4_000;
const MATCH_WARMUP = 6_000;
const MATCH_FRAMES = 4;
const MATCH_FRAME_GAP = 1_500;
const MATCH_TIMEOUT = 60_000;
// How much a frame's luminance has to vary to count as a picture. A canvas
// that is up but still black — ScummVM draws its full-size canvas minutes
// before its game data has arrived — scores 0, and ScummVM's flat orange
// splash 4; the darkest neon arena in the multiplayer set scores 6.
const MIN_DETAIL = 5;
// ScummVM opens on its own splash and then the game's intro; frames spread
// over a minute and a half reach the game rather than the title cards.
const FRAME_GAP_BY_ENGINE = { scummvm: 15_000 };

mkdirSync(path.join(outDir, "og"), { recursive: true });
const manifest = existsSync(manifestPath)
  ? JSON.parse(readFileSync(manifestPath, "utf8"))
  : {};

// Software GL, so the WebGL engines (Quake, Half-Life) draw headless.
const browser = await chromium.launch({
  args: [
    "--use-gl=angle",
    "--use-angle=swiftshader",
    "--enable-unsafe-swiftshader",
    "--ignore-gpu-blocklist",
  ],
});
const converter = await browser.newPage();
const failures = [];

try {
  if (importing) {
    const [, slug, file, source, crop] = cli;
    if (!slug || !file || !source)
      throw new Error("usage: --import <slug> <file> <source-url> [x,y,w,h]");
    const clip = crop ? crop.split(",").map(Number) : null;
    const { webp, width, height } = await toWebp(readFileSync(file), clip);
    writeFileSync(path.join(outDir, `${slug}.webp`), webp);
    manifest[slug] = { width, height, source, og: await writeCard(slug, webp) };
    console.log(
      `${slug}: ${width}x${height}, ${Math.round(webp.length / 1024)} KB, from ${source}`,
    );
  }

  if (rebuildingCards) {
    for (const slug of Object.keys(manifest)) {
      const webp = readFileSync(path.join(outDir, `${slug}.webp`));
      manifest[slug] = { ...manifest[slug], og: await writeCard(slug, webp) };
    }

    console.log(`${Object.keys(manifest).length} share cards rebuilt`);
  }

  for (const target of targets.filter((t) => t.kind === "arcade")) {
    await capture(target, () => captureArcade(target));
  }

  const multiplayer = targets.filter((t) => t.kind === "multiplayer");

  if (multiplayer.length > 0) {
    const page = await browser.newPage({
      viewport: { width: 1280, height: 800 },
    });
    await connectWithNewNick(page);

    for (const target of multiplayer) {
      await capture(target, () => captureMatch(page, target));
    }

    await page.close();
  }
} finally {
  writeFileSync(
    manifestPath,
    JSON.stringify(sortKeys(manifest), null, 2) + "\n",
  );
  await browser.close();
}

if (failures.length > 0) {
  console.error(
    `\n${failures.length} game(s) not captured: ${failures.join(", ")}`,
  );
  process.exit(1);
}

async function capture(target, takeFrames) {
  const started = Date.now();

  try {
    const frames = await takeFrames();
    // The most detailed of the frames that are pictures at all. PNG size is
    // the measure: it grows with everything a frame has to show.
    const best = frames.reduce((a, b) => (b.length > a.length ? b : a));
    const { webp, width, height } = await toWebp(best);
    writeFileSync(path.join(outDir, `${target.slug}.webp`), webp);
    manifest[target.slug] = {
      width,
      height,
      source: "captured",
      og: await writeCard(target.slug, webp),
    };
    console.log(
      `${target.slug}: ${width}x${height}, ${Math.round(webp.length / 1024)} KB, ${seconds(started)}s`,
    );
  } catch (error) {
    failures.push(target.slug);
    console.error(
      `${target.slug}: failed after ${seconds(started)}s — ${error.message.split("\n")[0]}`,
    );
  }
}

async function captureArcade(target) {
  const page = await browser.newPage({
    viewport: { width: 1280, height: 800 },
  });

  try {
    // The game's canvas is the largest one on screen. Not the largest by
    // resolution: FreeDM keeps a full-size canvas hidden at zero width.
    await page.addInitScript(() => {
      window.__shownCanvas = () =>
        [...document.querySelectorAll("canvas")]
          .map((canvas) => ({ canvas, box: canvas.getBoundingClientRect() }))
          .filter(({ box }) => box.width > 0 && box.height > 0)
          .sort(
            (a, b) => b.box.width * b.box.height - a.box.width * a.box.height,
          )[0]?.canvas;
    });
    await page.goto(target.url);

    await page.waitForFunction(
      () => {
        const canvas = window.__shownCanvas();
        return canvas && canvas.width * canvas.height > 300 * 150;
      },
      null,
      { timeout: GAME_TIMEOUT, polling: 1_000 },
    );

    const canvas = await page.evaluateHandle(() => window.__shownCanvas());

    // The page clipped to the canvas rather than toDataURL, which reads a
    // WebGL canvas without preserveDrawingBuffer back blank — and rather than
    // an element screenshot, which waits for the element to hold still and a
    // running game never does.
    const gap = FRAME_GAP_BY_ENGINE[target.engine] || ARCADE_FRAME_GAP;
    const frames = await sampleFrames(
      page,
      ARCADE_FRAMES,
      gap,
      GAME_TIMEOUT,
      async () =>
        page.screenshot({
          clip: await canvas.asElement().boundingBox(),
          timeout: 60_000,
        }),
    );

    return frames;
  } finally {
    await page.close();
  }
}

async function captureMatch(page, target) {
  await page.goto(`${baseURL}${target.path}`);
  await page.getByRole("button", { name: "Play vs AI" }).click();
  await page.waitForTimeout(MATCH_WARMUP);

  // The canvas's own pixels: the desktop's toolbars overlap it on screen.
  const frames = await sampleFrames(
    page,
    MATCH_FRAMES,
    MATCH_FRAME_GAP,
    MATCH_TIMEOUT,
    async () => {
      const dataUrl = await page
        .locator("canvas")
        .first()
        .evaluate((c) => c.toDataURL("image/png"));
      return Buffer.from(dataUrl.split(",")[1], "base64");
    },
  );

  await page
    .getByRole("button", { name: "End" })
    .click()
    .catch((error) => {
      console.warn(
        `${target.slug}: could not end the match — ${error.message.split("\n")[0]}`,
      );
    });

  return frames;
}

// Takes frames until `wanted` of them are pictures, or `timeout` runs out.
// Frames that are one flat colour — a loader, a black screen — are dropped,
// and a game that never shows anything fails rather than shipping a black box.
async function sampleFrames(page, wanted, gap, timeout, takeFrame) {
  const deadline = Date.now() + timeout;
  const frames = [];
  let flattest = 0;

  while (frames.length < wanted && Date.now() < deadline) {
    await page.waitForTimeout(gap);
    const png = await takeFrame();
    const score = await detail(png);
    flattest = Math.max(flattest, score);

    if (score >= MIN_DETAIL) frames.push(png);
  }

  if (frames.length === 0) {
    throw new Error(
      `no frame had any picture in it (best detail ${flattest.toFixed(1)} < ${MIN_DETAIL})`,
    );
  }

  return frames;
}

// The standard deviation of a frame's luminance, on a small copy of it.
async function detail(png) {
  return converter.evaluate(async (base64) => {
    const image = new Image();
    image.src = `data:image/png;base64,${base64}`;
    await image.decode();

    const canvas = document.createElement("canvas");
    canvas.width = 160;
    canvas.height = 100;
    const context = canvas.getContext("2d");
    context.drawImage(image, 0, 0, canvas.width, canvas.height);

    const { data } = context.getImageData(0, 0, canvas.width, canvas.height);
    let sum = 0;
    let squares = 0;
    const pixels = data.length / 4;

    for (let i = 0; i < data.length; i += 4) {
      const luminance =
        0.2126 * data[i] + 0.7152 * data[i + 1] + 0.0722 * data[i + 2];
      sum += luminance;
      squares += luminance * luminance;
    }

    const mean = sum / pixels;
    return Math.sqrt(Math.max(0, squares / pixels - mean * mean));
  }, png.toString("base64"));
}

// A new nickname is offered registration, and taking it is the one way past
// the connect screen: a throwaway nick with a throwaway password.
async function connectWithNewNick(page) {
  const password = `shots-${Date.now()}`;

  await page.goto(`${baseURL}/connect`);
  await page
    .locator("#nickname")
    .fill(`shots${Date.now().toString(36).slice(-5)}`);
  await page.getByTestId("connect-btn").click();
  await page.locator("#reg-password").fill(password);
  await page.locator("#reg-password-confirm").fill(password);
  await page.getByTestId("register-btn").click();
  await page.waitForURL(/\/chat/, { timeout: 30_000 });
}

async function toWebp(png, clip = null) {
  const result = await converter.evaluate(
    async ({ base64, maxWidth, quality, clip }) => {
      const image = new Image();
      image.src = `data:image/png;base64,${base64}`;
      await image.decode();

      const [sx, sy, sw, sh] = clip || [
        0,
        0,
        image.naturalWidth,
        image.naturalHeight,
      ];
      const scale = Math.min(1, maxWidth / sw);
      const canvas = document.createElement("canvas");
      canvas.width = Math.round(sw * scale);
      canvas.height = Math.round(sh * scale);

      const context = canvas.getContext("2d");
      // Pixel art stays pixel art when it is scaled down.
      context.imageSmoothingEnabled = scale < 1;
      context.drawImage(
        image,
        sx,
        sy,
        sw,
        sh,
        0,
        0,
        canvas.width,
        canvas.height,
      );

      const webp = canvas.toDataURL("image/webp", quality);

      if (!webp.startsWith("data:image/webp"))
        throw new Error("this Chromium cannot encode WebP");

      return {
        base64: webp.split(",")[1],
        width: canvas.width,
        height: canvas.height,
      };
    },
    {
      base64: png.toString("base64"),
      maxWidth: MAX_WIDTH,
      quality: WEBP_QUALITY,
      clip,
    },
  );

  return {
    webp: Buffer.from(result.base64, "base64"),
    width: result.width,
    height: result.height,
  };
}

// The share card: the picture centred on black at the size every platform
// crops a large card to, so nothing of the game is cut off.
async function writeCard(slug, webp) {
  const base64 = await converter.evaluate(
    async ({ source, width, height, quality }) => {
      const image = new Image();
      image.src = `data:image/webp;base64,${source}`;
      await image.decode();

      const canvas = document.createElement("canvas");
      canvas.width = width;
      canvas.height = height;
      const context = canvas.getContext("2d");
      context.fillStyle = "black";
      context.fillRect(0, 0, width, height);

      const scale = Math.min(
        width / image.naturalWidth,
        height / image.naturalHeight,
      );
      const drawnWidth = Math.round(image.naturalWidth * scale);
      const drawnHeight = Math.round(image.naturalHeight * scale);
      context.drawImage(
        image,
        (width - drawnWidth) / 2,
        (height - drawnHeight) / 2,
        drawnWidth,
        drawnHeight,
      );

      return canvas.toDataURL("image/jpeg", quality).split(",")[1];
    },
    {
      source: webp.toString("base64"),
      width: CARD_WIDTH,
      height: CARD_HEIGHT,
      quality: CARD_QUALITY,
    },
  );

  writeFileSync(
    path.join(outDir, "og", `${slug}.jpg`),
    Buffer.from(base64, "base64"),
  );
  return { width: CARD_WIDTH, height: CARD_HEIGHT };
}

function sortKeys(object) {
  return Object.fromEntries(
    Object.keys(object)
      .sort()
      .map((key) => [key, object[key]]),
  );
}

function seconds(since) {
  return Math.round((Date.now() - since) / 1000);
}

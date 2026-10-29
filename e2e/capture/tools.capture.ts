/**
 * Captures the pictures of the public pages of Hex Paint (`/paint`), ASCII
 * Art (`/ascii-art`) and Hex Radio (`/radio`): each program open on the
 * desktop with something made in it, the channel those things were posted
 * to, and the radio playing with its equalizer open.
 *
 *   make tools.shots
 *
 * Not a test: it runs only under `make tools.shots` (the `capture` project of
 * `playwright.config.ts`), against the local e2e server, with a throwaway
 * nickname in a channel of its own. Every picture is the real desktop at
 * 1280x720, so the pages never show a window the product does not draw.
 *
 * The drawing is put in Hex Paint's draft before the window opens — the same
 * place the browser keeps somebody's drawing between visits — so the picture
 * is pixel art rather than a mouse's scribble. Each picture is written at full
 * size and halved to the pixel (`-half`). The radio's station is one of
 * `Radio.Fixture`'s; its stream is answered here with a chord the script
 * makes, shared with the page, so the spectrum is the real one; each program's share card,
 * `og/<name>.jpg`, is cut from its picture's centre at 1200x630. The page
 * reads every size from `manifest.json` at compile time.
 *
 * Writes `apps/retro_hex_chat_web/priv/static/images/tools/`.
 */
import { mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import { expect, Page, test } from "@playwright/test";
import {
  closeUsers,
  newSignedInUser,
  uniqueChannel,
} from "../helpers/chatUsers";
import { sortKeys, toCard, toWebp } from "../scripts/lib/images.mjs";

const OUT_DIR = path.resolve(
  __dirname,
  "../../apps/retro_hex_chat_web/priv/static/images/tools",
);
const WEBP_QUALITY = 0.85;
const CARD = { width: 1200, height: 630, quality: 0.85 };

type Picture = { width: number; height: number };
const manifest: Record<string, Picture> = {};

// A heart over a starry night, in mIRC colour numbers (hex digits), "." clear.
// Every character is a pixel of a 32x32 drawing.
const NIGHT = "2";
const HEART = [
  "..55555.....55555..",
  ".5444445...5444445.",
  "544004445.544444445",
  "5444444445444444445",
  "5444444444444444445",
  "5444444444444444445",
  ".54444444444444445.",
  "..544444444444445..",
  "...5444444444445...",
  "....54444444445....",
  ".....544444445.....",
  "......5444445......",
  ".......54445.......",
  "........545........",
  ".........5.........",
];
const STARS = [
  [3, 3],
  [27, 4],
  [6, 26],
  [25, 27],
  [15, 2],
  [2, 15],
  [29, 16],
];

function drawing(): string {
  const size = 32;
  const pixels = Array.from({ length: size * size }, () => NIGHT);
  STARS.forEach(([x, y]) => (pixels[y * size + x] = "8"));
  HEART.forEach((row, r) =>
    [...row].forEach((c, i) => {
      if (c !== ".") pixels[(r + 8) * size + i + 6] = c;
    }),
  );
  return `${size}:${pixels.join("")}`;
}

test("captures the pictures of the Hex Paint, ASCII Art and Hex Radio pages", async ({
  browser,
}) => {
  test.setTimeout(3 * 60_000);
  mkdirSync(path.join(OUT_DIR, "og"), { recursive: true });

  const ana = await newSignedInUser(browser, "art");
  try {
    const page = ana.page;
    const channel = uniqueChannel("art");
    await ana.chat.sendMessage(`/join ${channel}`);
    // The drawing waits as a draft.
    await page.evaluate(
      (draft) => window.localStorage.setItem("retrohex.paint.draft", draft),
      drawing(),
    );

    // Hex Paint, open on the drawing.
    await ana.chat.sendMessage("/paint");
    const paint = page.getByTestId("paint-window");
    await expect(paint).toBeVisible();
    await expect
      .poll(() =>
        page
          .getByTestId("hex-paint-canvas")
          .evaluate((el: HTMLCanvasElement) => el.width),
      )
      .toBeGreaterThan(32);
    await page.getByTestId("hex-paint-tool-bucket").click();
    const paintShot = await save(page, "paint");
    writeFileSync(
      path.join(OUT_DIR, "og", "paint.jpg"),
      await toCard(page, paintShot, { ...CARD, fit: "crop" }),
    );
    manifest["og/paint"] = { width: CARD.width, height: CARD.height };

    // Posted, with a line of text.
    await page
      .getByTestId("hex-paint-menu-bar")
      .locator(".app-menu-bar__desktop-menu")
      .first()
      .locator("button[data-menubar-trigger]")
      .click();
    await page
      .getByTestId("hex-paint-menu-bar")
      .locator(".app-menu-bar__desktop-menu")
      .getByTestId("hex-paint-menu-post")
      .click();
    await expect(page.getByTestId("hex-paint-post-submit")).toBeEnabled();
    await page
      .getByTestId("hex-paint-post-caption")
      .fill("made this in Hex Paint");
    await page.getByTestId("hex-paint-post-submit").click();
    await paint.locator("[data-window-control='close']").click();

    // ASCII Art, a word in shaded rainbow blocks.
    await ana.chat.sendMessage("/ascii");
    const ascii = page.getByTestId("ascii-art-window");
    await expect(ascii).toBeVisible();
    await page.getByTestId("ascii-art-text").fill("RETRO");
    for (const [name, option] of [
      ["ascii-style", "With a shadow"],
      ["ascii-scheme", "Rainbow"],
    ]) {
      await page.getByTestId(name).locator("button").first().click();
      await page
        .getByTestId(name)
        .getByRole("option", { name: option })
        .click();
      // The list closes in a short transition; the picture waits for it.
      await expect(
        page.getByTestId(name).locator(".select-content"),
      ).toBeHidden();
    }
    await expect(
      page.getByTestId("ascii-art-preview").locator("pre.irc-art"),
    ).toContainText("░");
    const asciiShot = await save(page, "ascii_art");
    writeFileSync(
      path.join(OUT_DIR, "og", "ascii_art.jpg"),
      await toCard(page, asciiShot, { ...CARD, fit: "crop" }),
    );
    manifest["og/ascii_art"] = { width: CARD.width, height: CARD.height };

    await ascii
      .locator(".app-menu-bar__desktop-menu")
      .first()
      .locator("button[data-menubar-trigger]")
      .click();
    await ascii
      .locator(".app-menu-bar__desktop-menu")
      .getByTestId("ascii-art-menu-post")
      .click();
    await page.getByTestId("ascii-art-post-submit").click();
    await ascii.locator("[data-window-control='close']").click();

    // The channel with both in it.
    await expect(ana.chat.messageList.locator("pre.irc-art")).toBeVisible();
    await expect(
      ana.chat.messageList.getByTestId("message-attachment-image-preview"),
    ).toBeVisible();
    await save(page, "in_chat");

    // Hex Radio, playing a chiptune station from the most played.
    await page.route("https://radio.e2e.test/**", (route) =>
      route.fulfill({
        status: 200,
        headers: {
          "content-type": "audio/wav",
          "access-control-allow-origin": "*",
        },
        body: chord(30),
      }),
    );
    await ana.chat.sendMessage("/radio");
    const radio = page.getByTestId("radio-window");
    await expect(radio).toBeVisible();
    // The most played, the list a member sees first.
    await expect(page.getByTestId("hex-radio-station")).toHaveCount(6);
    await page.getByTestId("hex-radio-station-e2e-pixel").click();
    await expect(page.getByTestId("hex-radio-status-state")).toHaveText(
      "Playing",
    );
    await page.getByTestId("hex-radio-star").click();
    await expect(page.getByTestId("hex-radio-star")).toHaveAttribute(
      "aria-pressed",
      "true",
    );
    // A moment of music, so the peaks have somewhere to fall from.
    await page.waitForTimeout(1500);
    const radioShot = await save(page, "radio");
    writeFileSync(
      path.join(OUT_DIR, "og", "radio.jpg"),
      await toCard(page, radioShot, { ...CARD, fit: "crop" }),
    );
    manifest["og/radio"] = { width: CARD.width, height: CARD.height };

    await page.getByTestId("hex-radio-equalizer-toggle").click();
    for (const [band, value] of [
      [0, 8],
      [1, 6],
      [2, 3],
      [7, 4],
      [8, 6],
      [9, 7],
    ]) {
      await page
        .getByTestId(`hex-radio-band-${band}`)
        .evaluate((el: HTMLInputElement, next) => {
          el.value = String(next);
          el.dispatchEvent(new Event("input", { bubbles: true }));
        }, value);
    }
    await page.waitForTimeout(800);
    await save(page, "radio_equalizer");

    writeFileSync(
      path.join(OUT_DIR, "manifest.json"),
      JSON.stringify(sortKeys(manifest), null, 2) + "\n",
    );
  } finally {
    await closeUsers([ana]);
  }
});

// A WAV of `seconds` of a chord that swells and fades, so every part of the
// spectrum has something in it: a bass, a fifth, and a bright arpeggio.
function chord(seconds: number): Buffer {
  const rate = 22050;
  const samples = rate * seconds;
  const data = Buffer.alloc(44 + samples * 2);
  data.write("RIFF", 0);
  data.writeUInt32LE(36 + samples * 2, 4);
  data.write("WAVEfmt ", 8);
  data.writeUInt32LE(16, 16);
  data.writeUInt16LE(1, 20);
  data.writeUInt16LE(1, 22);
  data.writeUInt32LE(rate, 24);
  data.writeUInt32LE(rate * 2, 28);
  data.writeUInt16LE(2, 32);
  data.writeUInt16LE(16, 34);
  data.write("data", 36);
  data.writeUInt32LE(samples * 2, 40);
  const notes = [110, 165, 220, 330, 440, 660, 880, 1320, 2640, 5280];
  for (let i = 0; i < samples; i++) {
    const time = i / rate;
    const swell = 0.6 + 0.4 * Math.sin(time * Math.PI * 2);
    const step = Math.floor(time * 8) % notes.length;
    let value = 0;
    notes.forEach((note, n) => {
      const loud = n === step ? 1 : 0.25 / (1 + n * 0.3);
      value += loud * Math.sin(2 * Math.PI * note * time);
    });
    const sample = Math.max(-1, Math.min(1, (value / 3) * swell));
    data.writeInt16LE(Math.round(sample * 32767), 44 + i * 2);
  }
  return data;
}

// The desktop as the member sees it, at full size and halved, recorded in the
// manifest; the full one is returned for the share card.
async function save(page: Page, name: string): Promise<Buffer> {
  // A tip that came up meanwhile is put away: it would cover the window.
  for (const tip of await page
    .locator(".toast-notification")
    .getByRole("button", { name: "Got it!" })
    .all()) {
    await tip.click().catch(() => {});
  }
  await expect(page.locator(".toast-notification")).toHaveCount(0);
  await page.mouse.move(0, 0);
  const png = await page.screenshot();
  const full = await toWebp(page, png, { quality: WEBP_QUALITY });
  const half = await toWebp(page, png, {
    quality: WEBP_QUALITY,
    maxWidth: full.width / 2,
    smooth: false,
  });
  writeFileSync(path.join(OUT_DIR, `${name}.webp`), full.webp);
  writeFileSync(path.join(OUT_DIR, `${name}-half.webp`), half.webp);
  manifest[name] = { width: full.width, height: full.height };
  return full.webp;
}

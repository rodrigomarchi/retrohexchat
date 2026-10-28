/**
 * Captures the pictures of the public pages of Hex Paint (`/paint`) and ASCII
 * Art (`/ascii-art`): each program open on the desktop with something made
 * in it, and the channel those things were posted to.
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
 * size and halved to the pixel (`-half`); each program's share card,
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

test("captures the pictures of the Hex Paint and ASCII Art pages", async ({
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

    writeFileSync(
      path.join(OUT_DIR, "manifest.json"),
      JSON.stringify(sortKeys(manifest), null, 2) + "\n",
    );
  } finally {
    await closeUsers([ana]);
  }
});

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

import { BrowserContext, expect, Page } from "@playwright/test";
import { ChatPage } from "../pages/ChatPage";

/**
 * The arcade on film: the Arcade window, and DOOM running in its own tab.
 *
 * The game is served by the public static host, not the app, so filming it
 * needs the internet. `/play/arcade/<game>` only redirects there, dropping any
 * query string; the engine reads its arguments from the query, so the tab is
 * sent straight to E1M1 instead of the title menus.
 */
const DOOM_E1M1 =
  "https://static.retrohexchat.app/arcade/doom_shareware/index.html?-warp&1&1&-skill&3";

/** The window of the Arcade's First-Person Shooters folder, where DOOM is. */
export function shootersFolder(page: Page) {
  return page.getByTestId("desktop-launcher-window-arcade-fps");
}

/**
 * Double-clicks the desktop's Arcade icon and opens its First-Person
 * Shooters folder, whose cards DOOM is among.
 */
export async function openArcade(page: Page, chat: ChatPage) {
  await chat.openArcadeFolder();
  await chat.openCategoryOf(
    chat.arcadeFolderWindow,
    "arcade-game-doom_shareware",
  );
  await expect(shootersFolder(page)).toBeVisible();
}

/** Picks DOOM's card in the open folder, so the Arcade opens on its sheet. */
export async function previewDoom(page: Page) {
  await shootersFolder(page).getByTestId("arcade-game-doom_shareware").click();
  await expect(page.getByTestId("arcade-game-preview")).toBeVisible();
}

/**
 * Presses Play and confirms the new tab, and sends that tab straight to E1M1.
 * Returns at once: the game loads while the scene goes on (`readyDoom`).
 */
export async function startDoom(
  page: Page,
  ctx: BrowserContext,
): Promise<Page> {
  await page.getByTestId("solo-game-start-doom_shareware").click();
  const popup = ctx.waitForEvent("page");
  await page.getByTestId("open-tab-confirm-open").click();
  const doom = await popup;
  await doom.goto(DOOM_E1M1);
  return doom;
}

/** The engine ignores input for a while after its data is in, setting up the map. */
const ENGINE_WARM_UP_MS = 3000;

/**
 * Waits until DOOM takes input, and scales its canvas to the window's height —
 * the game draws a small fixed canvas in a corner, too small at 1080p.
 */
export async function readyDoom(doom: Page) {
  await expect(doom.locator("#canvas")).toBeVisible({ timeout: 60_000 });
  await expect(doom.getByText(/Downloading/)).toHaveCount(0, {
    timeout: 60_000,
  });
  await doom.addStyleTag({
    content: `html, body { background: #000; margin: 0; overflow: hidden; }
      #canvas { position: fixed; inset: 0; margin: auto; height: 100vh !important;
        width: auto !important; image-rendering: pixelated; }`,
  });
  await doom.waitForTimeout(ENGINE_WARM_UP_MS);
}

/** Play, then ready: for a scene that has the time to wait on camera. */
export async function launchDoom(
  page: Page,
  ctx: BrowserContext,
): Promise<Page> {
  const doom = await startDoom(page, ctx);
  await readyDoom(doom);
  return doom;
}

/** Plays for about `ms`: walk, turn, fire, in a loop. */
export async function playDoom(doom: Page, ms: number) {
  await doom.locator("#canvas").click();
  const moves: [string, number][] = [
    ["ArrowUp", 1200],
    ["ArrowLeft", 450],
    ["Control", 250],
    ["ArrowUp", 800],
    ["ArrowRight", 600],
    ["Control", 250],
  ];
  const until = Date.now() + ms;
  for (let i = 0; Date.now() < until; i++) {
    const [key, hold] = moves[i % moves.length];
    await doom.keyboard.down(key);
    await doom.waitForTimeout(Math.min(hold, Math.max(0, until - Date.now())));
    await doom.keyboard.up(key);
  }
}

/**
 * Closes the game tab and ends the session (which closes the Arcade window),
 * so the next visit offers Play again.
 * The chat cannot see a tab on another origin: closing it leaves the session
 * "in progress", and the next pick would open on "Game in progress" with no
 * Play button.
 */
export async function closeDoom(page: Page, doom: Page) {
  await doom.close();
  await page.getByTestId("solo-session-end").click();
  // Ending the session closes the Arcade window with it.
  await expect(page.getByTestId("arcade-games-window")).toBeHidden();
}

/** Closes the Arcade window. */
export async function closeArcade(page: Page) {
  await page
    .getByTestId("arcade-games-window")
    .locator('[data-window-control="close"]')
    .click();
  await expect(page.getByTestId("arcade-games-window")).toBeHidden();
}

/**
 * Loads DOOM's 7.5 MB into the context's cache straight from the static host,
 * without an Arcade session, so Play on camera opens the game quickly.
 */
export async function warmDoom(ctx: BrowserContext) {
  const doom = await ctx.newPage();
  await doom.goto(DOOM_E1M1);
  await expect(doom.locator("#canvas")).toBeVisible({ timeout: 60_000 });
  await expect(doom.getByText(/Downloading/)).toHaveCount(0, {
    timeout: 60_000,
  });
  await doom.close();
}

/**
 * Off camera: leaves the Arcade and its folders closed, with no session in
 * progress — a session left "playing" reopens on its own state, without a
 * Play button. Picking DOOM shows that state, or DOOM's sheet when there is
 * none (a finished session starts afresh on a pick).
 */
export async function resetArcade(page: Page, chat: ChatPage) {
  const window = page.getByTestId("arcade-games-window");
  if (!(await window.isVisible())) {
    await openArcade(page, chat);
    await shootersFolder(page)
      .getByTestId("arcade-game-doom_shareware")
      .click();
    await expect(window).toBeVisible();
  }
  if (await page.getByTestId("arcade-game-preview").isVisible()) {
    await closeArcade(page);
  } else {
    // A game in progress: ending it closes the window with the session.
    await page.getByTestId("solo-session-end").click();
    await expect(window).toBeHidden();
  }
  for (const folder of [shootersFolder(page), chat.arcadeFolderWindow]) {
    if (await folder.isVisible()) {
      await folder.locator('[data-window-control="close"]').click();
      await expect(folder).toBeHidden();
    }
  }
}

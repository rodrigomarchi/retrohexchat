import {
  APIRequestContext,
  BrowserContext,
  expect,
  Locator,
  Page,
} from "@playwright/test";
import { followCard } from "../helpers/surfaceEntry";

/**
 * The Retro Games, the way a scene needs them: a seat played by the game's own
 * computer player, a game opened from its home, a match against the computer,
 * a seat offered in the game's channel and the match room it opens.
 *
 * Every step is the steps of a spec in `e2e/tests/` (game-hex-invaders,
 * game-stage, game-open-lobby, game-channels, chat-retro-games) with a camera.
 */

export { autopilot, provisionGameChannel } from "../helpers/retroGames";

/** A finished match between two people, in the ledger, for a scene filmed alone. */
export async function recordMatch(
  request: APIRequestContext,
  gameId: string,
  p1: string,
  p2: string,
  score: { p1: number; p2: number },
): Promise<void> {
  const response = await request.post("/api/e2e/game-results", {
    data: {
      game_id: gameId,
      duration_seconds: 70,
      p1,
      p2,
      payload: { score, winner: score.p1 > score.p2 ? 1 : 2 },
    },
  });
  expect(response.ok(), await response.text()).toBeTruthy();
}

/** A way of the game on its home: its row, by the mode's id. */
export function way(page: Page, wayId: string): Locator {
  return page.getByTestId(`game-way-${wayId}`);
}

/**
 * Presses a dialog-guarded door — a way's Against the computer, a card's Join —
 * and Open: the tab it opens, loaded.
 */
export async function openTab(
  page: Page,
  door: Locator,
  touch = false,
): Promise<Page> {
  if (touch) await door.tap();
  else await door.click();
  const confirm = page.getByTestId("open-tab-confirm-open");
  await expect(confirm).toBeVisible();
  const [tab] = await Promise.all([
    page.context().waitForEvent("page"),
    touch ? confirm.tap() : confirm.click(),
  ]);
  await tab.waitForLoadState("domcontentloaded");
  return tab;
}

/** A way's Against the computer, from the home: the game on its stage, in a tab of its own. */
export async function playFromHome(
  page: Page,
  wayId: string,
  options: { touch?: boolean } = {},
): Promise<Page> {
  const door = way(page, wayId).getByTestId("game-play");
  await door.scrollIntoViewIfNeeded();
  const game = await openTab(page, door, !!options.touch);
  await expect(game).toHaveURL(new RegExp(`/play/${wayId}$`));
  await expect(game.getByTestId("retro-game-start-ai")).toBeVisible({
    timeout: 15_000,
  });
  return game;
}

/** The stage's menu, over the game until the match starts. */
export const stageMenu = (game: Page) => game.getByTestId("game-stage-menu");

/** The canvas the game draws on. */
export const gameCanvas = (game: Page, wayId: string) =>
  game.getByTestId(`retro-game-canvas-${wayId}`).locator("canvas");

/** Picks how hard the computer plays and presses Play vs AI. */
export async function startAgainstComputer(
  game: Page,
  options: { difficulty?: "easy" | "normal" | "hard"; touch?: boolean } = {},
): Promise<void> {
  const press = (target: Locator) =>
    options.touch ? target.tap() : target.click();
  if (options.difficulty) {
    await press(
      game.getByTestId(`retro-game-difficulty-${options.difficulty}`),
    );
  }
  await press(game.getByTestId("retro-game-start-ai"));
  await expect(stageMenu(game)).toBeHidden();
}

/** End, from the menu over the match: the result comes up in its place. */
export async function endMatch(game: Page): Promise<void> {
  await game.getByTestId("game-stage-menu-key").click();
  await game.getByTestId("retro-game-end-match").click();
  await expect(game.getByTestId("retro-game-result")).toBeVisible();
}

/**
 * Find a partner — on a way's row of the home (`game-lfg`) or on the game's
 * line under its channel's topic (`game-channel-lfg`): the chat comes forward
 * on the game's channel with the seat's card in it. Returns the card's Join
 * address.
 */
export async function offerSeat(
  page: Page,
  door: Locator,
  nick: string,
): Promise<{ card: Locator; address: string }> {
  await door.click();
  const card = page
    .locator('[data-testid="share-message-card"]')
    .filter({ has: page.getByTestId("share-message-enter") })
    .last();
  await expect(
    page.getByText(`${nick} is looking for a partner in`).last(),
  ).toBeVisible({ timeout: 15_000 });
  await expect(card).toBeVisible();
  const address = (await card
    .getByTestId("share-message-enter")
    .getAttribute("href")) as string;
  return { card, address };
}

/** Join on a seat's card, and Open: the match room, in a tab. */
export async function enterRoom(
  page: Page,
  ctx: BrowserContext,
  address: string,
): Promise<Page> {
  const room = await followCard(page, ctx, address);
  await expect(room.getByTestId("p2p-room-game")).toBeVisible({
    timeout: 20_000,
  });
  return room;
}

/** Both players ready; the host's Start can be pressed. */
export async function bothReady(host: Page, guest: Page): Promise<void> {
  await host.getByTestId("p2p-room-ready").click();
  await guest.getByTestId("p2p-room-ready").click();
  await expect(host.getByTestId("p2p-room-start")).toBeEnabled({
    timeout: 30_000,
  });
}

/** The host presses Start: both land in the game. */
export async function startMatch(
  host: Page,
  guest: Page,
  wayId: string,
): Promise<void> {
  await host.getByTestId("p2p-room-start").click();
  for (const room of [host, guest]) {
    await expect(matchCanvas(room, wayId)).toBeVisible({ timeout: 30_000 });
  }
}

/** The canvas of a match between two people. */
export const matchCanvas = (room: Page, wayId: string) =>
  room.locator(`#lobby-game-canvas[data-game-id="${wayId}"] canvas`);

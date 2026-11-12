import {
  APIRequestContext,
  Browser,
  BrowserContext,
  expect,
  Page,
} from "@playwright/test";
import { closeUsers, newSignedInUser, TestUser } from "./chatUsers";
import { shot } from "./screenshots";
import { waitForView } from "./liveView";
import { enterViaCard, followCard } from "./surfaceEntry";

/**
 * A Retro Game played to its end with nobody at the keyboard: each seat's keys
 * pressed by the game's own computer player, the matches every game's spec
 * proves the same way — one against the computer, one between two people in
 * the game's channel.
 */

/**
 * Every game this context opens has its seat played by the game's own computer
 * player, through the seat's keys (`games/core/autopilot.js`, e2e server only).
 * Set before any game loads.
 */
export async function autopilot(
  ctx: BrowserContext,
  difficulty: "easy" | "normal" | "hard" = "hard",
): Promise<void> {
  await ctx.addInitScript((level) => {
    (window as unknown as { __rhcAutopilot: object }).__rhcAutopilot = {
      difficulty: level,
    };
  }, difficulty);
}

/**
 * The game's channel set up the way the provisioning script sets it up —
 * registered, founded by `founder`, with Scoreboard announcing in it — by a
 * match of `founder`'s against the computer in the ledger. A founder who is
 * not a player of the match under test: a player is news in the room once
 * every few minutes, and a match of theirs just before keeps the next one out.
 */
export async function provisionGameChannel(
  request: APIRequestContext,
  gameId: string,
  founder: string,
  score: { p1: number; p2: number } = { p1: 420, p2: 510 },
): Promise<void> {
  const response = await request.post("/api/e2e/game-results", {
    data: {
      game_id: gameId,
      duration_seconds: 95,
      p1: founder,
      payload: { score, winner: score.p1 > score.p2 ? 1 : 2 },
      difficulty: "normal",
    },
  });
  expect(response.ok(), await response.text()).toBeTruthy();
}

/** The game's home, at its address (`/games/hex-pong`). */
export async function openHome(user: TestUser, slug: string): Promise<void> {
  await user.page.goto(`/games/${slug}`);
  await expect(user.page.getByTestId("game-home")).toBeVisible();
  await waitForView(user.page);
}

/** A way's Against the computer, from the home: the game in a tab of its own. */
export async function playFromHome(user: TestUser, way: string): Promise<Page> {
  await user.page.bringToFront();
  await user.page
    .getByTestId(`game-way-${way}`)
    .getByTestId("game-play")
    .click();
  const [game] = await Promise.all([
    user.ctx.waitForEvent("page"),
    user.page.getByTestId("open-tab-confirm-open").click(),
  ]);
  await game.waitForLoadState("domcontentloaded");
  await expect(game).toHaveURL(new RegExp(`/play/${way}$`));
  return game;
}

/**
 * Play vs AI on a game's stage, the seat's AI at the keys: the match runs to
 * its end and the result comes up in the menu.
 */
export async function playToTheResult(
  game: Page,
  name: string,
  timeout: number,
): Promise<void> {
  const menu = game.getByTestId("game-stage-menu");
  await game.getByTestId("retro-game-start-ai").click();
  await expect(menu).toBeHidden();
  await game.waitForTimeout(8_000);
  await shot(game, `${name}-playing`);
  const result = game.getByTestId("retro-game-result");
  await expect(result).toBeVisible({ timeout });
  await expect(result.getByTestId("retro-game-verdict")).toBeVisible();
  await shot(game, `${name}-result`);
}

/**
 * Find a partner — on a way's row of the game's home, or on the game's line
 * under its channel's topic (`from: "channel"`) — puts a seat's card in the
 * game's channel; a friend already there takes the seat with Join, both are
 * ready, the match runs while somebody with no seat watches it, and Scoreboard
 * says the result in the channel with both names on its card.
 */
export async function matchInTheChannel(
  browser: Browser,
  game: {
    id: string;
    name: string;
    slug: string;
    way: string;
    /** A plausible score of this game, for the match that sets the channel up. */
    score?: { p1: number; p2: number };
  },
  name: string,
  timeout: number,
  from: "home" | "channel" = "home",
): Promise<void> {
  // Nicknames are 16 characters at most: five of the name, a role, six random.
  const nick = name.slice(0, 5);
  const host = await newSignedInUser(browser, `${nick}host`);
  const guest = await newSignedInUser(browser, `${nick}guest`);
  const regular = await newSignedInUser(browser, `${nick}reg`);
  const watcherCtx = await browser.newContext();
  try {
    await autopilot(host.ctx);
    await autopilot(guest.ctx);
    await provisionGameChannel(
      regular.page.request,
      game.id,
      regular.nick,
      game.score,
    );

    // The friend is in the channel already, where the card will land.
    await guest.page.goto(`/c/${game.slug}`);
    await guest.chat.waitUntilConnected();
    await expect(guest.page.getByTestId("game-channel-bar")).toBeVisible();

    // Find a partner takes the host to the channel, card and all.
    if (from === "home") {
      await openHome(host, game.slug);
      await host.page
        .getByTestId(`game-way-${game.way}`)
        .getByTestId("game-lfg")
        .click();
    } else {
      await host.page.goto(`/c/${game.slug}`);
      await host.chat.waitUntilConnected();
      await host.page
        .getByTestId("game-channel-bar")
        .getByTestId("game-channel-lfg")
        .click();
    }
    const seat = host.chat.messageRowByText(
      `${host.nick} is looking for a partner in ${game.name}`,
    );
    await expect(seat).toBeVisible({ timeout: 15_000 });
    await expect(host.page).toHaveURL(new RegExp(`/c/${game.slug}`));
    await shot(host.page, `${name}-seat-card`);

    const address = (await seat
      .getByTestId("share-message-enter")
      .getAttribute("href")) as string;
    // The host waits in the room their card opened; the friend's Join takes
    // the one seat left.
    const hostRoom = await followCard(host.page, host.ctx, address);
    await expect(hostRoom.getByTestId("p2p-room-game")).toBeVisible();
    const guestRoom = await enterViaCard(guest.page, guest.ctx);
    await expect(guestRoom.getByTestId("p2p-room-game")).toBeVisible();
    const token = new URL(hostRoom.url()).pathname.split("/").pop();

    await hostRoom.getByTestId("p2p-room-ready").click();
    await guestRoom.getByTestId("p2p-room-ready").click();
    await expect(hostRoom.getByTestId("p2p-room-start")).toBeEnabled({
      timeout: 30_000,
    });
    await hostRoom.getByTestId("p2p-room-start").click();
    for (const room of [hostRoom, guestRoom]) {
      await expect(
        room.locator(`#lobby-game-canvas[data-game-id="${game.way}"] canvas`),
      ).toBeVisible({ timeout: 30_000 });
    }

    // Somebody with no seat watches it live.
    const watcher = await watcherCtx.newPage();
    await watcher.goto(`/watch/${token}`);
    const canvas = watcher.getByTestId("watch-canvas");
    await expect
      .poll(async () => Number(await canvas.getAttribute("data-frames")), {
        timeout: 30_000,
      })
      .toBeGreaterThan(0);
    await hostRoom.waitForTimeout(8_000);
    await shot(hostRoom, `${name}-versus-host`);
    await shot(guestRoom, `${name}-versus-guest`);
    await shot(watcher, `${name}-versus-watched`);

    // Both seats play it out; the room's bot says how it went.
    const card = guest.page
      .locator('[data-testid^="game-result-card-"]')
      .filter({ hasText: host.nick })
      .last();
    await expect(card).toBeVisible({ timeout });
    await expect(card).toContainText(guest.nick);
    await shot(guest.page, `${name}-result-in-channel`);
  } finally {
    await watcherCtx.close();
    await closeUsers([host, guest, regular]);
  }
}

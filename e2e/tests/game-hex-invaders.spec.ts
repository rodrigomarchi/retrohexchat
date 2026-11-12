/**
 * @section N - P2P, File, Call, Game
 * @flow N94 [done] Hex Invaders' home offers its three ways — the war, Co-op and Blitz — each against the computer; Co-op opens on its stage naming 10 waves and plays with the computer beside you; Blitz names 5 waves, and a match played to its end shows the result
 * @flow N95 [done] Find a partner on Hex Invaders puts a seat's card in #hex-invaders; a friend's Join takes it, both are ready, the match runs while a third person watches it, and Scoreboard says the result in the channel
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import {
  APIRequestContext,
  BrowserContext,
  expect,
  test,
} from "@playwright/test";
import { closeUsers, newSignedInUser, TestUser } from "../helpers/chatUsers";
import { shot } from "../helpers/screenshots";
import { waitForView } from "../helpers/liveView";
import { enterViaCard, followCard } from "../helpers/surfaceEntry";

/**
 * The seat played by the game's own AI through its keys: a match that runs
 * to its end without anybody at the keyboard. Set before the game loads.
 */
async function autopilot(ctx: BrowserContext, difficulty = "hard") {
  await ctx.addInitScript((level) => {
    (window as unknown as { __rhcAutopilot: object }).__rhcAutopilot = {
      difficulty: level,
    };
  }, difficulty);
}

// A match in the ledger sets the game's room up the way the provisioning
// script does: registered, with Scoreboard announcing in it. It is a regular's,
// not a player's: a player is news in the room once every few minutes, and a
// match of theirs just before would keep the one under test out of it.
async function provisionChannel(request: APIRequestContext, p1: string) {
  const response = await request.post("/api/e2e/game-results", {
    data: {
      game_id: "hex_invaders",
      duration_seconds: 90,
      p1,
      payload: { score: { p1: 400, p2: 520 }, winner: 2 },
      difficulty: "easy",
    },
  });
  expect(response.ok(), await response.text()).toBeTruthy();
}

/** A way's Against the computer, from the home: the game in a tab of its own. */
async function playFromHome(user: TestUser, way: string) {
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

async function openHome(user: TestUser) {
  await user.page.goto("/games/hex-invaders");
  await expect(user.page.getByTestId("game-home")).toBeVisible();
  await waitForView(user.page);
}

test.describe("Hex Invaders", () => {
  test("the home's three ways, and Blitz against the computer to the end (N94)", async ({
    browser,
  }) => {
    test.setTimeout(180_000);
    const ana = await newSignedInUser(browser, "invsolo");
    try {
      await autopilot(ana.ctx);
      await openHome(ana);
      for (const way of [
        "hex_invaders",
        "hex_invaders_coop",
        "hex_invaders_blitz",
      ]) {
        await expect(ana.page.getByTestId(`game-way-${way}`)).toBeVisible();
      }
      await expect(
        ana.page.getByTestId("game-way-hex_invaders_coop"),
      ).toContainText("Defend Earth together");
      await shot(ana.page, "invaders-home-ways");

      // Co-op: the computer beside you, under the same waves.
      const coop = await playFromHome(ana, "hex_invaders_coop");
      const coopMenu = coop.getByTestId("game-stage-menu");
      await expect(coopMenu.getByTestId("retro-game-goal")).toHaveText(
        "10 waves",
      );
      await coop.getByTestId("retro-game-start-ai").click();
      await expect(coopMenu).toBeHidden();
      await coop.waitForTimeout(6_000);
      await expect(coop.getByTestId("game-stage-menu-key")).toBeVisible();
      await shot(coop, "invaders-coop-playing");
      await coop.close();

      const game = await playFromHome(ana, "hex_invaders_blitz");
      const menu = game.getByTestId("game-stage-menu");
      await expect(menu.getByTestId("retro-game-goal")).toHaveText("5 waves");
      await shot(game, "invaders-blitz-ready");

      await game.getByTestId("retro-game-start-ai").click();
      await expect(menu).toBeHidden();
      await game.waitForTimeout(10_000);
      await shot(game, "invaders-blitz-playing");

      // The seat's AI plays it out: the result comes up in the menu.
      const result = game.getByTestId("retro-game-result");
      await expect(result).toBeVisible({ timeout: 150_000 });
      await expect(result.getByTestId("retro-game-verdict")).toBeVisible();
      await shot(game, "invaders-blitz-result");
    } finally {
      await closeUsers([ana]);
    }
  });

  test("a friend takes the seat in #hex-invaders, somebody watches, Scoreboard says the result (N95)", async ({
    browser,
  }) => {
    test.setTimeout(300_000);
    const host = await newSignedInUser(browser, "invhost");
    const guest = await newSignedInUser(browser, "invguest");
    const regular = await newSignedInUser(browser, "invreg");
    const watcherCtx = await browser.newContext();
    try {
      await autopilot(host.ctx);
      await autopilot(guest.ctx);
      await provisionChannel(regular.page.request, regular.nick);

      // The friend is in the channel already, where the card will land.
      await guest.page.goto("/c/hex-invaders");
      await guest.chat.waitUntilConnected();
      await expect(guest.page.getByTestId("game-channel-bar")).toBeVisible();

      // Find a partner on the war's row takes the host to the channel, card
      // and all.
      await openHome(host);
      await host.page
        .getByTestId("game-way-hex_invaders")
        .getByTestId("game-lfg")
        .click();
      const seat = host.chat.messageRowByText(
        `${host.nick} is looking for a partner in Hex Invaders`,
      );
      await expect(seat).toBeVisible({ timeout: 15_000 });
      await expect(host.page).toHaveURL(/\/c\/hex-invaders/);
      await shot(host.page, "invaders-seat-card");

      const address = (await seat
        .getByTestId("share-message-enter")
        .getAttribute("href")) as string;
      // The host waits in the room their card opened; the friend's Join
      // takes the one seat left.
      const hostRoom = await followCard(host.page, host.ctx, address);
      await expect(hostRoom.getByTestId("p2p-room-game")).toBeVisible();
      const guestRoom = await enterViaCard(guest.page, guest.ctx);
      for (const room of [hostRoom, guestRoom]) {
        await expect(room.getByTestId("p2p-room-game")).toBeVisible();
      }
      const token = new URL(hostRoom.url()).pathname.split("/").pop();

      await hostRoom.getByTestId("p2p-room-ready").click();
      await guestRoom.getByTestId("p2p-room-ready").click();
      await expect(hostRoom.getByTestId("p2p-room-start")).toBeEnabled({
        timeout: 30_000,
      });
      await shot(hostRoom, "invaders-room-ready");
      await hostRoom.getByTestId("p2p-room-start").click();
      for (const room of [hostRoom, guestRoom]) {
        await expect(
          room.locator(
            '#lobby-game-canvas[data-game-id="hex_invaders"] canvas',
          ),
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
      await shot(hostRoom, "invaders-versus-host");
      await shot(guestRoom, "invaders-versus-guest");
      await shot(watcher, "invaders-versus-watched");

      // Both seats play it out; the room's bot says how it went.
      const card = guest.page
        .locator('[data-testid^="game-result-card-"]')
        .filter({ hasText: host.nick })
        .last();
      await expect(card).toBeVisible({ timeout: 200_000 });
      await expect(card).toContainText(guest.nick);
      await shot(guest.page, "invaders-result-in-channel");
    } finally {
      await watcherCtx.close();
      await closeUsers([host, guest, regular]);
    }
  });
});

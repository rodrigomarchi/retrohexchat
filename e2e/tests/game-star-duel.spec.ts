/**
 * @section N - P2P, File, Call, Game
 * @flow N100 [done] In two friends' private conversation, the card of their last Star Duel match opens the game's home by its name, on the You tab with that match in it; Play opens the game in a tab of its own, its stage naming First to 7, and a match against the computer played to its end shows the result
 * @flow N101 [done] Play with someone on Star Duel's stage opens a match room with one seat empty; its Share link, sent in a private message, becomes the match's card there; the friend's Join on it takes the seat, both are ready, the duel is played to the end, and its result card lands in the same conversation
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, Page, test } from "@playwright/test";
import { closeUsers, newSignedInUser } from "../helpers/chatUsers";
import { waitForView } from "../helpers/liveView";
import {
  autopilot,
  playFromHome,
  playToTheResult,
} from "../helpers/retroGames";
import { shot } from "../helpers/screenshots";
import { followCard } from "../helpers/surfaceEntry";

const GAME = "star_duel";

/** The match cards in the conversation on screen, the newest last. */
const resultCards = (page: Page) =>
  page.locator('[data-testid^="game-result-card-"]');

test.describe("Star Duel", () => {
  test("from the last match's card in a private conversation to the home, and against the computer to the end (N100)", async ({
    browser,
  }) => {
    // Two ships at hard: one and a half to three minutes to seven.
    test.setTimeout(8 * 60_000);
    const ana = await newSignedInUser(browser, "duelsolo");
    const beto = await newSignedInUser(browser, "duelfriend");
    try {
      await autopilot(ana.ctx);
      const response = await ana.page.request.post("/api/e2e/game-results", {
        data: {
          game_id: GAME,
          duration_seconds: 140,
          p1: ana.nick,
          p2: beto.nick,
          payload: { score: { p1: 5, p2: 7 }, winner: 2 },
        },
      });
      expect(response.ok(), await response.text()).toBeTruthy();

      const page = ana.page;
      await ana.chat.sendMessage(`/query ${beto.nick}`);
      const card = resultCards(page).last();
      await expect(card).toBeVisible();
      await expect(card).toContainText(`${ana.nick} 5 × 7 ${beto.nick}`);
      await shot(card, "duel-private-card");

      await card.getByTestId("game-result-home").click();
      await expect(page).toHaveURL(/\/games\/star-duel/);
      await expect(page.getByTestId("game-home")).toBeVisible();
      await waitForView(page);
      await page.getByTestId("game-home-tab-you").click();
      await expect(page.getByTestId("game-you-recent")).toContainText(
        beto.nick,
      );
      await expect(page.locator('[data-testid^="game-way-"]')).toHaveCount(1);
      await shot(page, "duel-home-you");

      await page.getByTestId("game-home-tab-play").click();
      const game = await playFromHome(ana, GAME);
      await expect(
        game.getByTestId("game-stage-menu").getByTestId("retro-game-goal"),
      ).toHaveText("First to 7");
      await game.getByTestId("retro-game-difficulty-normal").click();
      await shot(game, "duel-ready");
      await playToTheResult(game, "duel-solo", 5 * 60_000);
      await expect(game.getByTestId("retro-game-verdict")).toHaveText(
        /You won|AI won/,
      );
    } finally {
      await closeUsers([ana, beto]);
    }
  });

  test("a match link sent in a private message is taken from its card, and the duel's result lands in the same conversation (N101)", async ({
    browser,
  }) => {
    test.setTimeout(9 * 60_000);
    const host = await newSignedInUser(browser, "duelhost");
    const guest = await newSignedInUser(browser, "duelguest");
    try {
      await autopilot(host.ctx);
      await autopilot(guest.ctx);

      // The match is born on the game's own stage.
      const stage = await host.ctx.newPage();
      await stage.goto(`/play/${GAME}`);
      await expect(stage.getByTestId("play-create-match")).toBeVisible();
      await stage.getByTestId("play-create-match").click();
      await expect(stage).toHaveURL(new RegExp(`/play/${GAME}/`));
      const room = stage;
      await expect(room.getByTestId("p2p-room-game")).toBeVisible();

      await room.getByTestId("share-create").click();
      const link = await room.getByTestId("share-url").inputValue();
      expect(link).toContain("/join/");
      await room.getByTestId("share-close").click();
      await expect(room.getByTestId("share-url")).toBeHidden();

      // Sent in a private message, the link is drawn as the match it names.
      await host.page.bringToFront();
      await host.chat.sendMessage(`/query ${guest.nick}`);
      await host.chat.sendMessage(`duel? ${link}`);
      const address = new URL(link).pathname;
      const invite = host.page.getByTestId("share-message-card").last();
      await expect(invite).toBeVisible({ timeout: 15_000 });
      await expect(invite).toContainText("Star Duel");
      await shot(host.page, "duel-link-in-private");

      await guest.chat.sendMessage(`/query ${host.nick}`);
      await expect(
        guest.page.getByTestId("share-message-card").last(),
      ).toBeVisible({ timeout: 15_000 });
      const guestRoom = await followCard(
        guest.page,
        guest.ctx,
        (await guest.page
          .getByTestId("share-message-enter")
          .last()
          .getAttribute("href")) ?? address,
      );
      await expect(guestRoom.getByTestId("p2p-room-game")).toBeVisible();

      await room.getByTestId("p2p-room-ready").click();
      await guestRoom.getByTestId("p2p-room-ready").click();
      await expect(room.getByTestId("p2p-room-start")).toBeEnabled({
        timeout: 30_000,
      });
      await room.getByTestId("p2p-room-start").click();
      for (const side of [room, guestRoom]) {
        await expect(
          side.locator(`#lobby-game-canvas[data-game-id="${GAME}"] canvas`),
        ).toBeVisible({ timeout: 30_000 });
      }
      await room.waitForTimeout(8_000);
      await shot(room, "duel-versus-host");
      await shot(guestRoom, "duel-versus-guest");

      // Played to seven; the result is written into their conversation.
      const card = resultCards(guest.page)
        .filter({ hasText: host.nick })
        .last();
      await expect(card).toBeVisible({ timeout: 6 * 60_000 });
      await expect(card).toContainText(guest.nick);
      await expect(card).toContainText("7");
      await shot(guest.page, "duel-result-in-private");
    } finally {
      await closeUsers([host, guest]);
    }
  });
});

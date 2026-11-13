/**
 * @section N - P2P, File, Call, Game
 * @flow N98 [done] Start -> Games -> Retro Games -> Action -> Block Breakers opens the game's home, with its one way; Play opens the game in a tab of its own, its stage naming Clear all blocks, and a match beside the computer's paddle played to its end shows the board cleared or out of lives
 * @flow N99 [done] Find a partner on Block Breakers' home puts a seat's card in #block-breakers; a friend's Join takes it, both are ready, the pair plays one board while a third person watches it, and Scoreboard says how it ended in the channel
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, test } from "@playwright/test";
import { closeUsers, newSignedInUser } from "../helpers/chatUsers";
import {
  autopilot,
  matchInTheChannel,
  playFromHome,
  playToTheResult,
} from "../helpers/retroGames";
import { shot } from "../helpers/screenshots";

const GAME = {
  id: "block_breakers",
  name: "Block Breakers",
  slug: "block-breakers",
  way: "block_breakers",
  // A pair scores the same: the board's points are theirs together.
  score: { p1: 1240, p2: 1240 },
};

test.describe("Block Breakers", () => {
  test("from Start to the home's one way, and beside the computer to the end (N98)", async ({
    browser,
  }) => {
    // Two paddles at hard: one to three minutes for a board.
    test.setTimeout(9 * 60_000);
    const ana = await newSignedInUser(browser, "blocksolo");
    try {
      await autopilot(ana.ctx);
      const page = ana.page;
      const action = page.getByTestId("start-menu-folder-games-action");
      const item = page.getByTestId("start-menu-item-game-block_breakers");
      await ana.chat.openStartPath(
        [
          ana.chat.startGamesSubmenuTrigger,
          ana.chat.startRetroGamesTrigger,
          action,
        ],
        item,
      );
      await item.click();
      await expect(page.getByTestId("game-home")).toBeVisible();
      await expect(page.getByTestId(`game-way-${GAME.way}`)).toBeVisible();
      await expect(page.locator('[data-testid^="game-way-"]')).toHaveCount(1);
      await shot(page, "blocks-home");

      const game = await playFromHome(ana, GAME.way);
      await expect(
        game.getByTestId("game-stage-menu").getByTestId("retro-game-goal"),
      ).toHaveText("Clear all blocks");
      // An easy game gets the strongest partner.
      await game.getByTestId("retro-game-difficulty-easy").click();
      await shot(game, "blocks-ready");
      await playToTheResult(game, "blocks-solo", 6 * 60_000);
      await expect(game.getByTestId("retro-game-verdict")).toHaveText(
        /Board cleared|Out of lives/,
      );
    } finally {
      await closeUsers([ana]);
    }
  });

  test("Find a partner on the home, a friend takes the seat, somebody watches, Scoreboard says how it ended (N99)", async ({
    browser,
  }) => {
    test.setTimeout(10 * 60_000);
    await matchInTheChannel(browser, GAME, "blocks", 7 * 60_000);
  });
});

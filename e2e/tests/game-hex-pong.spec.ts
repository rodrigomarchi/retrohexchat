/**
 * @section N - P2P, File, Call, Game
 * @flow N96 [done] In #hex-pong, the game's name on its line under the topic opens Hex Pong's home, with its one way; Play on the same line opens the game in a tab of its own, its stage naming First to 11, and a match against the computer played to its end shows the result
 * @flow N97 [done] Find a partner on the game's line under #hex-pong's topic puts a seat's card in the channel; a friend's Join takes it, both are ready, the match runs while a third person watches it, and Scoreboard says the result in the channel
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, test } from "@playwright/test";
import { closeUsers, newSignedInUser } from "../helpers/chatUsers";
import {
  autopilot,
  matchInTheChannel,
  playToTheResult,
} from "../helpers/retroGames";
import { shot } from "../helpers/screenshots";

const GAME = {
  id: "hex_pong",
  name: "Hex Pong",
  slug: "hex-pong",
  way: "hex_pong",
  score: { p1: 9, p2: 11 },
};

test.describe("Hex Pong", () => {
  test("from #hex-pong's game line: the home's one way, and against the computer to the end (N96)", async ({
    browser,
  }) => {
    // Two computer players at eleven by two: four to eight minutes, twelve at worst.
    test.setTimeout(16 * 60_000);
    const ana = await newSignedInUser(browser, "pongsolo");
    try {
      await autopilot(ana.ctx);
      await ana.page.goto(`/c/${GAME.slug}`);
      await ana.chat.waitUntilConnected();
      const line = ana.page.getByTestId("game-channel-bar");
      await line.getByTestId("game-channel-home").click();
      await expect(ana.page.getByTestId("game-home")).toBeVisible();
      await expect(ana.page).toHaveURL(/\/games\/hex-pong/);
      await expect(ana.page.getByTestId(`game-way-${GAME.way}`)).toBeVisible();
      await expect(ana.page.locator('[data-testid^="game-way-"]')).toHaveCount(
        1,
      );
      await shot(ana.page, "pong-home");

      // Back in the channel, the line's Play: the game in a tab of its own.
      await ana.page.goto(`/c/${GAME.slug}`);
      await ana.chat.waitUntilConnected();
      await line.getByTestId("game-channel-play").click();
      const [game] = await Promise.all([
        ana.ctx.waitForEvent("page"),
        ana.page.getByTestId("open-tab-confirm-open").click(),
      ]);
      await expect(game).toHaveURL(/\/play\/hex_pong$/);
      await expect(
        game.getByTestId("game-stage-menu").getByTestId("retro-game-goal"),
      ).toHaveText("First to 11");
      await shot(game, "pong-ready");
      // The seat's AI plays it out: the result comes up in the menu.
      await playToTheResult(game, "pong-solo", 14 * 60_000);
    } finally {
      await closeUsers([ana]);
    }
  });

  test("Find a partner under #hex-pong's topic, a friend takes the seat, somebody watches, Scoreboard says the result (N97)", async ({
    browser,
  }) => {
    test.setTimeout(17 * 60_000);
    await matchInTheChannel(browser, GAME, "pong", 14 * 60_000, "channel");
  });
});

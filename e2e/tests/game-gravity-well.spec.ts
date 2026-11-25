/**
 * @section N - P2P, File, Call, Game
 * @flow N102 [done] In #gravity-well, the game's name on its line under the topic opens Gravity Well's home, with its one way; Play opens the game in a tab of its own, its stage naming First to 7, and a match against the computer at Hard, played round the star, ends with the result
 * @flow N103 [done] Find a partner on the game's line under #gravity-well's topic puts a seat's card in the channel; a friend's Join takes it and both are ready; somebody in the channel finds the match live under the topic and watches it in a tab of its own, the host's menu over the match says 1 watching, and Scoreboard says the result in the channel
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
  id: "gravity_well",
  name: "Gravity Well",
  slug: "gravity-well",
  way: "gravity_well",
  score: { p1: 5, p2: 7 },
};

test.describe("Gravity Well", () => {
  test("from #gravity-well's game line: the home's one way, and against the computer at Hard to the end (N102)", async ({
    browser,
  }) => {
    // Two ships at hard round the star: about a minute and a half to seven,
    // two and a half at worst.
    test.setTimeout(8 * 60_000);
    const ana = await newSignedInUser(browser, "wellsolo");
    try {
      await autopilot(ana.ctx);
      await ana.page.goto(`/c/${GAME.slug}`);
      await ana.chat.waitUntilConnected();
      const line = ana.page.getByTestId("game-channel-bar");
      await line.getByTestId("game-channel-home").click();
      await expect(ana.page.getByTestId("game-home")).toBeVisible();
      await expect(ana.page).toHaveURL(/\/games\/gravity-well/);
      await expect(ana.page.getByTestId(`game-way-${GAME.way}`)).toBeVisible();
      await expect(ana.page.locator('[data-testid^="game-way-"]')).toHaveCount(
        1,
      );
      await shot(ana.page, "well-home");

      await ana.page.goto(`/c/${GAME.slug}`);
      await ana.chat.waitUntilConnected();
      await line.getByTestId("game-channel-play").click();
      const [game] = await Promise.all([
        ana.ctx.waitForEvent("page"),
        ana.page.getByTestId("open-tab-confirm-open").click(),
      ]);
      await expect(game).toHaveURL(/\/play\/gravity_well$/);
      await expect(
        game.getByTestId("game-stage-menu").getByTestId("retro-game-goal"),
      ).toHaveText("First to 7");
      await game.getByTestId("retro-game-difficulty-hard").click();
      await shot(game, "well-ready");
      await playToTheResult(game, "well-solo", 5 * 60_000);
      await expect(game.getByTestId("retro-game-verdict")).toHaveText(
        /You won|AI won/,
      );
    } finally {
      await closeUsers([ana]);
    }
  });

  test("Find a partner under #gravity-well's topic, a friend takes the seat, the channel watches from under the topic, Scoreboard says the result (N103)", async ({
    browser,
  }) => {
    test.setTimeout(9 * 60_000);
    await matchInTheChannel(browser, GAME, "well", 6 * 60_000, "channel", {
      watchFrom: "channel",
    });
  });
});

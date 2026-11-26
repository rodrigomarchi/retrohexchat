/**
 * @section N - P2P, File, Call, Game
 * @flow N114 [done] Hex Tennis's home lists its three formats — Hex Tennis (a full set), Quick Match and Sudden Death; Play on each opens the game in a tab of its own, and against the computer at Hard each is a match under way; Quick Match is played to the result
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, test } from "@playwright/test";
import { closeUsers, newSignedInUser } from "../helpers/chatUsers";
import {
  autopilot,
  openHome,
  playFromHome,
  playToTheResult,
} from "../helpers/retroGames";
import { shot } from "../helpers/screenshots";

const SLUG = "hex-tennis";
const WAYS = ["hex_tennis", "hex_tennis_quick", "hex_tennis_sudden"];
// Two hard players: Quick Match takes one to three minutes.
const MATCH_TIMEOUT = 6 * 60_000;

test.describe("Hex Tennis", () => {
  test("the home lists three formats, each a match against the computer; Quick Match played to the result (N114)", async ({
    browser,
  }) => {
    test.setTimeout(MATCH_TIMEOUT + 4 * 60_000);
    const ana = await newSignedInUser(browser, "tennissolo");
    try {
      await autopilot(ana.ctx);
      await openHome(ana, SLUG);
      for (const id of WAYS) {
        await expect(ana.page.getByTestId(`game-way-${id}`)).toBeVisible();
      }
      await expect(ana.page.locator('[data-testid^="game-way-"]')).toHaveCount(
        WAYS.length,
      );
      await shot(ana.page, "tennis-home");

      for (const id of [WAYS[0], WAYS[2]]) {
        const game = await playFromHome(ana, id);
        await expect(
          game.getByTestId("game-stage-menu").getByTestId("retro-game-goal"),
        ).toBeVisible();
        await game.getByTestId("retro-game-difficulty-hard").click();
        await game.getByTestId("retro-game-start-ai").click();
        await expect(game.getByTestId("game-stage-menu")).toBeHidden();
        await game.waitForTimeout(12_000);
        await shot(game, `${id}-match`);
        await game.close();
        await ana.page.bringToFront();
      }

      const game = await playFromHome(ana, WAYS[1]);
      await expect(
        game.getByTestId("game-stage-menu").getByTestId("retro-game-goal"),
      ).toBeVisible();
      await shot(game, "tennis-quick-ready");
      await game.getByTestId("retro-game-difficulty-hard").click();
      await playToTheResult(game, "tennis-quick", MATCH_TIMEOUT);
    } finally {
      await closeUsers([ana]);
    }
  });
});

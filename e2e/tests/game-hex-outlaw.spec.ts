/**
 * @section N - P2P, File, Call, Game
 * @flow N112 [done] Hex Outlaw's home lists its four streets — Hex Outlaw, Ricochet, Stagecoach and No Man's Land; Play on each opens the game in a tab of its own, its menu naming the match (First to 10 · best of 3 rounds), and against the computer at Hard each street is a duel under way; on Hex Outlaw's own street the duel is played to the result
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

const SLUG = "hex-outlaw";
const WAYS = [
  "hex_outlaw",
  "hex_outlaw_ricochet",
  "hex_outlaw_stagecoach",
  "hex_outlaw_nml",
];
// Two hard gunslingers: a duel takes one to three minutes.
const DUEL_TIMEOUT = 6 * 60_000;

test.describe("Hex Outlaw", () => {
  test("the home lists four streets, each a duel against the computer; one played to the result (N112)", async ({
    browser,
  }) => {
    test.setTimeout(DUEL_TIMEOUT + 4 * 60_000);
    const ana = await newSignedInUser(browser, "outlawsolo");
    try {
      await autopilot(ana.ctx);
      await openHome(ana, SLUG);
      for (const id of WAYS) {
        await expect(ana.page.getByTestId(`game-way-${id}`)).toBeVisible();
      }
      await shot(ana.page, "outlaw-home");

      for (const id of WAYS.slice(1)) {
        const game = await playFromHome(ana, id);
        await expect(
          game.getByTestId("game-stage-menu").getByTestId("retro-game-goal"),
        ).toBeVisible();
        await game.getByTestId("retro-game-difficulty-hard").click();
        await game.getByTestId("retro-game-start-ai").click();
        await expect(game.getByTestId("game-stage-menu")).toBeHidden();
        await game.waitForTimeout(9_000);
        await shot(game, `${id}-duel`);
        await game.close();
        await ana.page.bringToFront();
      }

      const game = await playFromHome(ana, WAYS[0]);
      await expect(
        game.getByTestId("game-stage-menu").getByTestId("retro-game-goal"),
      ).toBeVisible();
      await shot(game, "outlaw-ready");
      await game.getByTestId("retro-game-difficulty-hard").click();
      await playToTheResult(game, "outlaw-solo", DUEL_TIMEOUT);
    } finally {
      await closeUsers([ana]);
    }
  });
});

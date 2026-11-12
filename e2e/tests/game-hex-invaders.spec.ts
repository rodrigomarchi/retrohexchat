/**
 * @section N - P2P, File, Call, Game
 * @flow N94 [done] Hex Invaders' home offers its three ways — the war, Co-op and Blitz — each against the computer; Co-op opens on its stage naming 10 waves and plays with the computer beside you; Blitz names 5 waves, and a match played to its end shows the result
 * @flow N95 [done] Find a partner on Hex Invaders puts a seat's card in #hex-invaders; a friend's Join takes it, both are ready, the match runs while a third person watches it, and Scoreboard says the result in the channel
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, test } from "@playwright/test";
import { closeUsers, newSignedInUser } from "../helpers/chatUsers";
import {
  autopilot,
  matchInTheChannel,
  openHome,
  playFromHome,
  playToTheResult,
} from "../helpers/retroGames";
import { shot } from "../helpers/screenshots";

test.describe("Hex Invaders", () => {
  test("the home's three ways, and Blitz against the computer to the end (N94)", async ({
    browser,
  }) => {
    test.setTimeout(180_000);
    const ana = await newSignedInUser(browser, "invsolo");
    try {
      await autopilot(ana.ctx);
      await openHome(ana, "hex-invaders");
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

      // The seat's AI plays it out: the result comes up in the menu.
      await playToTheResult(game, "invaders-blitz", 150_000);
    } finally {
      await closeUsers([ana]);
    }
  });

  test("a friend takes the seat in #hex-invaders, somebody watches, Scoreboard says the result (N95)", async ({
    browser,
  }) => {
    test.setTimeout(300_000);
    await matchInTheChannel(
      browser,
      {
        id: "hex_invaders",
        name: "Hex Invaders",
        slug: "hex-invaders",
        way: "hex_invaders",
      },
      "invaders",
      200_000,
    );
  });
});

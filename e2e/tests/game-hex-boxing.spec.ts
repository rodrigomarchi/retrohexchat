/**
 * @section N - P2P, File, Call, Game
 * @flow N93 [done] Hex Boxing against the AI: the menu names the match (best of 3 rounds); once the bell rings, Space throws a punch that winds up first — the arm draws back and the fist glows — and then strikes, while the match goes on with nothing over the ring but the corner key
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, test } from "@playwright/test";
import { closeUsers, newSignedInUser } from "../helpers/chatUsers";
import { shot } from "../helpers/screenshots";

// A punch winds up for 14 frames (about 230 ms) before it can land.
const MID_WINDUP_MS = 110;
const STRIKING_MS = 300;

test.describe("Hex Boxing against the AI", () => {
  test("a punch winds up before it strikes", async ({ browser }) => {
    const user = await newSignedInUser(browser, "boxwind");
    try {
      const game = await user.chat.openGameFromFolder("hex_boxing");
      const menu = game.getByTestId("game-stage-menu");
      await expect(menu.getByTestId("retro-game-goal")).toHaveText(
        "Best of 3 rounds",
      );

      await game.getByTestId("retro-game-start-ai").click();
      await expect(menu).toBeHidden();
      // The countdown, then FIGHT! while the boxers come out, then the bell.
      await game.waitForTimeout(6000);
      const ring = game
        .getByTestId("retro-game-canvas-hex_boxing")
        .locator("canvas");
      await expect(ring).toBeInViewport({ ratio: 1 });

      await game.keyboard.down("Space");
      await game.waitForTimeout(MID_WINDUP_MS);
      await shot(ring, "punch-winding-up");
      await game.keyboard.up("Space");
      await game.waitForTimeout(STRIKING_MS - MID_WINDUP_MS);
      await shot(ring, "punch-striking");

      await expect(menu).toBeHidden();
      await expect(game.getByTestId("game-stage-menu-key")).toBeVisible();
    } finally {
      await closeUsers([user]);
    }
  });
});

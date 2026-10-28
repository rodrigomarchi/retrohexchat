/**
 * @section N - P2P, File, Call, Game
 * @flow N75 [done] A game played alone (Hex Jungle): its home offers Play and nothing that needs somebody else — no partner, match link, invitation or Live tab; a run ended with End from the menu is written down, in the player's own record and among the best runs
 * @flow N76 [done] In the channel of a game played alone, the strip offers Play without Find a partner, and /lfg says the game is played alone
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, test } from "@playwright/test";
import { closeUsers, newSignedInUser } from "../helpers/chatUsers";
import { shot } from "../helpers/screenshots";
import { waitForView } from "../helpers/liveView";

test.describe("a game played alone", () => {
  test("is played alone, and its run is written down", async ({ browser }) => {
    const user = await newSignedInUser(browser, "jungle");
    try {
      const home = await user.chat.openGameHomeFromFolder("hex_jungle");
      for (const testid of [
        "game-lfg",
        "game-match-link",
        "game-invite",
        "game-home-tab-live",
      ]) {
        await expect(home.getByTestId(testid)).toHaveCount(0);
      }
      await shot(home, "hex-jungle-home");

      const game = await user.chat.openGameFromFolder("hex_jungle");
      await waitForView(game);
      await expect(game.getByTestId("retro-game-difficulty-panel")).toHaveCount(
        0,
      );
      await game.getByTestId("retro-game-start-ai").click();
      await expect(game.getByTestId("game-stage-menu-key")).toBeVisible();

      // Run right into the jungle for a few seconds, then stop and look.
      await game.getByTestId("retro-game-canvas-hex_jungle").click();
      await game.keyboard.down("ArrowRight");
      await game.waitForTimeout(2500);
      await game.keyboard.up("ArrowRight");
      await game.waitForTimeout(1500);
      await shot(
        game.getByTestId("retro-game-canvas-hex_jungle"),
        "hex-jungle-playing",
      );

      // End is in the menu, over the match it holds.

      await game.getByTestId("game-stage-menu-key").click();

      await game.getByTestId("retro-game-end-match").click();
      const result = game.getByTestId("retro-game-result");
      await expect(result).toContainText("points");
      await expect(result.getByTestId("retro-game-ended-early")).toBeVisible();
      await expect(result.getByTestId("retro-game-recorded")).toBeVisible();
      await shot(result, "hex-jungle-result");

      await user.page.getByTestId("game-home-tab-ranking").click();
      await expect(user.page.getByTestId("game-community-best")).toBeVisible();
      await shot(
        user.page.getByTestId("game-home-ranking"),
        "hex-jungle-ranking",
      );

      // The ranking keeps the five best of everybody; the run is the player's own.
      await user.page.getByTestId("game-home-tab-you").click();
      await expect(user.page.getByTestId("game-you-totals")).toContainText(
        /\d/,
      );
      await expect(user.page.getByTestId("game-you-recent")).toContainText(
        user.nick,
      );
    } finally {
      await closeUsers([user]);
    }
  });

  test("its channel has no partner to find", async ({ browser }) => {
    const user = await newSignedInUser(browser, "junglech");
    try {
      await user.page.goto("/c/hex-jungle");
      await user.chat.waitUntilConnected();
      await expect(user.page.getByTestId("game-channel-play")).toBeVisible();
      await expect(user.page.getByTestId("game-channel-lfg")).toHaveCount(0);

      await user.chat.sendMessage("/lfg");
      await expect(
        user.page
          .getByTestId("chat-message-list")
          .getByText("Hex Jungle is a game for one player."),
      ).toBeVisible();
      await shot(
        user.page.getByTestId("game-channel-bar"),
        "hex-jungle-channel-strip",
      );
    } finally {
      await closeUsers([user]);
    }
  });
});

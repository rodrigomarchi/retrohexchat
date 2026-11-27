/**
 * @section N - P2P, File, Call, Game
 * @flow N121 [done] Pixel Tanks' home has its one way; Play opens the game in a tab of its own, its menu naming Best of 3 rounds, and a match against the computer at Hard, the player's own tank driven by the seat's AI, is played to its result
 * @flow N122 [done] Find a partner on Pixel Tanks' home puts a seat's card in #pixel-tanks; a friend's Join takes it, both are ready, the match runs with both tanks driven from their own screens while a third person watches it, and Scoreboard says the result in the channel
 * @flow N123 [done] A rematch: a Pixel Tanks match made with Find a partner and played to its end shows Final Score on both screens; the one who did not win presses Rematch on it and, the seat having been taken for this game, the second match starts on both screens in the same room with no second yes, played to its end with its own Final Score
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, Page, test } from "@playwright/test";
import { closeUsers, newSignedInUser } from "../helpers/chatUsers";
import {
  autopilot,
  matchInTheChannel,
  openHome,
  playFromHome,
  playToTheResult,
  provisionGameChannel,
  startSeatMatch,
} from "../helpers/retroGames";
import { shot } from "../helpers/screenshots";

const GAME = {
  id: "pixel_tanks",
  name: "Pixel Tanks",
  slug: "pixel-tanks",
  way: "pixel_tanks",
  score: { p1: 2, p2: 1 },
};
// Up to three rounds of two minutes on the clock, with the pauses after
// each hit: under eight minutes.
const MATCH_TIMEOUT = 9 * 60_000;

test.describe("Pixel Tanks", () => {
  test("the home's one way, and against the computer to the result (N121)", async ({
    browser,
  }) => {
    test.setTimeout(MATCH_TIMEOUT + 2 * 60_000);
    const ana = await newSignedInUser(browser, "tanksolo");
    try {
      await autopilot(ana.ctx);
      await openHome(ana, GAME.slug);
      await expect(ana.page.getByTestId(`game-way-${GAME.way}`)).toBeVisible();
      await expect(ana.page.locator('[data-testid^="game-way-"]')).toHaveCount(
        1,
      );
      await shot(ana.page, "tanks-home");
      const game = await playFromHome(ana, GAME.way);
      await expect(
        game.getByTestId("game-stage-menu").getByTestId("retro-game-goal"),
      ).toHaveText("Best of 3 rounds");
      await game.getByTestId("retro-game-difficulty-hard").click();
      await shot(game, "tanks-ready");
      await playToTheResult(game, "tanks-solo", MATCH_TIMEOUT);
    } finally {
      await closeUsers([ana]);
    }
  });

  test("Find a partner, a friend takes the seat in #pixel-tanks, somebody watches, Scoreboard says the result (N122)", async ({
    browser,
  }) => {
    test.setTimeout(MATCH_TIMEOUT + 3 * 60_000);
    await matchInTheChannel(browser, GAME, "tanks", MATCH_TIMEOUT);
  });

  test("a rematch: the one who did not win asks for another, and it is played in the same room (N123)", async ({
    browser,
  }) => {
    test.setTimeout(2 * MATCH_TIMEOUT + 3 * 60_000);
    const [pix, kes] = await Promise.all(
      ["ptpix", "ptkes"].map((name) => newSignedInUser(browser, name)),
    );
    const founder = await newSignedInUser(browser, "ptfound");
    try {
      for (const player of [pix, kes]) await autopilot(player.ctx);
      await provisionGameChannel(
        founder.page.request,
        GAME.id,
        founder.nick,
        GAME.score,
      );
      await kes.page.goto(`/c/${GAME.slug}`);
      await kes.chat.waitUntilConnected();
      await expect(kes.page.getByTestId("game-channel-bar")).toBeVisible();

      const match = await startSeatMatch(pix, kes, GAME);
      const rooms = [match.hostRoom, match.guestRoom];
      await finalScore(rooms);
      await shot(match.hostRoom, "tanks-first-final-score");

      // The one who did not win asks; on a draw, the guest does.
      const hostWon = (await outcome(match.hostRoom)) === "You win!";
      const [asker, asked] = hostWon
        ? [match.guestRoom, match.hostRoom]
        : [match.hostRoom, match.guestRoom];
      await asker.getByTestId("lobby-game-rematch").click();
      // The seat's card named this game: taking it was the yes, so the same
      // game again asks nobody.
      await expect(asked.getByTestId("lobby-game-consent")).toHaveCount(0);

      // The second match, in the same room, to its own end.
      for (const room of rooms) {
        await expect(room.getByTestId("lobby-game-result")).toBeHidden({
          timeout: 20_000,
        });
        await expect(
          room.locator(`#lobby-game-canvas[data-game-id="${GAME.way}"] canvas`),
        ).toBeVisible({ timeout: 20_000 });
      }
      await match.hostRoom.waitForTimeout(8_000);
      await shot(match.hostRoom, "tanks-rematch-playing");
      await finalScore(rooms);
      await shot(match.hostRoom, "tanks-rematch-final-score");
    } finally {
      await closeUsers([pix, kes, founder]);
    }
  });
});

/** Both rooms at the match's Final Score. */
async function finalScore(rooms: Page[]) {
  for (const room of rooms) {
    await expect(room.getByTestId("lobby-game-result")).toBeVisible({
      timeout: MATCH_TIMEOUT,
    });
  }
}

/** What the room's Final Score says of how it went for this side. */
async function outcome(room: Page): Promise<string> {
  return (
    (await room.getByTestId("lobby-game-outcome").textContent())?.trim() ?? ""
  );
}

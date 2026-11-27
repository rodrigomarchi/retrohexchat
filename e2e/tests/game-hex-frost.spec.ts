/**
 * @section N - P2P, File, Call, Game
 * @flow N130 [done] Hex Frost's home lists its three games — Hex Frost (best of five rounds), Blizzard and Peaceful; Play on each opens the game in a tab of its own, its menu naming the game, and against the computer at Hard each is a round under way
 * @flow N131 [done] Find a partner on the home's Blizzard row puts a seat's card in #hex-frost; a friend's Join takes it, both are ready, the round runs with the same ice — blocks, enemies and both igloos — on both screens while a third person watches it, and Scoreboard says the result in the channel
 * @flow N132 [done] The steal: in a Blizzard made with Find a partner, the igloos grow as each skater lands on white blocks, and a landing on the rival's block takes a piece from their igloo for one's own — one igloo up as the other goes down — until the round ends and the Final Score is on both screens
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, Page, test } from "@playwright/test";
import { closeUsers, newSignedInUser } from "../helpers/chatUsers";
import {
  autopilot,
  iceSeen,
  matchInTheChannel,
  openHome,
  playFromHome,
  provisionGameChannel,
  startSeatMatch,
} from "../helpers/retroGames";
import { shot } from "../helpers/screenshots";

const SLUG = "hex-frost";
const WAYS = ["hex_frost", "hex_frost_blizzard", "hex_frost_peaceful"];
const BLIZZARD = {
  id: "hex_frost",
  name: "Hex Frost: Blizzard",
  slug: SLUG,
  way: "hex_frost_blizzard",
  score: { p1: 1, p2: 0 },
};
// A blizzard is one round of about two minutes.
const ROUND_TIMEOUT = 6 * 60_000;

test.describe("Hex Frost", () => {
  test("the home lists three games, each a round against the computer (N130)", async ({
    browser,
  }) => {
    test.setTimeout(4 * 60_000);
    const ana = await newSignedInUser(browser, "frostsolo");
    try {
      await autopilot(ana.ctx);
      await openHome(ana, SLUG);
      for (const id of WAYS) {
        await expect(ana.page.getByTestId(`game-way-${id}`)).toBeVisible();
      }
      await expect(ana.page.locator('[data-testid^="game-way-"]')).toHaveCount(
        WAYS.length,
      );
      await shot(ana.page, "frost-home");
      for (const id of WAYS) {
        const game = await playFromHome(ana, id);
        await expect(
          game.getByTestId("game-stage-menu").getByTestId("retro-game-goal"),
        ).toBeVisible();
        await game.getByTestId("retro-game-difficulty-hard").click();
        await game.getByTestId("retro-game-start-ai").click();
        await expect(game.getByTestId("game-stage-menu")).toBeHidden();
        await game.waitForTimeout(15_000);
        await shot(game, `${id}-round`);
        await game.close();
        await ana.page.bringToFront();
      }
    } finally {
      await closeUsers([ana]);
    }
  });

  test("Find a partner on the Blizzard row, a friend takes the seat in #hex-frost, somebody watches, Scoreboard says the result (N131)", async ({
    browser,
  }) => {
    test.setTimeout(ROUND_TIMEOUT + 3 * 60_000);
    await matchInTheChannel(browser, BLIZZARD, "frost", ROUND_TIMEOUT);
  });

  test("the steal: one igloo goes up as the other goes down, until the round ends (N132)", async ({
    browser,
  }) => {
    test.setTimeout(ROUND_TIMEOUT + 3 * 60_000);
    const [pix, kes] = await Promise.all(
      ["frpix", "frkes"].map((name) => newSignedInUser(browser, name)),
    );
    const founder = await newSignedInUser(browser, "frfound");
    try {
      for (const player of [pix, kes]) await autopilot(player.ctx);
      await provisionGameChannel(
        founder.page.request,
        BLIZZARD.id,
        founder.nick,
        BLIZZARD.score,
      );
      await kes.page.goto(`/c/${SLUG}`);
      await kes.chat.waitUntilConnected();
      await expect(kes.page.getByTestId("game-channel-bar")).toBeVisible();

      const round = await startSeatMatch(pix, kes, BLIZZARD);
      await round.hostRoom.waitForTimeout(8_000);
      await shot(round.hostRoom, "frost-building");

      // A steal: between two looks, one igloo gained as the other lost.
      await expect
        .poll(() => stealBetweenLooks(round.hostRoom), {
          timeout: 2 * 60_000,
          intervals: [0],
        })
        .toBe(true);
      await shot(round.hostRoom, "frost-after-a-steal");

      for (const room of [round.hostRoom, round.guestRoom]) {
        await expect(room.getByTestId("lobby-game-result")).toBeVisible({
          timeout: ROUND_TIMEOUT,
        });
      }
      await shot(round.hostRoom, "frost-final-score");
    } finally {
      await closeUsers([pix, kes, founder]);
    }
  });
});

/** Whether, between two looks a moment apart, one igloo gained while the other lost. */
async function stealBetweenLooks(room: Page): Promise<boolean> {
  const before = await iceSeen(room);
  await room.waitForTimeout(120);
  const after = await iceSeen(room);
  if (!before || !after) return false;
  const one = after.pieces1 - before.pieces1;
  const two = after.pieces2 - before.pieces2;
  return (one > 0 && two < 0) || (two > 0 && one < 0);
}

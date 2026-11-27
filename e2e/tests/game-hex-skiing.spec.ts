/**
 * @section N - P2P, File, Call, Game
 * @flow N127 [done] Hex Skiing's home lists its three descents — Hex Skiing (best of three runs), Escape and Clean Run; Play on each opens the game in a tab of its own, its menu naming the descent, and against the computer at Hard each is a descent under way
 * @flow N128 [done] Find a partner on the home's Escape row puts a seat's card in #hex-skiing; a friend's Join takes it, both are ready, the descent runs with the same slope — trees, rocks and gates — on both screens while a third person watches it, and Scoreboard says the result in the channel
 * @flow N129 [done] The avalanche: an Escape made with Find a partner runs past the point where the slope grows thicker; the avalanche, slower than the skiers at first, speeds up until its front comes into view behind them, and swallows them, the Final Score on both screens
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
  provisionGameChannel,
  slopeSeen,
  startSeatMatch,
} from "../helpers/retroGames";
import { shot } from "../helpers/screenshots";

const SLUG = "hex-skiing";
const WAYS = ["hex_skiing", "hex_skiing_escape", "hex_skiing_clean"];
const ESCAPE = {
  id: "hex_skiing",
  name: "Hex Skiing: Escape",
  slug: SLUG,
  way: "hex_skiing_escape",
  score: { p1: 1, p2: 0 },
};
// An escape lasts two to three minutes before the avalanche catches it.
const DESCENT_TIMEOUT = 6 * 60_000;

test.describe("Hex Skiing", () => {
  test("the home lists three descents, each a descent against the computer (N127)", async ({
    browser,
  }) => {
    test.setTimeout(4 * 60_000);
    const ana = await newSignedInUser(browser, "skisolo");
    try {
      await autopilot(ana.ctx);
      await openHome(ana, SLUG);
      for (const id of WAYS) {
        await expect(ana.page.getByTestId(`game-way-${id}`)).toBeVisible();
      }
      await expect(ana.page.locator('[data-testid^="game-way-"]')).toHaveCount(
        WAYS.length,
      );
      await shot(ana.page, "skiing-home");
      for (const id of WAYS) {
        const game = await playFromHome(ana, id);
        await expect(
          game.getByTestId("game-stage-menu").getByTestId("retro-game-goal"),
        ).toBeVisible();
        await game.getByTestId("retro-game-difficulty-hard").click();
        await game.getByTestId("retro-game-start-ai").click();
        await expect(game.getByTestId("game-stage-menu")).toBeHidden();
        await game.waitForTimeout(15_000);
        await shot(game, `${id}-descent`);
        await game.close();
        await ana.page.bringToFront();
      }
    } finally {
      await closeUsers([ana]);
    }
  });

  test("Find a partner on the Escape row, a friend takes the seat in #hex-skiing, somebody watches, Scoreboard says the result (N128)", async ({
    browser,
  }) => {
    test.setTimeout(DESCENT_TIMEOUT + 3 * 60_000);
    await matchInTheChannel(browser, ESCAPE, "skiing", DESCENT_TIMEOUT);
  });

  test("the avalanche closes in on an escape until it swallows both skiers (N129)", async ({
    browser,
  }) => {
    test.setTimeout(DESCENT_TIMEOUT + 3 * 60_000);
    const [pix, kes] = await Promise.all(
      ["skpix", "skkes"].map((name) => newSignedInUser(browser, name)),
    );
    const founder = await newSignedInUser(browser, "skfound");
    try {
      for (const player of [pix, kes]) await autopilot(player.ctx);
      await provisionGameChannel(
        founder.page.request,
        ESCAPE.id,
        founder.nick,
        ESCAPE.score,
      );
      await kes.page.goto(`/c/${SLUG}`);
      await kes.chat.waitUntilConnected();
      await expect(kes.page.getByTestId("game-channel-bar")).toBeVisible();

      const escape = await startSeatMatch(pix, kes, ESCAPE);
      const rooms = [escape.hostRoom, escape.guestRoom];
      const seen = () => slopeSeen(escape.hostRoom);
      await escape.hostRoom.waitForTimeout(10_000);
      await shot(escape.hostRoom, "skiing-escape-early");

      // Past the stretch where the slope grows thicker, while still running.
      await expect
        .poll(async () => (await seen())?.distance ?? 0, {
          timeout: 3 * 60_000,
        })
        .toBeGreaterThanOrEqual(18_000);
      await shot(escape.hostRoom, "skiing-escape-thicker");

      // Faster each quarter minute, the avalanche's front comes into view.
      await expect
        .poll(async () => (await seen())?.avalancheY ?? -1_000, {
          timeout: 3 * 60_000,
        })
        .toBeGreaterThan(0);
      await shot(escape.hostRoom, "skiing-escape-front-in-view");

      // And at last it swallows them: the Final Score on both screens.
      for (const room of rooms) {
        await expect(room.getByTestId("lobby-game-result")).toBeVisible({
          timeout: DESCENT_TIMEOUT,
        });
      }
      await shot(escape.hostRoom, "skiing-escape-final-score");
    } finally {
      await closeUsers([pix, kes, founder]);
    }
  });
});

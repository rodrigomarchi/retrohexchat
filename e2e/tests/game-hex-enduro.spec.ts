/**
 * @section N - P2P, File, Call, Game
 * @flow N124 [done] Hex Enduro's home lists its three races — Hex Enduro (three days), Night Race and Sprint; Play on each opens the game in a tab of its own, its menu naming the race, and against the computer at Hard each is a race under way
 * @flow N125 [done] Find a partner on the home's Sprint row puts a seat's card in #hex-enduro; a friend's Join takes it, both are ready, the race runs with both cars driven from their own screens while a third person watches it, and Scoreboard says the result in the channel
 * @flow N126 [done] A double header: a Sprint made with Find a partner is raced to its Final Score; in the same session the host goes Back to games, proposes Night Race from the session's games, the friend is asked — "wants to play" — and accepts, and the night race is run in the same room to its own Final Score
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
  provisionGameChannel,
  startSeatMatch,
} from "../helpers/retroGames";
import { shot } from "../helpers/screenshots";

const SLUG = "hex-enduro";
const WAYS = ["hex_enduro", "hex_enduro_night", "hex_enduro_sprint"];
const SPRINT = {
  id: "hex_enduro",
  name: "Hex Enduro: Sprint",
  slug: SLUG,
  way: "hex_enduro_sprint",
  score: { p1: 40, p2: 31 },
};
// A Sprint is ninety seconds on the clock, after its countdown.
const RACE_TIMEOUT = 3 * 60_000;
// A Night Race is three minutes.
const NIGHT_TIMEOUT = 5 * 60_000;

test.describe("Hex Enduro", () => {
  test("the home lists three races, each a race against the computer (N124)", async ({
    browser,
  }) => {
    test.setTimeout(4 * 60_000);
    const ana = await newSignedInUser(browser, "endurosolo");
    try {
      await autopilot(ana.ctx);
      await openHome(ana, SLUG);
      for (const id of WAYS) {
        await expect(ana.page.getByTestId(`game-way-${id}`)).toBeVisible();
      }
      await expect(ana.page.locator('[data-testid^="game-way-"]')).toHaveCount(
        WAYS.length,
      );
      await shot(ana.page, "enduro-home");
      for (const id of WAYS) {
        const game = await playFromHome(ana, id);
        await expect(
          game.getByTestId("game-stage-menu").getByTestId("retro-game-goal"),
        ).toBeVisible();
        await shot(game, `${id}-menu`);
        await game.getByTestId("retro-game-difficulty-hard").click();
        await game.getByTestId("retro-game-start-ai").click();
        await expect(game.getByTestId("game-stage-menu")).toBeHidden();
        await game.waitForTimeout(15_000);
        await shot(game, `${id}-race`);
        await game.close();
        await ana.page.bringToFront();
      }
    } finally {
      await closeUsers([ana]);
    }
  });

  test("Find a partner on the Sprint row, a friend takes the seat in #hex-enduro, somebody watches, Scoreboard says the result (N125)", async ({
    browser,
  }) => {
    test.setTimeout(RACE_TIMEOUT + 3 * 60_000);
    await matchInTheChannel(browser, SPRINT, "enduro", RACE_TIMEOUT);
  });

  test("a double header: a Sprint, then a Night Race proposed and accepted in the same session (N126)", async ({
    browser,
  }) => {
    test.setTimeout(RACE_TIMEOUT + NIGHT_TIMEOUT + 3 * 60_000);
    const [pix, kes] = await Promise.all(
      ["enpix", "enkes"].map((name) => newSignedInUser(browser, name)),
    );
    const founder = await newSignedInUser(browser, "enfound");
    try {
      for (const player of [pix, kes]) await autopilot(player.ctx);
      await provisionGameChannel(
        founder.page.request,
        SPRINT.id,
        founder.nick,
        SPRINT.score,
      );
      await kes.page.goto(`/c/${SLUG}`);
      await kes.chat.waitUntilConnected();
      await expect(kes.page.getByTestId("game-channel-bar")).toBeVisible();

      const sprint = await startSeatMatch(pix, kes, SPRINT);
      const rooms = [sprint.hostRoom, sprint.guestRoom];
      await finalScore(rooms, RACE_TIMEOUT);
      await shot(sprint.hostRoom, "enduro-sprint-final-score");

      // Back to the session's games; another race asks the friend first.
      await sprint.hostRoom.getByTestId("lobby-game-back").click();
      const night = sprint.hostRoom.getByTestId("lobby-game-hex_enduro_night");
      await expect(night).toBeVisible({ timeout: 15_000 });
      await shot(sprint.hostRoom, "enduro-session-games");
      await night.click();
      const consent = sprint.guestRoom.getByTestId("lobby-game-consent");
      await expect(consent).toBeVisible({ timeout: 15_000 });
      await expect(consent).toContainText("wants to play");
      await expect(consent).toContainText("Night Race");
      await shot(sprint.guestRoom, "enduro-night-asked");
      await consent.getByTestId("lobby-game-accept").click();

      for (const room of rooms) {
        await expect(
          room.locator(
            '#lobby-game-canvas[data-game-id="hex_enduro_night"] canvas',
          ),
        ).toBeVisible({ timeout: 20_000 });
      }
      await sprint.hostRoom.waitForTimeout(10_000);
      await shot(sprint.hostRoom, "enduro-night-racing");
      await finalScore(rooms, NIGHT_TIMEOUT);
      await shot(sprint.hostRoom, "enduro-night-final-score");
    } finally {
      await closeUsers([pix, kes, founder]);
    }
  });
});

/** Both rooms at the race's Final Score. */
async function finalScore(rooms: Page[], timeout: number) {
  for (const room of rooms) {
    await expect(room.getByTestId("lobby-game-result")).toBeVisible({
      timeout,
    });
  }
}

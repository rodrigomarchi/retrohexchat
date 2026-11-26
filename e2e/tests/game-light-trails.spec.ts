/**
 * @section N - P2P, File, Call, Game
 * @flow N118 [done] Light Trails' home has its one way; Play opens the game in a tab of its own, its menu naming First to 3 games, and a match against the computer at Hard, the player's own cycle steered by the seat's AI, is played to its result
 * @flow N119 [done] Find a partner on Light Trails' home puts a seat's card in #light-trails; a friend's Join takes it, both are ready, the match runs with both cycles steered from their own screens while a third person watches it, and Scoreboard says the result in the channel
 * @flow N120 [done] From the stands: while two friends play Light Trails, a third finds their match under #light-trails' topic and in the Live tab of the game's home, and watches it from there in a tab of its own — Live, one watching, both players named — to the end, where the watch page gives the score; its "Play Light Trails yourself" leads to the home, where the watcher's Find a partner is taken by the match's winner, and the loser, from the channel, watches that match, its players told one is watching
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, Locator, Page, test } from "@playwright/test";
import { closeUsers, newSignedInUser, TestUser } from "../helpers/chatUsers";
import { waitForView } from "../helpers/liveView";
import {
  autopilot,
  finishSeatMatch,
  matchInTheChannel,
  openHome,
  playFromHome,
  playToTheResult,
  provisionGameChannel,
  startSeatMatch,
  watchFromTheChannel,
} from "../helpers/retroGames";
import { shot } from "../helpers/screenshots";

const GAME = {
  id: "light_trails",
  name: "Light Trails",
  slug: "light-trails",
  way: "light_trails",
  score: { p1: 3, p2: 1 },
};
// Two hard cycles, first to three rounds: under two and a half minutes.
const MATCH_TIMEOUT = 5 * 60_000;

test.describe("Light Trails", () => {
  test("the home's one way, and against the computer to the result (N118)", async ({
    browser,
  }) => {
    test.setTimeout(MATCH_TIMEOUT + 2 * 60_000);
    const ana = await newSignedInUser(browser, "trailsolo");
    try {
      await autopilot(ana.ctx);
      await openHome(ana, GAME.slug);
      await expect(ana.page.getByTestId(`game-way-${GAME.way}`)).toBeVisible();
      await expect(ana.page.locator('[data-testid^="game-way-"]')).toHaveCount(
        1,
      );
      await shot(ana.page, "trails-home");
      const game = await playFromHome(ana, GAME.way);
      await expect(
        game.getByTestId("game-stage-menu").getByTestId("retro-game-goal"),
      ).toHaveText("First to 3 games");
      await game.getByTestId("retro-game-difficulty-hard").click();
      await shot(game, "trails-ready");
      await playToTheResult(game, "trails-solo", MATCH_TIMEOUT);
    } finally {
      await closeUsers([ana]);
    }
  });

  test("Find a partner, a friend takes the seat in #light-trails, somebody watches, Scoreboard says the result (N119)", async ({
    browser,
  }) => {
    test.setTimeout(MATCH_TIMEOUT + 3 * 60_000);
    await matchInTheChannel(browser, GAME, "trails", MATCH_TIMEOUT);
  });

  test("from the stands: a match found live, watched to the end, then the watcher's own match watched (N120)", async ({
    browser,
  }) => {
    test.setTimeout(2 * MATCH_TIMEOUT + 4 * 60_000);
    const [pix, kes, nov] = await Promise.all(
      ["ltpix", "ltkes", "ltnov"].map((name) => newSignedInUser(browser, name)),
    );
    const founder = await newSignedInUser(browser, "ltfound");
    try {
      for (const player of [pix, kes, nov]) await autopilot(player.ctx);
      await provisionGameChannel(
        founder.page.request,
        GAME.id,
        founder.nick,
        GAME.score,
      );
      for (const friend of [kes, nov]) await inTheChannel(friend);

      // Two friends play; the third finds the match where the game's people are.
      const first = await startSeatMatch(kes, nov, GAME);
      await inTheChannel(pix);
      await expect(
        liveLink(pix.page.getByTestId("game-channel-bar"), first.token),
      ).toBeVisible({
        timeout: 15_000,
      });
      await shot(pix.page, "trails-live-under-the-topic");
      await openHome(pix, GAME.slug);
      await waitForView(pix.page);
      await pix.page.getByTestId("game-home-tab-live").click();
      const listed = liveLink(
        pix.page.getByTestId("game-community-live"),
        first.token,
      );
      await expect(listed).toBeVisible();
      await shot(pix.page, "trails-live-tab");

      // Watched from the Live tab, in a tab of its own.
      const watch = await openInATab(pix, listed);
      await expect(watch).toHaveURL(new RegExp(`/watch/${first.token}$`));
      await framesArrive(watch);
      await expect(watch.getByTestId("watch-status")).toHaveText("Live");
      await expect(watch.getByTestId("watch-watchers")).toHaveText(
        "1 watching",
      );
      await expect(watch.getByTestId("watch-window")).toContainText(kes.nick);
      await expect(watch.getByTestId("watch-window")).toContainText(nov.nick);
      await watch.waitForTimeout(5_000);
      await shot(watch, "trails-watching");

      // To the end: the watch page gives the score.
      await expect(watch.getByTestId("watch-result")).toBeVisible({
        timeout: MATCH_TIMEOUT,
      });
      await expect(watch.getByTestId("watch-result")).toContainText(kes.nick);
      await shot(watch, "trails-watched-to-the-end");
      const { winner, loser } = await finishSeatMatch(
        first,
        "trails-first",
        MATCH_TIMEOUT,
      );

      // The watcher's turn, from the watch page to the home.
      await watch.getByTestId("watch-play").click();
      await expect(watch).toHaveURL(/\/games\/light-trails/);
      await expect(watch.getByTestId("game-home")).toBeVisible();
      await watch.close();
      await inTheChannel(winner);
      await inTheChannel(loser);
      const second = await startSeatMatch(pix, winner, GAME);

      // Now the one who lost watches, from the channel; the players are told.
      const stands = await watchFromTheChannel(loser, GAME.slug, second.token);
      await expect(stands.getByTestId("watch-watchers")).toHaveText(
        "1 watching",
      );
      await second.hostRoom.getByTestId("game-stage-menu-key").click();
      await expect(
        second.hostRoom.getByTestId("lobby-game-watchers"),
      ).toContainText("1 watching", { timeout: 15_000 });
      await shot(second.hostRoom, "trails-pixel-told-of-the-watcher");
      await second.hostRoom.getByTestId("lobby-game-resume").click();
      await shot(stands, "trails-loser-watching");
      await finishSeatMatch(second, "trails-second", MATCH_TIMEOUT);
    } finally {
      await closeUsers([pix, kes, nov, founder]);
    }
  });
});

/** In the game's channel at its own address, the session restored. */
async function inTheChannel(who: TestUser) {
  await who.page.goto(`/c/${GAME.slug}`);
  await who.chat.waitUntilConnected();
  await expect(who.page.getByTestId("game-channel-bar")).toBeVisible();
}

/** The link to the match `token` inside `where`. */
const liveLink = (where: Locator, token: string) =>
  where.locator(`[data-testid="live-match-link"][data-token="${token}"]`);

/** A link that asks before it opens a tab of its own, followed there. */
async function openInATab(who: TestUser, link: Locator): Promise<Page> {
  await link.click();
  const [tab] = await Promise.all([
    who.ctx.waitForEvent("page"),
    who.page.getByTestId("open-tab-confirm-open").click(),
  ]);
  return tab;
}

/** A watch page once the host's frames reach it. */
async function framesArrive(watch: Page) {
  const canvas = watch.getByTestId("watch-canvas");
  await expect
    .poll(async () => Number(await canvas.getAttribute("data-frames")), {
      timeout: 30_000,
    })
    .toBeGreaterThan(0);
}

/**
 * @section N - P2P, File, Call, Game
 * @flow N93 [done] Hex Boxing against the AI: the menu names the match (best of 3 rounds); once the bell rings, Space throws a punch that winds up first — the arm draws back and the fist glows — and then strikes, while the match goes on with nothing over the ring but the corner key
 * @flow N110 [done] Hex Boxing's home has its one way; Play opens the game in a tab of its own, its menu naming the match (Best of 3 rounds), and a fight against the computer at Hard is boxed to the result
 * @flow N111 [done] A fight between friends, round by round: Find a partner on Hex Boxing's home puts a seat's card in #hex-boxing, a friend already there takes it with Join, both are ready, the host starts; round one ends with one boxer a round up on both screens and round two begins, the fight goes on until a boxer has two rounds, the result shows in both rooms, and Scoreboard says it in the channel with both names
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, Page, test } from "@playwright/test";
import { closeUsers, newSignedInUser } from "../helpers/chatUsers";
import {
  autopilot,
  matchSeen,
  openHome,
  playFromHome,
  playToTheResult,
  provisionGameChannel,
} from "../helpers/retroGames";
import { shot } from "../helpers/screenshots";
import { enterViaCard, followCard } from "../helpers/surfaceEntry";

const GAME = "hex_boxing";
const SLUG = "hex-boxing";

// A punch winds up for 14 frames (about 230 ms) before it can land.
const MID_WINDUP_MS = 110;
const STRIKING_MS = 300;

// Two hard boxers: a round is a knockout inside a minute, a fight two or three.
const FIGHT_TIMEOUT = 6 * 60_000;

/** Waits until the match on `room` has reached `round`; returns what it saw. */
async function untilRound(room: Page, round: number) {
  await expect
    .poll(async () => (await matchSeen(room))?.round ?? 0, {
      timeout: FIGHT_TIMEOUT,
      intervals: [250],
    })
    .toBeGreaterThanOrEqual(round);
  return (await matchSeen(room))!;
}

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

  test("the home's one way, and against the computer at Hard a fight is boxed to the result (N110)", async ({
    browser,
  }) => {
    test.setTimeout(FIGHT_TIMEOUT + 2 * 60_000);
    const ana = await newSignedInUser(browser, "boxsolo");
    try {
      await autopilot(ana.ctx);
      await openHome(ana, SLUG);
      await expect(ana.page.getByTestId(`game-way-${GAME}`)).toBeVisible();
      await expect(ana.page.locator('[data-testid^="game-way-"]')).toHaveCount(
        1,
      );
      await shot(ana.page, "boxing-home");
      const game = await playFromHome(ana, GAME);
      await expect(
        game.getByTestId("game-stage-menu").getByTestId("retro-game-goal"),
      ).toHaveText("Best of 3 rounds");
      await game.getByTestId("retro-game-difficulty-hard").click();
      await playToTheResult(game, "boxing-solo", FIGHT_TIMEOUT);
    } finally {
      await closeUsers([ana]);
    }
  });
});

test.describe("Hex Boxing between friends", () => {
  test("round by round: a round won shows on both screens, the next begins, two rounds win the fight, Scoreboard says it (N111)", async ({
    browser,
  }) => {
    test.setTimeout(FIGHT_TIMEOUT + 3 * 60_000);
    const host = await newSignedInUser(browser, "boxhost");
    const guest = await newSignedInUser(browser, "boxguest");
    const regular = await newSignedInUser(browser, "boxreg");
    try {
      await autopilot(host.ctx);
      await autopilot(guest.ctx);
      await provisionGameChannel(regular.page.request, GAME, regular.nick, {
        p1: 2,
        p2: 1,
      });

      // The friend is in the channel already, where the card will land.
      await guest.page.goto(`/c/${SLUG}`);
      await guest.chat.waitUntilConnected();
      await expect(guest.page.getByTestId("game-channel-bar")).toBeVisible();

      await openHome(host, SLUG);
      await host.page
        .getByTestId(`game-way-${GAME}`)
        .getByTestId("game-lfg")
        .click();
      const seat = host.chat.messageRowByText(
        `${host.nick} is looking for a partner in Hex Boxing`,
      );
      await expect(seat).toBeVisible({ timeout: 15_000 });
      const address = (await seat
        .getByTestId("share-message-enter")
        .getAttribute("href")) as string;
      const hostRoom = await followCard(host.page, host.ctx, address);
      const guestRoom = await enterViaCard(guest.page, guest.ctx);

      await hostRoom.getByTestId("p2p-room-ready").click();
      await guestRoom.getByTestId("p2p-room-ready").click();
      await expect(hostRoom.getByTestId("p2p-room-start")).toBeEnabled({
        timeout: 30_000,
      });
      await hostRoom.getByTestId("p2p-room-start").click();
      for (const room of [hostRoom, guestRoom]) {
        await expect(
          room.locator(`#lobby-game-canvas[data-game-id="${GAME}"] canvas`),
        ).toBeVisible({ timeout: 30_000 });
      }
      await expect.poll(async () => (await matchSeen(hostRoom))?.round).toBe(1);
      await hostRoom.waitForTimeout(8_000);
      await shot(hostRoom, "round-one-host");

      // Round one over: one boxer a round up, on both screens, and round two on.
      const second = await untilRound(hostRoom, 2);
      expect(second.roundWins1 + second.roundWins2).toBe(1);
      const guestSees = await untilRound(guestRoom, 2);
      expect([guestSees.roundWins1, guestSees.roundWins2]).toEqual([
        second.roundWins1,
        second.roundWins2,
      ]);
      await shot(guestRoom, "round-two-guest");

      // Two rounds win it: the result in both rooms, and in the channel.
      for (const room of [hostRoom, guestRoom]) {
        await expect(room.getByTestId("lobby-game-result")).toBeVisible({
          timeout: FIGHT_TIMEOUT,
        });
      }
      // The final score is the rounds won: one side has the two it took.
      await expect(hostRoom.getByTestId("lobby-game-result")).toContainText(
        /P1 2\b|\b2 P2/,
      );
      await shot(hostRoom, "decision-host");
      const card = guest.page
        .locator('[data-testid^="game-result-card-"]')
        .filter({ hasText: host.nick })
        .last();
      await expect(card).toBeVisible({ timeout: 30_000 });
      await expect(card).toContainText(guest.nick);
      await shot(guest.page, "boxing-result-in-channel");
    } finally {
      await closeUsers([host, guest, regular]);
    }
  });
});

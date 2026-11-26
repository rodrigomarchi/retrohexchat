/**
 * @section N - P2P, File, Call, Game
 * @flow N113 [done] A duel by invitation on Ricochet: from Hex Outlaw's home a friend is invited by nickname with Ricochet picked under Play with somebody you know; the invitation lands in their private conversation as that street's match, both enter it, both are ready, the host starts, the duel of bank shots is played to its end and its result card lands in the same conversation
 * @flow N112 [done] Hex Outlaw's home lists its four streets — Hex Outlaw, Ricochet, Stagecoach and No Man's Land; Play on each opens the game in a tab of its own, its menu naming the match (First to 10 · best of 3 rounds), and against the computer at Hard each street is a duel under way; on Hex Outlaw's own street the duel is played to the result
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, test } from "@playwright/test";
import { closeUsers, newSignedInUser } from "../helpers/chatUsers";
import {
  closeP2PUsers,
  enterP2PSession,
  newP2PUser,
} from "../helpers/p2pFlows";
import {
  autopilot,
  openHome,
  playFromHome,
  playToTheResult,
  provisionGameChannel,
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

  test("a duel by invitation on Ricochet, played to its result card in the conversation (N113)", async ({
    browser,
  }) => {
    test.setTimeout(DUEL_TIMEOUT + 4 * 60_000);
    const host = await newP2PUser(browser, "olhost", { media: true });
    const guest = await newP2PUser(browser, "olguest", { media: true });
    const founder = await newSignedInUser(browser, "olfound");
    try {
      await autopilot(host.ctx);
      await autopilot(guest.ctx);
      await provisionGameChannel(
        founder.page.request,
        "hex_outlaw",
        founder.nick,
        {
          p1: 2,
          p2: 1,
        },
      );
      await guest.chat.sendMessage(`/query ${host.nick}`);
      const cards = guest.page.getByTestId("share-message-enter");
      const before = await cards.count();

      await openHome(host, SLUG);
      const invite = host.page.getByTestId("game-invite");
      await invite
        .locator('select[name="game"]')
        .selectOption("hex_outlaw_ricochet");
      await invite.getByTestId("game-challenge-nickname").fill(guest.nick);
      await shot(invite, "outlaw-invite-ricochet");
      await invite.getByTestId("game-challenge").click();

      const hostRoom = await enterP2PSession(host);
      await expect(hostRoom.getByTestId("p2p-room-game")).toContainText(
        "Hex Outlaw: Ricochet",
      );
      await expect(cards).toHaveCount(before + 1, { timeout: 15_000 });
      const guestRoom = await enterP2PSession(guest);
      await expect(guestRoom.getByTestId("p2p-room-game")).toContainText(
        "Hex Outlaw: Ricochet",
      );

      await hostRoom.getByTestId("p2p-room-ready").click();
      await guestRoom.getByTestId("p2p-room-ready").click();
      await expect(hostRoom.getByTestId("p2p-room-start")).toBeEnabled({
        timeout: 30_000,
      });
      await hostRoom.getByTestId("p2p-room-start").click();
      for (const room of [hostRoom, guestRoom]) {
        await expect(
          room.locator(
            '#lobby-game-canvas[data-game-id="hex_outlaw_ricochet"] canvas',
          ),
        ).toBeVisible({ timeout: 30_000 });
      }
      await hostRoom.waitForTimeout(10_000);
      await shot(hostRoom, "outlaw-ricochet-host");
      await shot(guestRoom, "outlaw-ricochet-guest");

      for (const room of [hostRoom, guestRoom]) {
        await expect(room.getByTestId("lobby-game-result")).toBeVisible({
          timeout: DUEL_TIMEOUT,
        });
      }
      const card = guest.page
        .locator('[data-testid^="game-result-card-"]')
        .filter({ hasText: host.nick });
      await expect(card).toHaveCount(1, { timeout: 30_000 });
      await expect(card).toContainText(guest.nick);
      await shot(guest.page, "outlaw-result-in-private");
    } finally {
      await closeP2PUsers([host, guest]);
      await closeUsers([founder]);
    }
  });
});

/**
 * @section N - P2P, File, Call, Game
 * @flow N106 [done] Hex Warlords' home names its goal — Last king standing — and Play opens the game in a tab of its own; a match against the computer at Hard, where the first king hit ends it, is played to the result
 * @flow N107 [done] Play with somebody you know on Hex Warlords' home invites a friend by nickname: the invitation lands in their private conversation as the match's card, both enter Hex Warlords' match room through it, both are ready, the host starts, and the match played to its end leaves its result card in the same conversation
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

const GAME = "hex_warlords";
const SLUG = "hex-warlords";

test.describe("Hex Warlords", () => {
  test("the home names the goal, and against the computer at Hard the first king hit ends it (N106)", async ({
    browser,
  }) => {
    // One king each: against the hard computer one to nine minutes.
    test.setTimeout(14 * 60_000);
    const ana = await newSignedInUser(browser, "lordsolo");
    try {
      await autopilot(ana.ctx);
      await openHome(ana, SLUG);
      await expect(ana.page.locator('[data-testid^="game-way-"]')).toHaveCount(
        1,
      );
      await shot(ana.page, "warlords-home");
      const game = await playFromHome(ana, GAME);
      await expect(
        game.getByTestId("game-stage-menu").getByTestId("retro-game-goal"),
      ).toHaveText("Last king standing");
      await game.getByTestId("retro-game-difficulty-hard").click();
      await shot(game, "warlords-ready");
      await playToTheResult(game, "warlords-solo", 12 * 60_000);
      await expect(game.getByTestId("retro-game-verdict")).toBeVisible();
    } finally {
      await closeUsers([ana]);
    }
  });

  test("a friend invited by nickname from the home plays it in the session the invitation opens (N107)", async ({
    browser,
  }) => {
    test.setTimeout(16 * 60_000);
    const host = await newP2PUser(browser, "lordhost", { media: true });
    const guest = await newP2PUser(browser, "lordguest", { media: true });
    const founder = await newSignedInUser(browser, "lordfound");
    try {
      await autopilot(host.ctx);
      await autopilot(guest.ctx);
      // The channel as provisioning sets it up, where the command runs.
      await provisionGameChannel(founder.page.request, GAME, founder.nick, {
        p1: 0,
        p2: 1,
      });

      // Play with somebody you know: the friend's nickname, and Invite.
      await openHome(host, SLUG);
      const invite = host.page.getByTestId("game-invite");
      await invite.getByTestId("game-challenge-nickname").fill(guest.nick);
      await shot(invite, "warlords-invite-form");
      await invite.getByTestId("game-challenge").click();

      // The invitation is the match's card in their private conversation: it
      // opens Hex Warlords' room, the host's seat taken, the friend's waiting.
      const hostRoom = await enterP2PSession(host);
      await expect(hostRoom.getByTestId("p2p-room-game")).toBeVisible();
      await expect(hostRoom.getByTestId("p2p-room-game")).toContainText(
        "Hex Warlords",
      );
      await shot(host.page, "warlords-invitation-sent");

      await guest.chat.sendMessage(`/query ${host.nick}`);
      const guestRoom = await enterP2PSession(guest);
      await expect(guestRoom.getByTestId("p2p-room-game")).toBeVisible();
      await shot(guestRoom, "warlords-guest-room");

      await hostRoom.getByTestId("p2p-room-ready").click();
      await guestRoom.getByTestId("p2p-room-ready").click();
      await expect(hostRoom.getByTestId("p2p-room-start")).toBeEnabled({
        timeout: 30_000,
      });
      await hostRoom.getByTestId("p2p-room-start").click();
      for (const page of [hostRoom, guestRoom]) {
        await expect(
          page.locator(`#lobby-game-canvas[data-game-id="${GAME}"] canvas`),
        ).toBeVisible({ timeout: 30_000 });
      }
      const hostSession = hostRoom;
      await hostSession.waitForTimeout(8_000);
      await shot(hostSession, "warlords-versus-host");

      // Played to the end, the result lands in their conversation.
      const card = guest.page
        .locator('[data-testid^="game-result-card-"]')
        .filter({ hasText: host.nick })
        .last();
      await expect(card).toBeVisible({ timeout: 14 * 60_000 });
      await expect(card).toContainText(guest.nick);
      await shot(guest.page, "warlords-result-in-private");
    } finally {
      await closeP2PUsers([host, guest]);
      await closeUsers([founder]);
    }
  });
});

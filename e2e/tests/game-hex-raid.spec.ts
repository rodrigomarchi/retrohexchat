/**
 * @section N - P2P, File, Call, Game
 * @flow N108 [done] Hex Raid's home lists its three ways to fly — Hex Raid, Pacifist and Blitz — and its invitation picks one of them; Play opens the game in a tab of its own, its menu naming the goal (3 lives — top score wins), and a match against the computer at Hard is played to the result
 * @flow N109 [done] A best of three by invitation: from Hex Raid's home a friend is invited by nickname once in each way to fly — Pacifist, Blitz, then Hex Raid — each invitation lands in their private conversation as that mode's match, both enter it, both are ready, the host starts, each match played to its end leaves its result card in the same conversation, and the host ends that session before the next invitation — three cards in all
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, Page, test } from "@playwright/test";
import { closeUsers, newSignedInUser } from "../helpers/chatUsers";
import {
  closeP2PUsers,
  enterP2PSession,
  newP2PUser,
  P2PTestUser,
} from "../helpers/p2pFlows";
import {
  autopilot,
  openHome,
  playFromHome,
  playToTheResult,
  provisionGameChannel,
} from "../helpers/retroGames";
import { shot } from "../helpers/screenshots";

const GAME = "hex_raid";
const SLUG = "hex-raid";
const WAYS = ["hex_raid", "hex_raid_pacifist", "hex_raid_blitz"];

test.describe("Hex Raid", () => {
  test("the home lists three ways to fly, and against the computer at Hard a match is played to the result (N108)", async ({
    browser,
  }) => {
    test.setTimeout(8 * 60_000);
    const ana = await newSignedInUser(browser, "raidsolo");
    try {
      await autopilot(ana.ctx);
      await openHome(ana, SLUG);
      for (const id of WAYS) {
        await expect(ana.page.getByTestId(`game-way-${id}`)).toBeVisible();
      }
      await shot(ana.page, "raid-home");
      const game = await playFromHome(ana, GAME);
      await expect(
        game.getByTestId("game-stage-menu").getByTestId("retro-game-goal"),
      ).toHaveText("3 lives — top score wins");
      await game.getByTestId("retro-game-difficulty-hard").click();
      await shot(game, "raid-ready");
      await playToTheResult(game, "raid-solo", 6 * 60_000);
    } finally {
      await closeUsers([ana]);
    }
  });

  test("a best of three by invitation: one match in each way to fly, three result cards in one conversation (N109)", async ({
    browser,
  }) => {
    // Three matches between two hard jets: one to four minutes each.
    test.setTimeout(25 * 60_000);
    const host = await newP2PUser(browser, "raidhost", { media: true });
    const guest = await newP2PUser(browser, "raidguest", { media: true });
    const founder = await newSignedInUser(browser, "raidfound");
    try {
      await autopilot(host.ctx);
      await autopilot(guest.ctx);
      // The channel as provisioning sets it up, where the command runs.
      await provisionGameChannel(founder.page.request, GAME, founder.nick, {
        p1: 0,
        p2: 1,
      });
      await guest.chat.sendMessage(`/query ${host.nick}`);

      const series = [
        { way: "hex_raid_pacifist", name: "Hex Raid: Pacifist" },
        { way: "hex_raid_blitz", name: "Hex Raid: Blitz" },
        { way: "hex_raid", name: "Hex Raid" },
      ];
      for (const [index, match] of series.entries()) {
        await playOneMatch(host, guest, match, index);
      }

      // Three matches, three results, one conversation.
      await expect(resultCards(guest.page, host.nick)).toHaveCount(3);
      await shot(guest.page, "raid-series-in-private");
    } finally {
      await closeP2PUsers([host, guest]);
      await closeUsers([founder]);
    }
  });
});

const resultCards = (page: Page, rival: string) =>
  page.locator('[data-testid^="game-result-card-"]').filter({ hasText: rival });

/**
 * From the home, one way picked under Play with somebody you know and the
 * friend invited: both go in through the card in their conversation, the
 * host starts, and the match is played until its result card lands there.
 */
async function playOneMatch(
  host: P2PTestUser,
  guest: P2PTestUser,
  match: { way: string; name: string },
  played: number,
): Promise<void> {
  const cards = guest.page.getByTestId("share-message-enter");
  const before = await cards.count();
  const hostCards = host.page.getByTestId("share-message-enter");
  const hostBefore = await hostCards.count();

  await openHome(host, SLUG);
  const invite = host.page.getByTestId("game-invite");
  await invite.locator('select[name="game"]').selectOption(match.way);
  await invite.getByTestId("game-challenge-nickname").fill(guest.nick);
  await shot(invite, `raid-invite-${match.way}`);
  await invite.getByTestId("game-challenge").click();

  // The new invitation's card, under the session the last match was in.
  await expect(hostCards).toHaveCount(hostBefore + 1, { timeout: 15_000 });
  const hostRoom = await enterP2PSession(host);
  await expect(hostRoom.getByTestId("p2p-room-game")).toContainText(match.name);

  await expect(cards).toHaveCount(before + 1, { timeout: 15_000 });
  const guestRoom = await enterP2PSession(guest);
  await expect(guestRoom.getByTestId("p2p-room-game")).toContainText(
    match.name,
  );

  await hostRoom.getByTestId("p2p-room-ready").click();
  await guestRoom.getByTestId("p2p-room-ready").click();
  await expect(hostRoom.getByTestId("p2p-room-start")).toBeEnabled({
    timeout: 30_000,
  });
  await hostRoom.getByTestId("p2p-room-start").click();
  for (const room of [hostRoom, guestRoom]) {
    await expect(
      room.locator(`#lobby-game-canvas[data-game-id="${match.way}"] canvas`),
    ).toBeVisible({ timeout: 30_000 });
  }
  await hostRoom.waitForTimeout(8_000);
  await shot(hostRoom, `raid-versus-${match.way}`);

  await expect(resultCards(guest.page, host.nick)).toHaveCount(played + 1, {
    timeout: 7 * 60_000,
  });
  await shot(guest.page, `raid-result-${match.way}`);

  // The match over, the host ends the session it was played in.
  await hostRoom.getByTestId("p2p-console-end-session").click();
  await hostRoom.getByTestId("p2p-confirm-dialog-confirm").click();
  await guest.chat.expectMessageVisible("ended the P2P session");
  await hostRoom.close();
  await guestRoom.close();
  await host.page.bringToFront();
  await guest.page.bringToFront();
}

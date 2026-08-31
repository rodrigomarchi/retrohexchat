/**
 * @section N - P2P, File, Call, Game
 * @flow N45 [done] A match link minted inside a game is followed from another browser, the seat is taken and the game runs over the P2P session
 * @flow N46 [done] A third person following the same match link is told the seat is taken, and it stays taken after the match ends
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, test, type Page } from "@playwright/test";
import { ChatPage } from "../pages/ChatPage";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { shot } from "../helpers/screenshots";

/**
 * The open lobby: a match that does not know who is coming.
 *
 * Every other link in this product names a room somebody is already in. This
 * one names an empty seat, so the two things worth proving here are that
 * following it *takes* the seat and that the second person to follow it is
 * told so — the only link in the app that dies by succeeding.
 *
 * A match needs no camera, so this spec asks for no media permissions: the
 * game rides the same peer connection with nothing to send.
 */
const PASSWORD = "testpass123";
const GAME = "hex_pong";

async function connectedUser(page: Page): Promise<string> {
  const nick = uniqueNickname();
  const connect = new ConnectPage(page);
  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword(PASSWORD);
  await new ChatPage(page).waitUntilConnected();
  return nick;
}

test("a match link fills its one seat and the game runs on it (N45, N46)", async ({
  browser,
}) => {
  const hostCtx = await browser.newContext();
  const guestCtx = await browser.newContext();
  const latecomerCtx = await browser.newContext();
  const host = await hostCtx.newPage();
  const guest = await guestCtx.newPage();
  const latecomer = await latecomerCtx.newPage();

  try {
    const hostNick = await connectedUser(host);
    await connectedUser(guest);
    await connectedUser(latecomer);

    // The match is born inside the game, not beside it.
    await host.goto(`/play/${GAME}`);
    await host.getByTestId("play-create-match").click();

    await expect(host).toHaveURL(new RegExp(`/play/${GAME}/`));
    const matchUrl = host.url();
    await expect(host.getByTestId("p2p-room-game")).toBeVisible();
    await expect(host.getByTestId("p2p-room-roster")).toContainText(hostNick);
    // A game has no camera to choose: the device half of the room is gone.
    await expect(host.getByTestId("p2p-setup-preview")).toHaveCount(0);
    await shot(host, "match-room-host-empty-seat");

    // The address is minted by Share, in the room, and nowhere else.
    await host.getByTestId("share-create").click();
    const shareUrl = await host.getByTestId("share-url").inputValue();
    expect(shareUrl).toContain("/join/");
    const joinPath = new URL(shareUrl).pathname;

    // The guest follows it: the card offers the seat, then the seat is theirs.
    await guest.goto(joinPath);
    await expect(guest.getByTestId("join-card")).toBeVisible();
    await expect(guest.getByTestId("join-subject")).toContainText(
      "1 seat open",
    );
    await shot(guest, "join-card-seat-open");

    await guest.getByTestId("join-enter").click();
    await expect(guest).toHaveURL(new RegExp(`/play/${GAME}/`));
    await expect(guest.getByTestId("p2p-room-game")).toBeVisible();

    // The seat is gone the moment it is taken, and the card says so — full,
    // not expired, and without naming who took it.
    await latecomer.goto(joinPath);
    await expect(latecomer.getByTestId("join-filled")).toBeVisible();
    await expect(latecomer.getByTestId("join-card")).not.toContainText(
      "Link expired",
    );
    await shot(latecomer, "join-card-seat-taken");

    // Both ready, then the host starts. The game the link named needs no
    // second yes from either side.
    await host.getByTestId("p2p-room-ready").click();
    await guest.getByTestId("p2p-room-ready").click();

    await expect(host.getByTestId("p2p-room-start")).toBeEnabled({
      timeout: 30_000,
    });
    await host.getByTestId("p2p-room-start").click();

    // Both sides land in the game, over a connection that really came up, and
    // neither was asked to accept anything: the link was the yes.
    for (const page of [host, guest]) {
      await expect(page.getByTestId("p2p-session-console")).toBeVisible({
        timeout: 30_000,
      });
      await expect(page.getByTestId("lobby-game-consent")).toHaveCount(0);
      await expect(page.getByTestId("lobby-game-panel")).toContainText(
        "Hex Pong",
        { timeout: 30_000 },
      );
      await expect(page.locator("#lobby-game-canvas canvas")).toBeVisible({
        timeout: 30_000,
      });
      await expect(page.getByTestId("p2p-call-window")).toContainText(
        "Connected",
        { timeout: 30_000 },
      );
    }

    await shot(host, "match-running-host");

    // And the link stays dead once the match is over.
    await latecomer.goto(joinPath);
    await expect(latecomer.getByTestId("join-enter")).toHaveCount(0);
    await expect(latecomer).toHaveURL(new RegExp(joinPath));
    expect(matchUrl).toContain(`/play/${GAME}/`);
  } finally {
    await hostCtx.close();
    await guestCtx.close();
    await latecomerCtx.close();
  }
});

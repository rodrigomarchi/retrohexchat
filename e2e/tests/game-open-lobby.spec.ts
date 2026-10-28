/**
 * @section N - P2P, File, Call, Game
 * @flow N45 [done] A match link minted inside a game is followed from another browser, the seat is taken and the game runs over the P2P session
 * @flow N46 [done] A third person following the same match link is told the seat is taken, and it stays taken after the match ends
 * @flow N67 [done] Somebody with no account watches the match being played, at its /watch address, drawn live from the host's relayed frames, with nothing over it but the key that opens its menu
 * @flow N68 [done] The players see how many are watching and the watch link to hand on, in the menu over their match (which fits a phone-sized window); the match is offered to watch under its game channel's topic and on the game's page
 * @flow N77 [done] Players who take their time in a match room — reading it, pressing Ready a while after arriving — still get the game when the host presses Start
 * @flow N78 [done] When a match room ends, the window says why and that the match did not start, and offers Play again — a new room for the same game — or the game's page
 * @flow N69 [done] A full match's link, a playing nickname's menu and the game's page each lead to watching it; a member's Play on the game's page opens beside the desktop
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, test, type Page } from "@playwright/test";
import { ChatPage } from "../pages/ChatPage";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { shot } from "../helpers/screenshots";
import { waitForView } from "../helpers/liveView";

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
    const token = new URL(matchUrl).pathname.split("/").pop();
    await expect(host.getByTestId("p2p-room-game")).toBeVisible();
    await expect(host.getByTestId("p2p-room-roster")).toContainText(hostNick);
    // A game has no camera to choose: the device half of the room is gone.
    await expect(host.getByTestId("p2p-setup-preview")).toHaveCount(0);
    await shot(host, "match-room-host-empty-seat");

    // The address is minted by Share, in the room, and nowhere else. The window
    // it opens is modal, so it is closed again before the room is used —
    // exactly what the person who copied the link does next.
    await host.getByTestId("share-create").click();
    const shareUrl = await host.getByTestId("share-url").inputValue();
    expect(shareUrl).toContain("/join/");
    const joinPath = new URL(shareUrl).pathname;
    await host.getByTestId("share-close").click();
    await expect(host.getByTestId("share-url")).toBeHidden();

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
    // The seat was offered to everybody, so the late click may still watch.
    await expect(latecomer.getByTestId("join-watch")).toHaveAttribute(
      "href",
      `/watch/${token}`,
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
      await expect(
        page.locator('#lobby-game-canvas[data-game-id="hex_pong"] canvas'),
      ).toBeVisible({ timeout: 30_000 });
      await expect(page.getByTestId("p2p-call-window")).toContainText(
        "Connected",
        { timeout: 30_000 },
      );
    }

    await shot(host, "match-running-host");

    // A match offered in the open is watched in the open: no account, no
    // seat, only the game as the host plays it.
    const watcherCtx = await browser.newContext();
    const watcher = await watcherCtx.newPage();

    try {
      await watcher.goto(`/watch/${token}`);
      const canvas = watcher.getByTestId("watch-canvas");
      await expect(canvas).toBeVisible({ timeout: 30_000 });
      await expect
        .poll(async () => Number(await canvas.getAttribute("data-frames")), {
          timeout: 30_000,
        })
        .toBeGreaterThan(0);
      await expect(watcher.getByTestId("watch-status")).toHaveText("Live");
      await shot(watcher, "match-watched-without-an-account");
      // Nothing over the match but the key that opens what is said about it.
      await watcher.getByTestId("game-stage-menu-key").click();
      await expect(watcher.getByTestId("watch-resume")).toBeVisible();
      await shot(watcher, "match-watched-menu");
      await watcher.getByTestId("watch-resume").click();
      await expect(watcher.getByTestId("game-stage-menu")).toBeHidden();
      await expect(watcher.getByTestId("watch-watchers")).toHaveText(
        "1 watching",
      );

      // The players are told somebody is watching, and can hand the address
      // on, in the menu over their match.
      await host.getByTestId("game-stage-menu-key").click();
      await expect(host.getByTestId("lobby-game-watchers")).toContainText(
        "1 watching",
        { timeout: 15_000 },
      );
      await expect(host.getByTestId("lobby-game-watch-copy")).toHaveAttribute(
        "data-copy-text",
        new RegExp(`/watch/${token}$`),
      );
      await shot(host, "match-host-sees-who-watches");
      // The same menu fits a phone-sized window.
      await host.setViewportSize({ width: 390, height: 844 });
      await expect(host.getByTestId("lobby-game-end")).toBeInViewport({
        ratio: 1,
      });
      await shot(host, "match-host-menu-phone-size");
      await host.setViewportSize({ width: 1280, height: 720 });

      // Where people already are, the match is there to be found: the game's
      // channel, under its topic, and the game's own page.
      await latecomer.goto("/c/hex-pong");
      const live = latecomer
        .getByTestId("game-channel-bar")
        .locator(`[data-testid="live-match-link"][data-token="${token}"]`);
      await expect(live).toBeVisible({ timeout: 15_000 });
      await expect(live).toHaveAttribute("href", `/watch/${token}`);
      await shot(latecomer, "game-channel-live-match");

      // The host's nickname leads there too, from its menu in the channel.
      const hostChat = await hostCtx.newPage();
      await hostChat.goto("/c/hex-pong");
      await new ChatPage(hostChat).waitUntilConnected();
      await new ChatPage(latecomer).openNicklistContextMenu(hostNick);
      await expect(
        latecomer.getByTestId("context-menu-item-context_watch"),
      ).toBeVisible();
      await shot(
        latecomer.getByTestId("context-menu-nicklist-context-menu"),
        "nick-menu-watch-the-match",
      );
      await latecomer.keyboard.press("Escape");

      await latecomer.goto("/games/hex-pong");
      // The tabs switch once the page's view has joined.
      await waitForView(latecomer);
      await latecomer.getByTestId("game-home-tab-live").click();
      await expect(
        latecomer
          .getByTestId("game-community-live")
          .locator(`[data-token="${token}"]`),
      ).toBeVisible();
      await shot(latecomer, "game-home-live");
      await latecomer.getByTestId("game-home-tab-play").click();
      // A member's Play opens the game beside the desktop.
      const memberPlay = latecomer
        .getByTestId("game-way-hex_pong")
        .getByTestId("game-play");
      await expect(memberPlay).toHaveAttribute("target", "_blank");
      await shot(latecomer, "game-home-member");
    } finally {
      await watcherCtx.close();
    }

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

// People do not press Ready the instant they arrive: they read the room, wait
// for the other side, take a minute. Nothing connects before Start, so time
// spent in the room must not count against the connection — the room used to
// fail silently half a minute after the guest arrived, leaving both screens
// showing a Start that could no longer start anything.
test("a match room survives the people who take their time (N77)", async ({
  browser,
}) => {
  test.setTimeout(150_000);
  const hostCtx = await browser.newContext({
    viewport: { width: 1500, height: 900 },
  });
  const guestCtx = await browser.newContext({
    viewport: { width: 1500, height: 900 },
  });
  const host = await hostCtx.newPage();
  const guest = await guestCtx.newPage();

  try {
    await connectedUser(host);
    await connectedUser(guest);

    await host.goto(`/play/${GAME}`);
    await host.getByTestId("play-create-match").click();
    await expect(host).toHaveURL(new RegExp(`/play/${GAME}/`));
    await host.getByTestId("share-create").click();
    const joinPath = new URL(await host.getByTestId("share-url").inputValue())
      .pathname;
    await host.getByTestId("share-close").click();

    await guest.goto(joinPath);
    await guest.getByTestId("join-enter").click();
    await expect(guest).toHaveURL(new RegExp(`/play/${GAME}/`));

    // Longer than the connecting deadline, spent in the room.
    await guest.waitForTimeout(20_000);
    await guest.getByTestId("p2p-room-ready").click();
    await host.waitForTimeout(20_000);
    await host.getByTestId("p2p-room-ready").click();

    const start = host.getByTestId("p2p-room-start");
    await expect(start).toBeEnabled({ timeout: 15_000 });
    await expect(start).toBeInViewport({ ratio: 1 });
    await expect(host.getByTestId("p2p-room-roster")).not.toContainText(
      "getting ready",
    );
    await expect(guest.getByTestId("p2p-room-roster")).not.toContainText(
      "getting ready",
    );
    await shot(host, "match-room-ready-after-a-while");
    await start.click();

    for (const page of [host, guest]) {
      await expect(page.locator("#lobby-game-canvas canvas")).toBeVisible({
        timeout: 30_000,
      });
      await expect(page.getByTestId("p2p-call-window")).toContainText(
        "Connected",
        { timeout: 30_000 },
      );
    }
    await shot(guest, "match-running-after-a-while");
  } finally {
    await hostCtx.close();
    await guestCtx.close();
  }
});

// A room that ends says why in the middle of the window, not only on the
// status bar, and a match offers the way on: a new room for the same game, or
// the game's page.
test("an ended match room says why and offers to play again (N78)", async ({
  browser,
}) => {
  const hostCtx = await browser.newContext({
    viewport: { width: 1500, height: 900 },
  });
  const guestCtx = await browser.newContext({
    viewport: { width: 1500, height: 900 },
  });
  const host = await hostCtx.newPage();
  const guest = await guestCtx.newPage();

  try {
    const hostNick = await connectedUser(host);
    const guestNick = await connectedUser(guest);

    await host.goto(`/play/${GAME}`);
    await host.getByTestId("play-create-match").click();
    await expect(host).toHaveURL(new RegExp(`/play/${GAME}/`));
    const firstRoom = host.url();
    await host.getByTestId("share-create").click();
    const joinPath = new URL(await host.getByTestId("share-url").inputValue())
      .pathname;
    await host.getByTestId("share-close").click();

    await guest.goto(joinPath);
    await guest.getByTestId("join-enter").click();
    await expect(guest).toHaveURL(new RegExp(`/play/${GAME}/`));
    await expect(guest.getByTestId("p2p-room-roster")).toContainText(hostNick);

    await host.getByTestId("p2p-room-cancel").click();
    await host.getByRole("button", { name: "End session" }).click();

    const left = guest.getByTestId("p2p-left");
    await expect(left).toBeVisible();
    await expect(guest.getByTestId("p2p-left-reason")).toHaveText(
      `P2P session with ${hostNick} ended.`,
    );
    await expect(guest.getByTestId("p2p-left-detail")).toHaveText(
      "The match did not start.",
    );
    const again = guest.getByTestId("p2p-left-play-again");
    await expect(again).toBeInViewport({ ratio: 1 });
    await expect(guest.getByTestId("p2p-left-back-to-game")).toBeInViewport({
      ratio: 1,
    });
    await shot(guest, "match-ended-desktop");
    await guest.setViewportSize({ width: 390, height: 844 });
    await expect(again).toBeInViewport({ ratio: 1 });
    await shot(guest, "match-ended-phone");
    await guest.setViewportSize({ width: 1500, height: 900 });

    // Play again is a new room for the same game, with this player as its host.
    await again.click();
    await expect(guest).not.toHaveURL(firstRoom, { timeout: 15_000 });
    await expect(guest).toHaveURL(new RegExp(`/play/${GAME}/[^/?]+$`));
    await expect(guest.getByTestId("p2p-room-roster")).toContainText(
      `${guestNick} (host)`,
    );
    await expect(guest.getByTestId("p2p-room-cancel")).toBeVisible();
  } finally {
    await hostCtx.close();
    await guestCtx.close();
  }
});

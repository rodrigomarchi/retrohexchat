/**
 * @section N - P2P, File, Call, Game
 * @flow N42 [done] The P2P session at /p2p/:token carries real video both ways, and file transfer and the game share the same connection
 * @flow N43 [done] Opening the session at its own address moves it out of the chat's window, and the displaced window takes it back
 * @flow N44 [done] Closing the P2P tab does not end the session for the other side
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect, Page } from "@playwright/test";
import {
  newP2PUser,
  closeP2PUsers,
  statusBarP2P,
  sendP2PInvite,
  acceptP2PInvite,
  startP2PSession,
  remoteVideoLive,
  type P2PTestUser,
} from "../helpers/p2pFlows";

/**
 * The P2P session at an address of its own.
 *
 * `chat-p2p.spec.ts` proves the session works inside the chat. What is proved
 * here is the half the chat cannot supply: the same session, in a tab that has
 * no chat in it, carrying the three things the original integration wave called
 * a prerequisite for switching the standalone lobby off — real media both ways,
 * a file mid-call, and a game mid-call.
 */

/** Both sides in the starting room and ready, with nothing started yet. */
async function readyPair(alice: P2PTestUser, bob: P2PTestUser) {
  await sendP2PInvite(alice, bob.nick);
  await bob.chat.expectTabVisible(alice.nick);
  await bob.chat.switchToTab(alice.nick);
  await acceptP2PInvite(bob.page);
  await expect(alice.page.getByTestId("p2p-room-start")).toBeEnabled({
    timeout: 20_000,
  });
}

/** Both sides in, and the host has started. */
async function connectPair(alice: P2PTestUser, bob: P2PTestUser) {
  await readyPair(alice, bob);
  await startP2PSession(alice);

  await expect(statusBarP2P(alice.page)).toContainText(`P2P: ${bob.nick}`, {
    timeout: 20_000,
  });
}

/**
 * The session token, read off the anchor of whichever page holds the seat.
 * There is no anchor before `[Ready]`, so this is only asked after it.
 */
async function tokenFrom(page: Page) {
  const token = await page
    .getByTestId("p2p-webrtc")
    .getAttribute("data-session-token");

  expect(token).toBeTruthy();
  return token as string;
}

async function openP2PConsoleSection(
  page: Page,
  section: "call" | "files" | "games" | "stats",
) {
  await page.getByTestId(`p2p-console-nav-${section}`).click();
  await expect(
    page.getByTestId(`p2p-console-section-${section}`),
  ).toBeVisible();
}

test.describe("P2P session at its own address", () => {
  test("carries real video both ways; file and game share the connection", async ({
    browser,
  }) => {
    test.setTimeout(120_000);

    const alice = await newP2PUser(browser, "psa", { media: true });
    const bob = await newP2PUser(browser, "psb", {
      media: true,
      acceptDownloads: true,
    });

    try {
      // Both are in the starting room. Alice moves to the session's own address
      // before starting, so the whole negotiation happens there: this is the
      // shape somebody who follows a shared link arrives in.
      await readyPair(alice, bob);
      const token = await tokenFrom(alice.page);

      const tab = await alice.ctx.newPage();
      await tab.goto(`/p2p/${token}`);

      // No chat behind it: the way back is a link, and the room is the first
      // thing the address shows.
      await expect(tab.getByTestId("p2p-starting-room")).toBeVisible({
        timeout: 20_000,
      });
      await expect(tab.getByTestId("p2p-back-to-chat")).toBeVisible();

      await tab.getByTestId("p2p-room-ready").click();
      await expect(tab.getByTestId("p2p-room-start")).toBeEnabled({
        timeout: 20_000,
      });
      await tab.getByTestId("p2p-room-start").click();
      await expect(tab.getByTestId("p2p-session-console")).toBeVisible();

      // Real RTP in both directions, from the tab and from the peer's chat.
      for (const page of [tab, bob.page]) {
        await expect
          .poll(() => remoteVideoLive(page), { timeout: 30_000 })
          .toBe(true);
      }

      // A file over the SAME connection, mid-call, driven from the tab.
      await openP2PConsoleSection(tab, "files");
      await expect(tab.getByTestId("lobby-file-panel")).toBeVisible();

      const fileName = "p2p-surface-during-call.txt";
      await tab.locator("#lobby-file-input").setInputFiles({
        name: fileName,
        mimeType: "text/plain",
        buffer: Buffer.from("surface call + file payload"),
      });

      const bobFilePanel = bob.page.getByTestId("lobby-file-panel");
      await expect(bobFilePanel).toBeVisible({ timeout: 15_000 });
      await expect(bobFilePanel.getByTestId("file-transfer")).toContainText(
        fileName,
        { timeout: 15_000 },
      );
      const downloadPromise = bob.page.waitForEvent("download", {
        timeout: 20_000,
      });
      await bobFilePanel.getByTestId("file-transfer-accept").click();
      const download = await downloadPromise;
      expect(download.suggestedFilename()).toBe(fileName);

      // A game on the same connection, also from the tab.
      await openP2PConsoleSection(tab, "games");
      await expect(tab.getByTestId("lobby-game-panel")).toBeVisible();
      await tab
        .getByTestId("lobby-game-panel")
        .getByRole("button", { name: "Hex Pong" })
        .click();

      const consent = bob.page.getByTestId("lobby-game-consent");
      await expect(consent).toBeVisible({ timeout: 15_000 });
      await consent.getByRole("button", { name: "Accept" }).click();

      for (const page of [tab, bob.page]) {
        await expect(page.locator("#lobby-game-canvas canvas")).toBeVisible({
          timeout: 20_000,
        });
      }

      // The thesis: call + file + game coexist, and the video is STILL flowing
      // after everything else ran — in a tab with no chat in it.
      await expect
        .poll(() => remoteVideoLive(tab), { timeout: 15_000 })
        .toBe(true);
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test("the address moves the session, and the displaced window takes it back", async ({
    browser,
  }) => {
    test.setTimeout(90_000);

    const alice = await newP2PUser(browser, "pma", { media: true });
    const bob = await newP2PUser(browser, "pmb", { media: true });

    try {
      await readyPair(alice, bob);
      const token = await tokenFrom(alice.page);

      const tab = await alice.ctx.newPage();
      await tab.goto(`/p2p/${token}`);
      await expect(tab.getByTestId("p2p-starting-room")).toBeVisible({
        timeout: 20_000,
      });

      // One person is one participant: the chat's window says where the
      // session went rather than pretending to still hold it.
      await expect(alice.page.getByTestId("p2p-displaced")).toBeVisible({
        timeout: 20_000,
      });
      await expect(alice.page.getByTestId("p2p-webrtc")).toHaveCount(0);

      // And taking it back is a button on the window that lost it.
      await alice.page.getByTestId("p2p-reclaim").click();
      await expect(alice.page.getByTestId("p2p-displaced")).toHaveCount(0);
      await expect(tab.getByTestId("p2p-displaced")).toBeVisible({
        timeout: 20_000,
      });

      // The session itself never ended, and the seat is back in the chat.
      await expect(statusBarP2P(bob.page)).toContainText(alice.nick, {
        timeout: 20_000,
      });
      await expect(alice.page.getByTestId("p2p-room-start")).toBeVisible();
      await tab.close();
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test("closing the tab does not end the session for the other side", async ({
    browser,
  }) => {
    test.setTimeout(90_000);

    const alice = await newP2PUser(browser, "pca", { media: true });
    const bob = await newP2PUser(browser, "pcb", { media: true });

    try {
      await connectPair(alice, bob);
      const token = await tokenFrom(bob.page);

      const tab = await bob.ctx.newPage();
      await tab.goto(`/p2p/${token}`);
      await expect(tab.getByTestId("p2p-session-console")).toBeVisible({
        timeout: 20_000,
      });

      await tab.close();

      // The room decides who is in the session, not the tab. Closing it starts
      // the rejoin grace; only Leave, which asks first, is terminal — so the
      // other side keeps the session and its own window.
      // The status bar still names the peer whatever the link is doing while
      // it rebuilds; what is asserted is that the session is not over.
      await expect(statusBarP2P(alice.page)).toContainText(bob.nick, {
        timeout: 20_000,
      });
      await expect(alice.page.getByTestId("p2p-call-window")).toBeVisible();

      // And the address still resolves: it was never the tab that held it.
      const again = await bob.ctx.newPage();
      await again.goto(`/p2p/${token}`);
      await expect(again.getByTestId("p2p-denied")).toHaveCount(0);
      await expect(statusBarP2P(alice.page)).toContainText(bob.nick, {
        timeout: 20_000,
      });
      await again.close();
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });
});

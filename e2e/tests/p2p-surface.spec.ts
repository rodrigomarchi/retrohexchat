/**
 * @section N - P2P, File, Call, Game
 * @flow N42 [done] The P2P session at /p2p/:token carries real video both ways, and file transfer and the game share the same connection
 * @flow N43 [done] A second tab of the same session moves it, and the displaced tab takes it back
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
 * The P2P session at the only address it has.
 *
 * The chat has no window for a session: the card in the private message is the
 * door and it opens a tab of its own. What is proved here is that the session
 * carries everything in that tab — real media both ways, a file mid-call, and a
 * game mid-call — and what happens when the same person opens it twice.
 */

type Pair = { aliceSession: Page; bobSession: Page };

/** Both sides in the starting room and ready, with nothing started yet. */
async function readyPair(alice: P2PTestUser, bob: P2PTestUser): Promise<Pair> {
  const aliceSession = await sendP2PInvite(alice, bob.nick);
  await bob.chat.expectTabVisible(alice.nick);
  await bob.chat.switchToTab(alice.nick);
  const bobSession = await acceptP2PInvite(bob);

  await expect(aliceSession.getByTestId("p2p-room-start")).toBeEnabled({
    timeout: 20_000,
  });

  return { aliceSession, bobSession };
}

/** Both sides in, and the host has started. */
async function connectPair(
  alice: P2PTestUser,
  bob: P2PTestUser,
): Promise<Pair> {
  const pair = await readyPair(alice, bob);
  await startP2PSession(pair.aliceSession);

  await expect(statusBarP2P(alice.page)).toContainText(`P2P: ${bob.nick}`, {
    timeout: 20_000,
  });

  return pair;
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
      const { aliceSession, bobSession } = await connectPair(alice, bob);

      // No chat behind it: the way back is a link, and the chat that sent
      // everybody here is still standing in the tab it was in.
      await expect(aliceSession.getByTestId("p2p-back-to-chat")).toBeVisible();
      await expect(alice.page.getByTestId("chat-window")).toBeVisible();

      // Real RTP in both directions, in the two tabs that hold the session.
      for (const page of [aliceSession, bobSession]) {
        await expect
          .poll(() => remoteVideoLive(page), { timeout: 30_000 })
          .toBe(true);
      }

      // A file over the SAME connection, mid-call.
      await openP2PConsoleSection(aliceSession, "files");
      await expect(aliceSession.getByTestId("lobby-file-panel")).toBeVisible();

      const fileName = "p2p-surface-during-call.txt";
      await aliceSession.locator("#lobby-file-input").setInputFiles({
        name: fileName,
        mimeType: "text/plain",
        buffer: Buffer.from("surface call + file payload"),
      });

      const bobFilePanel = bobSession.getByTestId("lobby-file-panel");
      await expect(bobFilePanel).toBeVisible({ timeout: 15_000 });
      await expect(bobFilePanel.getByTestId("file-transfer")).toContainText(
        fileName,
        { timeout: 15_000 },
      );
      const downloadPromise = bobSession.waitForEvent("download", {
        timeout: 20_000,
      });
      await bobFilePanel.getByTestId("file-transfer-accept").click();
      const download = await downloadPromise;
      expect(download.suggestedFilename()).toBe(fileName);

      // A game on the same connection.
      await openP2PConsoleSection(aliceSession, "games");
      await expect(aliceSession.getByTestId("lobby-game-panel")).toBeVisible();
      await aliceSession
        .getByTestId("lobby-game-panel")
        .getByRole("button", { name: "Hex Pong" })
        .click();

      const consent = bobSession.getByTestId("lobby-game-consent");
      await expect(consent).toBeVisible({ timeout: 15_000 });
      await consent.getByRole("button", { name: "Accept" }).click();

      for (const page of [aliceSession, bobSession]) {
        await expect(page.locator("#lobby-game-canvas canvas")).toBeVisible({
          timeout: 20_000,
        });
      }

      // The thesis: call + file + game coexist, and the video is STILL flowing
      // after everything else ran — in a tab with no chat in it.
      await expect
        .poll(() => remoteVideoLive(aliceSession), { timeout: 15_000 })
        .toBe(true);
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test("a second tab moves the session, and the displaced one takes it back", async ({
    browser,
  }) => {
    test.setTimeout(90_000);

    const alice = await newP2PUser(browser, "pma", { media: true });
    const bob = await newP2PUser(browser, "pmb", { media: true });

    try {
      const { aliceSession } = await connectPair(alice, bob);
      const token = await tokenFrom(aliceSession);

      const tab = await alice.ctx.newPage();
      await tab.goto(`/p2p/${token}`);

      // One person is one participant: the page that lost the seat says where
      // the session went rather than pretending to still hold it, and the page
      // that took it is the one holding the session.
      await expect(aliceSession.getByTestId("p2p-displaced")).toBeVisible({
        timeout: 20_000,
      });
      await expect(aliceSession.getByTestId("p2p-webrtc")).toHaveCount(0);
      await expect(tab.getByTestId("p2p-webrtc")).toHaveCount(1, {
        timeout: 20_000,
      });

      // And taking it back is a button on the page that lost it.
      await aliceSession.getByTestId("p2p-reclaim").click();
      await expect(aliceSession.getByTestId("p2p-displaced")).toHaveCount(0);
      await expect(tab.getByTestId("p2p-displaced")).toBeVisible({
        timeout: 20_000,
      });

      // The session itself never ended, and the seat is back where it started.
      await expect(statusBarP2P(bob.page)).toContainText(alice.nick, {
        timeout: 20_000,
      });
      await expect(aliceSession.getByTestId("p2p-webrtc")).toHaveCount(1, {
        timeout: 20_000,
      });
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
      const { aliceSession, bobSession } = await connectPair(alice, bob);
      const token = await tokenFrom(bobSession);

      await bobSession.close();

      // The room decides who is in the session, not the tab. Closing it starts
      // the rejoin grace; only Leave, which asks first, is terminal — so the
      // other side keeps the session and its own window.
      await expect(aliceSession.getByTestId("p2p-call-window")).toBeVisible();
      await expect(statusBarP2P(alice.page)).toContainText(bob.nick, {
        timeout: 20_000,
      });

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

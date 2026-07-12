import { test, expect, Page } from "@playwright/test";
import {
  newP2PUser,
  closeP2PUsers,
  type P2PTestUser,
} from "../helpers/p2pFlows";

/**
 * In-chat P2P sessions (docs/plans/p2p-chat-integracao.md): the invite card
 * in the PM, accept/decline in place, the status-bar session area, and the
 * real WebRTC link established WITHOUT ever leaving /chat.
 */

function statusBarP2P(page: Page) {
  return page.getByTestId("status-bar-p2p");
}

function statusBarStop(page: Page) {
  return page.getByTestId("status-bar-p2p-stop");
}

async function sendP2PInvite(user: P2PTestUser, targetNick: string) {
  await user.chat.sendMessage(`/p2p ${targetNick}`);
  await expect(user.page.getByTestId("p2p-setup-accept")).toBeVisible();
  await expect(user.page.getByTestId("p2p-setup-form")).toContainText(
    "Send invite",
  );
  await user.page.getByTestId("p2p-setup-accept").click();
}

async function acceptP2PInvite(page: Page) {
  await page.getByTestId("session-card-accept").click();
  await expect(page.getByTestId("p2p-setup-accept")).toBeVisible();
  await expect(page.getByTestId("p2p-setup-preview")).toBeVisible();
  await page.getByTestId("p2p-setup-accept").click();
}

async function remoteVideoLive(page: Page) {
  return page.evaluate(() => {
    const v = document.getElementById(
      "lobby-remote-video",
    ) as HTMLVideoElement | null;
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const stream = v?.srcObject as any;
    const track = stream?.getVideoTracks?.()[0];
    return !!track && track.readyState === "live" && track.muted === false;
  });
}

async function remoteVideoIdentity(page: Page) {
  return page.evaluate(() => {
    const v = document.getElementById(
      "lobby-remote-video",
    ) as HTMLVideoElement | null;
    if (!v) return null;

    const markedVideo = v as HTMLVideoElement & { __e2eIdentity?: string };
    if (!markedVideo.__e2eIdentity) {
      markedVideo.__e2eIdentity = crypto.randomUUID();
    }

    const stream = v.srcObject as MediaStream | null;
    return {
      videoIdentity: markedVideo.__e2eIdentity,
      streamId: stream?.id || null,
    };
  });
}

test.describe("In-chat P2P session", () => {
  test("accepting the PM card connects both peers inside the chat", async ({
    browser,
  }) => {
    const alice = await newP2PUser(browser, "cpa", { media: true });
    const bob = await newP2PUser(browser, "cpb", { media: true });

    try {
      await sendP2PInvite(alice, bob.nick);
      await expect(statusBarP2P(alice.page)).toContainText("waiting for");

      // Bob accepts right on the PM card — no page navigation.
      await bob.chat.expectTabVisible(alice.nick);
      await bob.chat.switchToTab(alice.nick);
      await acceptP2PInvite(bob.page);

      // The WebRTC link comes up in place: the status bar flips to the
      // connected "P2P: <peer>" form on both sides.
      await expect(statusBarP2P(alice.page)).toContainText(`P2P: ${bob.nick}`, {
        timeout: 20_000,
      });
      await expect(statusBarP2P(bob.page)).toContainText(`P2P: ${alice.nick}`, {
        timeout: 20_000,
      });

      // The session presents itself: the Call window opens in front and the
      // call auto-starts (mic+camera) on BOTH sides; Files, Games and
      // Statistics land minimized on the taskbar.
      for (const page of [alice.page, bob.page]) {
        await expect(page.getByTestId("p2p-call-window")).toBeVisible();
        await expect(
          page.locator('[data-lobby-media-action="end-call"]'),
        ).toBeVisible({ timeout: 20_000 });

        for (const id of ["p2p-files", "p2p-games", "p2p-stats"]) {
          await expect(page.getByTestId(`${id}-window`)).toBeHidden();
          await expect(
            page.locator(`[data-window-taskbar="${id}"]`),
          ).toBeVisible();
        }
      }

      // Both PM tabs carry the session glyph, and the persisted P2P line
      // landed in the conversation.
      await expect(
        alice.page.getByTestId("tab-p2p-glyph").first(),
      ).toBeVisible();
      await alice.chat.expectMessageVisible("P2P session connected");

      // Closing ANY session window means disconnecting: the X on the Call
      // window opens the warning dialog, and confirming ends the session.
      await alice.page
        .getByTestId("p2p-call-window")
        .locator('[data-window-control="close"]')
        .click();
      await expect(alice.page.getByTestId("p2p-confirm-dialog")).toContainText(
        "disconnects the whole P2P session",
      );
      await alice.page.getByTestId("p2p-confirm-dialog-confirm").click();
      await expect(statusBarP2P(alice.page)).toBeHidden();
      await expect(statusBarP2P(bob.page)).toBeHidden({ timeout: 10_000 });
      await alice.chat.expectMessageVisible("ended the P2P session");

      // Ending closes every session window, on both sides.
      for (const page of [alice.page, bob.page]) {
        for (const id of [
          "p2p-call-window",
          "p2p-files-window",
          "p2p-games-window",
          "p2p-stats-window",
        ]) {
          await expect(page.getByTestId(id)).toBeHidden();
        }
      }
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test("the auto-started call carries real video both ways; file and game share the connection", async ({
    browser,
  }) => {
    const alice = await newP2PUser(browser, "cpg", {
      media: true,
      acceptDownloads: true,
    });
    const bob = await newP2PUser(browser, "cph", {
      media: true,
      acceptDownloads: true,
    });

    try {
      await sendP2PInvite(alice, bob.nick);
      await bob.chat.expectTabVisible(alice.nick);
      await bob.chat.switchToTab(alice.nick);
      await acceptP2PInvite(bob.page);

      await expect(statusBarP2P(alice.page)).toContainText(`P2P: ${bob.nick}`, {
        timeout: 20_000,
      });

      // The auto-started call must carry REAL RTP in both directions —
      // live, unmuted remote video tracks, not just visible elements.
      for (const page of [alice.page, bob.page]) {
        await expect
          .poll(() => remoteVideoLive(page), { timeout: 30_000 })
          .toBe(true);
      }

      // File transfer over the SAME connection, mid-call: restore the
      // minimized Files window from the taskbar and send.
      await alice.page.locator('[data-window-taskbar="p2p-files"]').click();
      await expect(alice.page.getByTestId("lobby-file-panel")).toBeVisible();
      const fileName = "chat-p2p-during-call.txt";
      await alice.page.locator("#lobby-file-input").setInputFiles({
        name: fileName,
        mimeType: "text/plain",
        buffer: Buffer.from("concurrent call + file payload"),
      });

      // The receiver's Files window surfaces on the offer; accepting
      // downloads the file for real.
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

      // The completed transfer lands as a persisted P2P line in the PM.
      await bob.chat.expectMessageVisible("File transfer completed");

      // A game joins the party on the same connection: the Games window is
      // minimized on the taskbar; restore, propose, accept, play.
      await alice.page.locator('[data-window-taskbar="p2p-games"]').click();
      await expect(alice.page.getByTestId("lobby-game-panel")).toBeVisible();
      await alice.page
        .getByTestId("lobby-game-panel")
        .getByRole("button", { name: "Hex Pong" })
        .click();

      const consent = bob.page.getByTestId("lobby-game-consent");
      await expect(consent).toBeVisible({ timeout: 15_000 });
      await consent.getByRole("button", { name: "Accept" }).click();

      for (const page of [alice.page, bob.page]) {
        await expect(page.locator("#lobby-game-canvas canvas")).toBeVisible({
          timeout: 20_000,
        });
      }

      // The thesis carries over from the lobby: call + file + game coexist —
      // the video is STILL flowing after everything else ran.
      await expect
        .poll(() => remoteVideoLive(alice.page), { timeout: 15_000 })
        .toBe(true);
      await expect(statusBarP2P(alice.page)).toContainText(`P2P: ${bob.nick}`);
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test("screen share marks the peer tile and the P2P stats video source", async ({
    browser,
  }) => {
    const alice = await newP2PUser(browser, "cpi", { media: true });
    const bob = await newP2PUser(browser, "cpj", { media: true });

    try {
      await sendP2PInvite(alice, bob.nick);
      await bob.chat.expectTabVisible(alice.nick);
      await bob.chat.switchToTab(alice.nick);
      await acceptP2PInvite(bob.page);

      await expect(statusBarP2P(alice.page)).toContainText(`P2P: ${bob.nick}`, {
        timeout: 20_000,
      });
      await expect
        .poll(() => remoteVideoLive(bob.page), { timeout: 30_000 })
        .toBe(true);

      await alice.page.getByTestId("p2p-call-screen-share").click();
      await expect(
        alice.page.getByTestId("p2p-call-local-tile"),
      ).toHaveAttribute("data-screen-share", "true");
      await expect(
        bob.page.getByTestId("p2p-call-remote-tile"),
      ).toHaveAttribute("data-peer-screen-share", "true", { timeout: 10_000 });

      await alice.page.getByTestId("p2p-call-dock-stats").click();
      const statsWindow = alice.page.getByTestId("p2p-stats-window");
      await expect(statsWindow).toBeVisible();
      await expect(statsWindow).toContainText("Source");
      await expect(statsWindow).toContainText("Screen", { timeout: 10_000 });

      await alice.page.getByTestId("p2p-call-screen-share").click();
      await expect(
        alice.page.getByTestId("p2p-call-local-tile"),
      ).toHaveAttribute("data-screen-share", "false");
      await expect(
        bob.page.getByTestId("p2p-call-remote-tile"),
      ).toHaveAttribute("data-peer-screen-share", "false", { timeout: 10_000 });
      await expect(statsWindow).toContainText("Camera", { timeout: 10_000 });
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test("mini mode, docked stats and maximize keep the P2P video alive", async ({
    browser,
  }) => {
    const alice = await newP2PUser(browser, "cpk", { media: true });
    const bob = await newP2PUser(browser, "cpl", { media: true });

    try {
      await sendP2PInvite(alice, bob.nick);
      await bob.chat.expectTabVisible(alice.nick);
      await bob.chat.switchToTab(alice.nick);
      await acceptP2PInvite(bob.page);

      await expect(statusBarP2P(alice.page)).toContainText(`P2P: ${bob.nick}`, {
        timeout: 20_000,
      });
      await expect
        .poll(() => remoteVideoLive(alice.page), { timeout: 30_000 })
        .toBe(true);

      const initialRemote = await remoteVideoIdentity(alice.page);
      expect(initialRemote?.videoIdentity).toBeTruthy();
      expect(initialRemote?.streamId).toBeTruthy();

      const callWindow = alice.page.getByTestId("p2p-call-window");
      const callPanel = alice.page.getByTestId("p2p-call-panel");

      await alice.page.getByTestId("p2p-call-mini-toggle").click();
      await expect(callPanel).toHaveAttribute("data-call-mini", "true");
      const miniBox = await callWindow.boundingBox();
      expect(miniBox).toBeTruthy();
      expect(miniBox!.width).toBeLessThanOrEqual(340);
      await expect
        .poll(() => remoteVideoIdentity(alice.page))
        .toEqual(initialRemote);

      await alice.page.getByTestId("p2p-call-mini-toggle").click();
      await expect(callPanel).toHaveAttribute("data-call-mini", "false");
      await expect
        .poll(() => remoteVideoIdentity(alice.page))
        .toEqual(initialRemote);

      await alice.page.getByTestId("p2p-call-dock-stats").click();
      const statsWindow = alice.page.getByTestId("p2p-stats-window");
      await expect(statsWindow).toBeVisible();

      const callBox = await callWindow.boundingBox();
      const statsBox = await statsWindow.boundingBox();
      expect(callBox).toBeTruthy();
      expect(statsBox).toBeTruthy();
      expect(statsBox!.x).toBeGreaterThan(callBox!.x + callBox!.width - 2);
      expect(Math.abs(statsBox!.y - callBox!.y)).toBeLessThanOrEqual(2);
      expect(Math.abs(statsBox!.height - callBox!.height)).toBeLessThanOrEqual(
        2,
      );
      await expect
        .poll(() => remoteVideoLive(alice.page), { timeout: 10_000 })
        .toBe(true);

      await callWindow.locator('[data-window-control="maximize"]').click();
      await expect(callWindow).toHaveClass(/desktop-window--maximized/);
      await expect(statsWindow).toBeVisible();
      await expect
        .poll(() => remoteVideoIdentity(alice.page))
        .toEqual(initialRemote);

      await callWindow.locator('[data-window-control="restore"]').click();
      await expect(callWindow).not.toHaveClass(/desktop-window--maximized/);
      await expect
        .poll(() => remoteVideoIdentity(alice.page))
        .toEqual(initialRemote);
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test("declining the invite tells the inviter and clears the pending state", async ({
    browser,
  }) => {
    const alice = await newP2PUser(browser, "cpc");
    const bob = await newP2PUser(browser, "cpd");

    try {
      await sendP2PInvite(alice, bob.nick);
      await expect(statusBarP2P(alice.page)).toBeVisible();

      await bob.chat.expectTabVisible(alice.nick);
      await bob.chat.switchToTab(alice.nick);
      await bob.page.getByTestId("session-card-decline").click();

      await alice.chat.expectMessageVisible("declined the P2P invite");
      await expect(statusBarP2P(alice.page)).toBeHidden();
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test("the inviter cancels a pending invite from the status bar", async ({
    browser,
  }) => {
    const alice = await newP2PUser(browser, "cpe");
    const bob = await newP2PUser(browser, "cpf");

    try {
      await sendP2PInvite(alice, bob.nick);
      await expect(statusBarP2P(alice.page)).toContainText("waiting for");

      await statusBarStop(alice.page).click();
      await expect(statusBarP2P(alice.page)).toBeHidden();
      await alice.chat.expectMessageVisible("cancelled the P2P invite");
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });
});

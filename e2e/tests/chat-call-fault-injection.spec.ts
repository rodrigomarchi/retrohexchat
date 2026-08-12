/**
 * @section N - P2P, File, Call, Game
 * @flow N34 [done] P2P stays actionable across a short LiveView outage and can end after reconnect
 * @flow N35 [done] The P2P recovery-error End button opens confirm and terminates the session
 * @flow N36 [done] A P2P answerer reloads while applying the initial offer and reconnects media
 * @flow N37 [done] Simultaneous manual P2P retries stay coordinated and recover media
 * @flow N38 [done] A conference stays actionable across a short LiveView outage and can be left after reconnect
 * @flow N39 [done] A conference participant reloads while applying the SFU offer and rejoins media
 * @flow N40 [done] Conference retry rejoins media when the participant PeerServer disappears
 * @flow N41 [done] The conference recovery-error Leave button opens confirm and exits cleanly
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { Browser, Page, expect, test } from "@playwright/test";
import { uniqueChannel } from "../helpers/chatUsers";
import { e2eURL, isLocalTarget, localOnlyReason } from "../helpers/env";
import {
  closeGroupCallUsers,
  newGroupCallUser,
} from "../helpers/groupCallUsers";
import {
  closeP2PUsers,
  newP2PUser,
  type P2PTestUser,
} from "../helpers/p2pFlows";

async function delayNextRemoteOffer(page: Page) {
  await page.evaluate(() => {
    type FaultInjectionWindow = typeof window & {
      __callOfferDelay?: {
        started: boolean;
        release?: () => void;
      };
    };

    const win = window as FaultInjectionWindow;
    const originalSetRemoteDescription =
      RTCPeerConnection.prototype.setRemoteDescription;

    win.__callOfferDelay = { started: false };

    RTCPeerConnection.prototype.setRemoteDescription = async function (
      description?: RTCSessionDescriptionInit,
    ) {
      if (!win.__callOfferDelay?.started && description?.type === "offer") {
        win.__callOfferDelay = { started: true };

        await new Promise<void>((resolve) => {
          const timeout = window.setTimeout(resolve, 10_000);
          win.__callOfferDelay!.release = () => {
            window.clearTimeout(timeout);
            resolve();
          };
        });
      }

      return (
        originalSetRemoteDescription as unknown as (
          this: RTCPeerConnection,
          description?: RTCSessionDescriptionInit,
        ) => Promise<void>
      ).call(this, description);
    };
  });
}

async function waitForDelayedRemoteOffer(page: Page) {
  await expect
    .poll(
      () =>
        page.evaluate(() => {
          type FaultInjectionWindow = typeof window & {
            __callOfferDelay?: { started: boolean };
          };

          return Boolean(
            (window as FaultInjectionWindow).__callOfferDelay?.started,
          );
        }),
      { timeout: 10_000 },
    )
    .toBe(true);
}

async function p2pRemoteVideoLive(page: Page) {
  return page.evaluate(() => {
    const video = document.getElementById(
      "lobby-remote-video",
    ) as HTMLVideoElement | null;
    const stream = video?.srcObject as MediaStream | null;
    const track = stream?.getVideoTracks()[0];

    return !!track && track.readyState === "live";
  });
}

async function groupCallRemoteVideoLive(page: Page) {
  return page.evaluate(() => {
    const videos = Array.from(
      document.querySelectorAll<HTMLVideoElement>(
        '[data-group-call-video-tile][data-local="false"] video',
      ),
    );

    return videos.some((video) => {
      const stream = video.srcObject as MediaStream | null;
      const track = stream?.getVideoTracks()[0];

      return !!track && track.readyState === "live";
    });
  });
}

async function groupCallRuntimeIds(page: Page) {
  return page.getByTestId("group-call-webrtc").evaluate((el) => {
    const token = el.getAttribute("data-group-call-token");
    const participantId = el.getAttribute("data-participant-id");

    if (!token || !participantId) {
      throw new Error("group call runtime ids are missing");
    }

    return { token, participantId };
  });
}

async function terminateGroupCallPeer(page: Page) {
  const ids = await groupCallRuntimeIds(page);
  const response = await page.request.post(
    e2eURL("/api/e2e/group-call-peer/terminate"),
    {
      data: {
        token: ids.token,
        participant_id: ids.participantId,
      },
    },
  );

  expect(response.status()).toBe(200);
  await expect(response).toBeOK();

  return ids;
}

async function sendP2PInvite(user: P2PTestUser, targetNick: string) {
  await user.chat.sendMessage(`/p2p ${targetNick}`);
  await expect(user.page.getByTestId("p2p-setup-accept")).toBeVisible();
  await user.page.getByTestId("p2p-setup-accept").click();
  await expect(user.page.getByTestId("p2p-call-window")).toBeVisible();
  await expect(user.page.getByTestId("p2p-session-console")).toBeVisible();
}

async function acceptP2PInvite(page: Page) {
  await expect(page.getByTestId("p2p-peer-entry")).toHaveAttribute(
    "data-p2p-state",
    "pending",
  );
  await page.getByTestId("p2p-peer-join").click();
  await expect(page.getByTestId("p2p-setup-accept")).toBeVisible();
  await page.getByTestId("p2p-setup-accept").click();
}

async function establishP2P(browser: Browser) {
  const alice = await newP2PUser(browser, "fiap", { media: true });
  const bob = await newP2PUser(browser, "fibp", { media: true });

  await sendP2PInvite(alice, bob.nick);
  await bob.chat.expectTabVisible(alice.nick);
  await bob.chat.switchToTab(alice.nick);
  await acceptP2PInvite(bob.page);

  await expect(alice.page.getByTestId("status-bar-p2p")).toContainText(
    `P2P: ${bob.nick}`,
    { timeout: 20_000 },
  );
  await expect(bob.page.getByTestId("status-bar-p2p")).toContainText(
    `P2P: ${alice.nick}`,
    { timeout: 20_000 },
  );

  return { alice, bob };
}

async function reportP2PRecoveryFailure(page: Page, reason: string) {
  await page.getByTestId("p2p-webrtc").evaluate((el, failureReason) => {
    el.dispatchEvent(
      new CustomEvent("p2p-lobby:recovery-state", {
        detail: {
          state: "failed",
          reason: failureReason,
          manual_retry: true,
        },
      }),
    );
  }, reason);
}

async function confirmP2PEnd(page: Page) {
  const confirm = page.getByTestId("p2p-confirm-dialog-confirm");
  await expect(confirm).toBeVisible();
  await expect(confirm).toBeEnabled();
  await confirm.click();
}

async function openP2PEndFromRecovery(page: Page, reason: string) {
  await expect(async () => {
    await reportP2PRecoveryFailure(page, reason);

    const banner = page.getByTestId("p2p-recovery-banner");
    await expect(banner).toHaveAttribute("data-p2p-recovery-state", "failed", {
      timeout: 1_000,
    });
    await expect(banner).toContainText("Retry", { timeout: 1_000 });

    await page.getByTestId("p2p-end-from-recovery").click({ timeout: 1_000 });
    await expect(page.getByTestId("p2p-confirm-dialog-confirm")).toBeVisible({
      timeout: 1_000,
    });
  }).toPass({ timeout: 10_000 });
}

async function joinChannel(
  user: {
    chat: {
      sendMessage: (message: string) => Promise<void>;
      expectTabVisible: (channel: string) => Promise<void>;
      switchToTab: (channel: string) => Promise<void>;
    };
    page: Page;
  },
  channel: string,
) {
  await user.chat.sendMessage(`/join ${channel}`);
  await user.chat.expectTabVisible(channel);
  await user.chat.switchToTab(channel);
  await expect(user.page.getByTestId("group-call-open")).toBeEnabled();
}

async function joinGroupCall(page: Page) {
  await page.getByTestId("group-call-open").click();
  await expect(
    page.locator("#group-call-prejoin-dialog-surface"),
  ).toBeVisible();
  await page.getByTestId("group-call-prejoin-join").click();
  await expect(page.getByTestId("group-call-window")).toBeVisible();
  await expect(page.getByTestId("status-bar-group-call")).toBeVisible();
}

async function reportGroupCallRecoveryFailure(page: Page, reason: string) {
  await page.getByTestId("group-call-webrtc").evaluate((el, failureReason) => {
    el.dispatchEvent(
      new CustomEvent("group-call:recovery-state", {
        detail: {
          state: "failed",
          reason: failureReason,
          trigger: "fault_injection",
          manual_retry: true,
          attempt: 3,
          max_attempts: 3,
          message: "Media recovery failed. Retry the media connection.",
        },
      }),
    );
  }, reason);
}

async function confirmGroupCallLeave(page: Page) {
  const confirm = page.getByTestId("group-call-confirm-dialog-confirm");
  await expect(confirm).toBeVisible();
  await expect(confirm).toBeEnabled();
  await confirm.click();
}

async function openGroupCallLeaveFromError(page: Page, reason: string) {
  await expect(async () => {
    await reportGroupCallRecoveryFailure(page, reason);
    await expect(page.getByTestId("group-call-error")).toContainText("Retry", {
      timeout: 1_000,
    });
    await page
      .getByTestId("group-call-leave-from-error")
      .click({ timeout: 1_000 });
    await expect(
      page.getByTestId("group-call-confirm-dialog-confirm"),
    ).toBeVisible({ timeout: 1_000 });
  }).toPass({ timeout: 10_000 });
}

test.describe("Call fault injection", () => {
  test("P2P stays actionable across a short LiveView outage and can end after reconnect", async ({
    browser,
  }) => {
    test.setTimeout(75_000);
    const { alice, bob } = await establishP2P(browser);

    try {
      await bob.ctx.setOffline(true);
      await expect(bob.chat.connectionBanner).toHaveClass(
        /connection-banner--visible/,
        { timeout: 12_000 },
      );
      await expect(bob.page.getByTestId("p2p-call-window")).toBeVisible();
      await expect(bob.page.getByTestId("p2p-session-console")).toBeVisible();
      await expect(
        bob.page.getByTestId("p2p-console-end-session"),
      ).toBeVisible();

      await bob.ctx.setOffline(false);
      await bob.chat.waitUntilConnected();

      await bob.page.getByTestId("p2p-console-end-session").click();
      await confirmP2PEnd(bob.page);

      await expect(bob.page.getByTestId("status-bar-p2p")).toBeHidden({
        timeout: 10_000,
      });
      await expect(alice.page.getByTestId("status-bar-p2p")).toBeHidden({
        timeout: 10_000,
      });
    } finally {
      await bob.ctx.setOffline(false).catch(() => {});
      await closeP2PUsers([alice, bob]);
    }
  });

  test("P2P recovery error End button opens confirm and terminates the session", async ({
    browser,
  }) => {
    test.setTimeout(75_000);
    const { alice, bob } = await establishP2P(browser);

    try {
      await openP2PEndFromRecovery(bob.page, "max_retries_exhausted");
      await confirmP2PEnd(bob.page);

      await expect(bob.page.getByTestId("status-bar-p2p")).toBeHidden({
        timeout: 10_000,
      });
      await expect(alice.page.getByTestId("status-bar-p2p")).toBeHidden({
        timeout: 10_000,
      });
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test("P2P answerer reloads while applying the initial offer and reconnects media", async ({
    browser,
  }) => {
    test.setTimeout(90_000);
    const alice = await newP2PUser(browser, "fira", { media: true });
    const bob = await newP2PUser(browser, "firb", { media: true });

    try {
      await sendP2PInvite(alice, bob.nick);
      await bob.chat.expectTabVisible(alice.nick);
      await bob.chat.switchToTab(alice.nick);
      await delayNextRemoteOffer(bob.page);

      await acceptP2PInvite(bob.page);
      await waitForDelayedRemoteOffer(bob.page);

      await bob.page.reload({ waitUntil: "load" });
      await bob.chat.waitUntilConnected();

      await expect(bob.page.getByTestId("status-bar-p2p")).toContainText(
        `P2P: ${alice.nick}`,
        { timeout: 20_000 },
      );
      await expect(alice.page.getByTestId("status-bar-p2p")).toContainText(
        `P2P: ${bob.nick}`,
        { timeout: 20_000 },
      );
      await expect(bob.page.getByTestId("p2p-call-window")).toBeVisible({
        timeout: 20_000,
      });

      await expect
        .poll(() => p2pRemoteVideoLive(alice.page), { timeout: 30_000 })
        .toBe(true);
      await expect
        .poll(() => p2pRemoteVideoLive(bob.page), { timeout: 30_000 })
        .toBe(true);
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test("P2P simultaneous manual retries stay coordinated and recover media", async ({
    browser,
  }) => {
    test.setTimeout(90_000);
    const { alice, bob } = await establishP2P(browser);

    try {
      await expect
        .poll(() => p2pRemoteVideoLive(alice.page), { timeout: 30_000 })
        .toBe(true);
      await expect
        .poll(() => p2pRemoteVideoLive(bob.page), { timeout: 30_000 })
        .toBe(true);

      await Promise.all([
        reportP2PRecoveryFailure(alice.page, "simultaneous_recovery"),
        reportP2PRecoveryFailure(bob.page, "simultaneous_recovery"),
      ]);

      for (const user of [alice, bob]) {
        const banner = user.page.getByTestId("p2p-recovery-banner");
        await expect(banner).toHaveAttribute(
          "data-p2p-recovery-state",
          "failed",
          {
            timeout: 10_000,
          },
        );
        await expect(banner).toContainText("Retry");
        await expect(
          user.page.getByTestId("p2p-retry-connection"),
        ).toBeEnabled();
      }

      const retryClicks = await Promise.allSettled([
        alice.page
          .getByTestId("p2p-retry-connection")
          .click({ timeout: 2_000 }),
        bob.page.getByTestId("p2p-retry-connection").click({ timeout: 2_000 }),
      ]);

      expect(retryClicks.some((result) => result.status === "fulfilled")).toBe(
        true,
      );

      await expect(alice.page.getByTestId("status-bar-p2p")).toContainText(
        `P2P: ${bob.nick}`,
        { timeout: 20_000 },
      );
      await expect(bob.page.getByTestId("status-bar-p2p")).toContainText(
        `P2P: ${alice.nick}`,
        { timeout: 20_000 },
      );
      await expect(alice.page.getByTestId("p2p-recovery-banner")).toBeHidden({
        timeout: 30_000,
      });
      await expect(bob.page.getByTestId("p2p-recovery-banner")).toBeHidden({
        timeout: 30_000,
      });
      await expect
        .poll(() => p2pRemoteVideoLive(alice.page), { timeout: 30_000 })
        .toBe(true);
      await expect
        .poll(() => p2pRemoteVideoLive(bob.page), { timeout: 30_000 })
        .toBe(true);
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test("conference stays actionable across a short LiveView outage and can leave after reconnect", async ({
    browser,
  }) => {
    test.setTimeout(75_000);
    const alice = await newGroupCallUser(browser, "figa");
    const bob = await newGroupCallUser(browser, "figb");
    const channel = uniqueChannel("faultg");

    try {
      for (const user of [alice, bob]) {
        await joinChannel(user, channel);
      }

      await joinGroupCall(alice.page);
      await joinGroupCall(bob.page);

      await bob.ctx.setOffline(true);
      await expect(bob.chat.connectionBanner).toHaveClass(
        /connection-banner--visible/,
        { timeout: 12_000 },
      );
      await expect(bob.page.getByTestId("group-call-window")).toBeVisible();
      await expect(bob.page.getByTestId("group-call-leave")).toBeVisible();

      await bob.ctx.setOffline(false);
      await bob.chat.waitUntilConnected();

      await bob.page.getByTestId("group-call-leave").click();
      await confirmGroupCallLeave(bob.page);

      await expect(bob.page.getByTestId("status-bar-group-call")).toBeHidden({
        timeout: 10_000,
      });
      await expect(bob.page.getByTestId("group-call-window")).toBeHidden({
        timeout: 10_000,
      });
    } finally {
      await bob.ctx.setOffline(false).catch(() => {});
      await closeGroupCallUsers([alice, bob]);
    }
  });

  test("conference participant reloads while applying the SFU offer and rejoins media", async ({
    browser,
  }) => {
    test.setTimeout(90_000);
    const alice = await newGroupCallUser(browser, "figr");
    const bob = await newGroupCallUser(browser, "figs");
    const channel = uniqueChannel("offerreload");

    try {
      for (const user of [alice, bob]) {
        await joinChannel(user, channel);
      }

      await joinGroupCall(alice.page);
      await delayNextRemoteOffer(bob.page);
      await joinGroupCall(bob.page);
      await waitForDelayedRemoteOffer(bob.page);

      await bob.page.reload({ waitUntil: "load" });
      await bob.chat.waitUntilConnected();

      await expect(bob.page.getByTestId("status-bar-group-call")).toContainText(
        "Call:",
        { timeout: 20_000 },
      );
      await expect(bob.page.getByTestId("group-call-window")).toBeVisible({
        timeout: 20_000,
      });
      await expect(bob.page.getByTestId("group-call-webrtc")).toBeVisible({
        timeout: 20_000,
      });

      await expect
        .poll(() => groupCallRemoteVideoLive(alice.page), { timeout: 30_000 })
        .toBe(true);
      await expect
        .poll(() => groupCallRemoteVideoLive(bob.page), { timeout: 30_000 })
        .toBe(true);
    } finally {
      await closeGroupCallUsers([alice, bob]);
    }
  });

  test("conference retry rejoins media when the participant PeerServer disappears", async ({
    browser,
  }) => {
    // Killing a PeerServer needs `/api/e2e/group-call-peer/terminate`, compiled
    // in only when `:e2e_fault_injection?` is set. The rest of this file drops
    // the connection through the browser and runs anywhere.
    test.skip(
      !isLocalTarget(),
      localOnlyReason("terminating a PeerServer needs the e2e-only API"),
    );
    test.setTimeout(90_000);
    const alice = await newGroupCallUser(browser, "figp");
    const bob = await newGroupCallUser(browser, "figq");
    const channel = uniqueChannel("peerrestart");

    try {
      for (const user of [alice, bob]) {
        await joinChannel(user, channel);
      }

      await joinGroupCall(alice.page);
      await joinGroupCall(bob.page);

      await expect
        .poll(() => groupCallRemoteVideoLive(alice.page), { timeout: 30_000 })
        .toBe(true);
      await expect
        .poll(() => groupCallRemoteVideoLive(bob.page), { timeout: 30_000 })
        .toBe(true);

      const before = await terminateGroupCallPeer(bob.page);

      await reportGroupCallRecoveryFailure(bob.page, "peer_server_crashed");
      await expect(bob.page.getByTestId("group-call-error")).toContainText(
        "Retry",
        { timeout: 10_000 },
      );
      await expect(bob.page.getByTestId("group-call-retry")).toBeEnabled();
      await bob.page.getByTestId("group-call-retry").click();

      await expect(bob.page.getByTestId("group-call-error")).toBeHidden({
        timeout: 20_000,
      });
      await expect(bob.page.getByTestId("status-bar-group-call")).toContainText(
        "Call:",
        { timeout: 20_000 },
      );
      await expect(bob.page.getByTestId("group-call-webrtc")).toHaveAttribute(
        "data-participant-id",
        before.participantId,
        { timeout: 20_000 },
      );
      await expect
        .poll(() => groupCallRemoteVideoLive(alice.page), { timeout: 30_000 })
        .toBe(true);
      await expect
        .poll(() => groupCallRemoteVideoLive(bob.page), { timeout: 30_000 })
        .toBe(true);
    } finally {
      await closeGroupCallUsers([alice, bob]);
    }
  });

  test("conference recovery error Leave button opens confirm and exits cleanly", async ({
    browser,
  }) => {
    test.setTimeout(60_000);
    const alice = await newGroupCallUser(browser, "fige");
    const channel = uniqueChannel("faulterr");

    try {
      await joinChannel(alice, channel);
      await joinGroupCall(alice.page);

      await openGroupCallLeaveFromError(alice.page, "ice_failed");
      await confirmGroupCallLeave(alice.page);

      await expect(alice.page.getByTestId("status-bar-group-call")).toBeHidden({
        timeout: 10_000,
      });
      await expect(alice.page.getByTestId("group-call-window")).toBeHidden({
        timeout: 10_000,
      });
    } finally {
      await closeGroupCallUsers([alice]);
    }
  });
});

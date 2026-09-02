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
  GroupCallUser,
  newGroupCallUser,
  openConference,
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

// The card in the conversation is the door, and it opens a tab of its own.
async function enterP2PSession(user: P2PTestUser): Promise<Page> {
  const entry = user.page.getByTestId("p2p-peer-entry");
  await expect(entry).toHaveAttribute("href", /\/p2p\//, { timeout: 20_000 });

  const [session] = await Promise.all([
    user.ctx.waitForEvent("page"),
    entry.click(),
  ]);

  await session.waitForLoadState("domcontentloaded");
  return session;
}

async function sendP2PInvite(
  user: P2PTestUser,
  targetNick: string,
): Promise<Page> {
  await user.chat.sendMessage(`/p2p ${targetNick}`);
  const session = await enterP2PSession(user);
  await expect(session.getByTestId("p2p-starting-room")).toBeVisible();
  await session.getByTestId("p2p-room-ready").click();
  return session;
}

async function acceptP2PInvite(user: P2PTestUser): Promise<Page> {
  await expect(user.page.getByTestId("p2p-peer-entry")).toHaveAttribute(
    "data-p2p-state",
    "pending",
  );

  const session = await enterP2PSession(user);
  await expect(session.getByTestId("p2p-starting-room")).toBeVisible();
  await session.getByTestId("p2p-room-ready").click();
  return session;
}

// The host releases the first offer, which is the gate the negotiation has
// always had — it just has a button now.
async function startP2PSession(session: Page) {
  await expect(session.getByTestId("p2p-room-start")).toBeEnabled({
    timeout: 20_000,
  });
  await session.getByTestId("p2p-room-start").click();
  await expect(session.getByTestId("p2p-session-console")).toBeVisible();
}

async function establishP2P(browser: Browser) {
  const alice = await newP2PUser(browser, "fiap", { media: true });
  const bob = await newP2PUser(browser, "fibp", { media: true });

  const aliceSession = await sendP2PInvite(alice, bob.nick);
  await bob.chat.expectTabVisible(alice.nick);
  await bob.chat.switchToTab(alice.nick);
  const bobSession = await acceptP2PInvite(bob);
  await startP2PSession(aliceSession);

  await expect(alice.page.getByTestId("status-bar-p2p")).toContainText(
    `P2P: ${bob.nick}`,
    { timeout: 20_000 },
  );
  await expect(bob.page.getByTestId("status-bar-p2p")).toContainText(
    `P2P: ${alice.nick}`,
    { timeout: 20_000 },
  );

  return { alice, bob, aliceSession, bobSession };
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

// The conference is a page of its own, reached through the card the chat writes
// when the room is opened. The returned page is where the call actually is; the
// chat keeps only the zone that points at it.
async function joinGroupCall(user: GroupCallUser): Promise<Page> {
  const call = await openConference(user);
  await expect(call.getByTestId("group-call-prejoin")).toBeVisible();
  await call.getByTestId("group-call-prejoin-join").click();
  await expect(call.getByTestId("group-call-panel")).toBeVisible();
  await expect(user.page.getByTestId("status-bar-group-call")).toBeVisible();
  return call;
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
    const { alice, bob, bobSession } = await establishP2P(browser);

    try {
      await bob.ctx.setOffline(true);
      await expect(bob.chat.connectionBanner).toHaveClass(
        /connection-banner--visible/,
        { timeout: 12_000 },
      );
      await expect(bobSession.getByTestId("p2p-call-window")).toBeVisible();
      await expect(bobSession.getByTestId("p2p-session-console")).toBeVisible();
      await expect(
        bobSession.getByTestId("p2p-console-end-session"),
      ).toBeVisible();

      await bob.ctx.setOffline(false);
      await bob.chat.waitUntilConnected();

      await bobSession.getByTestId("p2p-console-end-session").click();
      await confirmP2PEnd(bobSession);

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
    const { alice, bob, bobSession } = await establishP2P(browser);

    try {
      await openP2PEndFromRecovery(bobSession, "max_retries_exhausted");
      await confirmP2PEnd(bobSession);

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
      const aliceSession = await sendP2PInvite(alice, bob.nick);
      await bob.chat.expectTabVisible(alice.nick);
      await bob.chat.switchToTab(alice.nick);

      // The offer is delayed on the page that will apply it, which is the
      // session's own — the chat carries no signalling any more.
      const bobSession = await acceptP2PInvite(bob);
      await delayNextRemoteOffer(bobSession);
      await startP2PSession(aliceSession);
      await waitForDelayedRemoteOffer(bobSession);

      await bobSession.reload({ waitUntil: "load" });

      await expect(bob.page.getByTestId("status-bar-p2p")).toContainText(
        `P2P: ${alice.nick}`,
        { timeout: 20_000 },
      );
      await expect(alice.page.getByTestId("status-bar-p2p")).toContainText(
        `P2P: ${bob.nick}`,
        { timeout: 20_000 },
      );
      await expect(bobSession.getByTestId("p2p-call-window")).toBeVisible({
        timeout: 20_000,
      });

      await expect
        .poll(() => p2pRemoteVideoLive(aliceSession), { timeout: 30_000 })
        .toBe(true);
      await expect
        .poll(() => p2pRemoteVideoLive(bobSession), { timeout: 30_000 })
        .toBe(true);
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test("P2P simultaneous manual retries stay coordinated and recover media", async ({
    browser,
  }) => {
    test.setTimeout(90_000);
    const { alice, bob, aliceSession, bobSession } =
      await establishP2P(browser);

    try {
      await expect
        .poll(() => p2pRemoteVideoLive(aliceSession), { timeout: 30_000 })
        .toBe(true);
      await expect
        .poll(() => p2pRemoteVideoLive(bobSession), { timeout: 30_000 })
        .toBe(true);

      await Promise.all([
        reportP2PRecoveryFailure(aliceSession, "simultaneous_recovery"),
        reportP2PRecoveryFailure(bobSession, "simultaneous_recovery"),
      ]);

      for (const session of [aliceSession, bobSession]) {
        const banner = session.getByTestId("p2p-recovery-banner");
        await expect(banner).toHaveAttribute(
          "data-p2p-recovery-state",
          "failed",
          {
            timeout: 10_000,
          },
        );
        await expect(banner).toContainText("Retry");
        await expect(session.getByTestId("p2p-retry-connection")).toBeEnabled();
      }

      const retryClicks = await Promise.allSettled([
        aliceSession
          .getByTestId("p2p-retry-connection")
          .click({ timeout: 2_000 }),
        bobSession
          .getByTestId("p2p-retry-connection")
          .click({ timeout: 2_000 }),
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
      await expect(aliceSession.getByTestId("p2p-recovery-banner")).toBeHidden({
        timeout: 30_000,
      });
      await expect(bobSession.getByTestId("p2p-recovery-banner")).toBeHidden({
        timeout: 30_000,
      });
      await expect
        .poll(() => p2pRemoteVideoLive(aliceSession), { timeout: 30_000 })
        .toBe(true);
      await expect
        .poll(() => p2pRemoteVideoLive(bobSession), { timeout: 30_000 })
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

      await joinGroupCall(alice);
      const bobCall = await joinGroupCall(bob);

      // The whole context goes offline, so the chat and the call lose the
      // socket together — the chat's banner is the cheapest witness that they
      // did, and the call is what has to stay actionable through it.
      await bob.ctx.setOffline(true);
      await expect(bob.chat.connectionBanner).toHaveClass(
        /connection-banner--visible/,
        { timeout: 12_000 },
      );
      await expect(bobCall.getByTestId("group-call-window")).toBeVisible();
      await expect(bobCall.getByTestId("group-call-leave")).toBeVisible();

      await bob.ctx.setOffline(false);
      await bob.chat.waitUntilConnected();

      await bobCall.getByTestId("group-call-leave").click();
      await confirmGroupCallLeave(bobCall);

      // The page says it is finished rather than navigating: going to the chat
      // from here would announce a second chat session and end the first. The
      // chat drops the zone, because the tab gave up the address with it.
      await expect(bobCall.getByTestId("call-left")).toBeVisible({
        timeout: 15_000,
      });
      await expect(bob.page.getByTestId("status-bar-group-call")).toBeHidden({
        timeout: 15_000,
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

      const aliceCall = await joinGroupCall(alice);

      // The fault has to be installed on the page that will do the negotiating,
      // which does not exist until the address is open — so the antechamber is
      // where it goes, one step before the offer it delays.
      const bobCall = await openConference(bob);
      await expect(bobCall.getByTestId("group-call-prejoin")).toBeVisible();
      await delayNextRemoteOffer(bobCall);
      await bobCall.getByTestId("group-call-prejoin-join").click();
      await expect(bobCall.getByTestId("group-call-panel")).toBeVisible();
      await waitForDelayedRemoteOffer(bobCall);

      await bobCall.reload({ waitUntil: "load" });

      await expect(bobCall.getByTestId("group-call-window")).toBeVisible({
        timeout: 20_000,
      });
      await expect(bobCall.getByTestId("group-call-webrtc")).toBeVisible({
        timeout: 20_000,
      });
      // Reopening the address is recovery: the seat is still Bob's, so this is
      // the room and not the antechamber.
      await expect(bobCall.getByTestId("group-call-prejoin")).toHaveCount(0);

      await expect
        .poll(() => groupCallRemoteVideoLive(aliceCall), { timeout: 30_000 })
        .toBe(true);
      await expect
        .poll(() => groupCallRemoteVideoLive(bobCall), { timeout: 30_000 })
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

      const aliceCall = await joinGroupCall(alice);
      const bobCall = await joinGroupCall(bob);

      await expect
        .poll(() => groupCallRemoteVideoLive(aliceCall), { timeout: 30_000 })
        .toBe(true);
      await expect
        .poll(() => groupCallRemoteVideoLive(bobCall), { timeout: 30_000 })
        .toBe(true);

      const before = await terminateGroupCallPeer(bobCall);

      await reportGroupCallRecoveryFailure(bobCall, "peer_server_crashed");
      await expect(bobCall.getByTestId("group-call-error")).toContainText(
        "Retry",
        { timeout: 10_000 },
      );
      await expect(bobCall.getByTestId("group-call-retry")).toBeEnabled();
      await bobCall.getByTestId("group-call-retry").click();

      await expect(bobCall.getByTestId("group-call-error")).toBeHidden({
        timeout: 20_000,
      });
      await expect(bobCall.getByTestId("group-call-webrtc")).toHaveAttribute(
        "data-participant-id",
        before.participantId,
        { timeout: 20_000 },
      );
      // The seat never moved, so the chat still points at the same address.
      await expect(bob.page.getByTestId("status-bar-group-call")).toBeVisible();
      await expect
        .poll(() => groupCallRemoteVideoLive(aliceCall), { timeout: 30_000 })
        .toBe(true);
      await expect
        .poll(() => groupCallRemoteVideoLive(bobCall), { timeout: 30_000 })
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
      const aliceCall = await joinGroupCall(alice);

      await openGroupCallLeaveFromError(aliceCall, "ice_failed");
      await confirmGroupCallLeave(aliceCall);

      await expect(aliceCall.getByTestId("call-left")).toBeVisible({
        timeout: 15_000,
      });
      await expect(alice.page.getByTestId("status-bar-group-call")).toBeHidden({
        timeout: 15_000,
      });
    } finally {
      await closeGroupCallUsers([alice]);
    }
  });
});

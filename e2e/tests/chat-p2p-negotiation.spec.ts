/**
 * @section N - P2P, File, Call, Game
 * @flow N28 [done] A settled call keeps its picture and logs no signalling failure
 * @flow N29 [done] The picture arrives without renegotiating repeatedly
 * @flow N30 [done] Publishing a camera mid-call renegotiates without desync
 * @flow N31 [done] The picture comes back after the peer cycles their camera
 * @flow N32 [done] A relay-only call carries the picture end to end (skipped unless E2E_BASE_URL points at a deployment with TURN: `config/e2e.exs` sets `turn_listener_count: 0`)
 * @flow N33 [done] A call negotiated across intercontinental latency stays clean
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect, Page } from "@playwright/test";
import {
  newP2PUser,
  closeP2PUsers,
  sendP2PInvite,
  acceptP2PInvite,
  startP2PSession,
  statusBarP2P,
  remoteVideoHasVisibleFrame,
  recordLocalOffers,
  localOffers,
  type P2PTestUser,
} from "../helpers/p2pFlows";

/**
 * Negotiation health for in-chat P2P calls.
 *
 * The other P2P specs assert the remote picture came up at some point, which a
 * call that connects, drops and reconnects still satisfies — the exact shape of
 * the production reconnect loop. These watch the negotiation instead: the
 * failures the hooks log while renegotiating, and whether the picture survives
 * once it arrives rather than merely appearing once.
 */

// Every line the lobby hooks log when a description cannot be applied. A clean
// call produces none of them; the reconnect loop produced them by the dozen.
const SIGNALLING_FAULTS = [
  /signaling .* failed/i,
  /connection .* failed/i,
  /InvalidStateError/,
  /InvalidAccessError/,
  /Ignoring .* meant for the peer/,
  /Ignoring .* in signalingState=/,
];

function watchSignalling(page: Page) {
  const faults: string[] = [];

  page.on("console", (message) => {
    const text = message.text();
    if (SIGNALLING_FAULTS.some((pattern) => pattern.test(text))) {
      faults.push(text);
    }
  });

  return faults;
}

/**
 * A picture that arrives and then goes black fails this; `poll` would not.
 *
 * Reports the longest run of blank samples rather than their count: one blank
 * sample is frame jitter on a real network, while the failure this guards
 * against — recovery tearing the stream down — blanks it for seconds.
 */
async function holdsVisibleFrames(page: Page, durationMs: number) {
  const deadline = Date.now() + durationMs;
  let samples = 0;
  let blankRun = 0;
  let longestBlankRun = 0;

  while (Date.now() < deadline) {
    samples += 1;

    if (await remoteVideoHasVisibleFrame(page)) {
      blankRun = 0;
    } else {
      blankRun += 1;
      longestBlankRun = Math.max(longestBlankRun, blankRun);
    }

    await page.waitForTimeout(500);
  }

  return { samples, longestBlankRun };
}

/** Approximates the round trip between a Brazilian client and a EU server. */
async function addLatency(page: Page, latencyMs: number) {
  const session = await page.context().newCDPSession(page);
  await session.send("Network.enable");
  await session.send("Network.emulateNetworkConditions", {
    offline: false,
    latency: latencyMs,
    downloadThroughput: -1,
    uploadThroughput: -1,
  });
}

async function connectPair(alice: P2PTestUser, bob: P2PTestUser, options = {}) {
  await sendP2PInvite(alice, bob.nick);
  await bob.chat.expectTabVisible(alice.nick);
  await bob.chat.switchToTab(alice.nick);
  await acceptP2PInvite(bob.page, options);
  await startP2PSession(alice);

  await expect(statusBarP2P(alice.page)).toContainText(`P2P: ${bob.nick}`, {
    timeout: 20_000,
  });
}

test.describe("P2P negotiation health", () => {
  test("a settled call keeps its picture and logs no signalling failure", async ({
    browser,
  }) => {
    test.setTimeout(90_000);

    const alice = await newP2PUser(browser, "png", { media: true });
    const bob = await newP2PUser(browser, "pnh", { media: true });
    const aliceFaults = watchSignalling(alice.page);
    const bobFaults = watchSignalling(bob.page);

    try {
      await connectPair(alice, bob);

      for (const page of [alice.page, bob.page]) {
        await expect
          .poll(() => remoteVideoHasVisibleFrame(page), { timeout: 30_000 })
          .toBe(true);
      }

      // Once negotiated the picture must stay, not flicker through recovery.
      for (const page of [alice.page, bob.page]) {
        const { samples, longestBlankRun } = await holdsVisibleFrames(
          page,
          5_000,
        );
        expect(samples).toBeGreaterThan(5);
        expect(longestBlankRun).toBeLessThanOrEqual(1);
      }

      expect(aliceFaults).toEqual([]);
      expect(bobFaults).toEqual([]);
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test("the picture arrives without renegotiating repeatedly", async ({
    browser,
  }) => {
    test.setTimeout(90_000);

    const alice = await newP2PUser(browser, "pnq", {
      media: true,
      instrument: recordLocalOffers,
    });
    const bob = await newP2PUser(browser, "pnr", { media: true });

    try {
      await connectPair(alice, bob);

      await expect
        .poll(() => remoteVideoHasVisibleFrame(alice.page), { timeout: 30_000 })
        .toBe(true);

      // Local media is acquired after the data channels have already triggered
      // the first offer, so one follow-up round is expected. More than that
      // means the stalled-media watchdog is asking for restarts while that
      // round is still in flight — which is what makes the picture take
      // seconds to appear instead of arriving with the connection.
      const offers = await localOffers(alice.page);
      expect(offers.length).toBeGreaterThan(0);
      expect(offers.length).toBeLessThanOrEqual(3);
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test("publishing a camera mid-call renegotiates without desync", async ({
    browser,
  }) => {
    test.setTimeout(90_000);

    const alice = await newP2PUser(browser, "pni", { media: true });
    const bob = await newP2PUser(browser, "pnj", { media: true });
    const aliceFaults = watchSignalling(alice.page);
    const bobFaults = watchSignalling(bob.page);

    try {
      // Bob joins without a camera, so his video m-line only appears on the
      // renegotiation his own toggle triggers — media added after the
      // connection settled, which is where the desync used to land.
      await connectPair(alice, bob, { audio: true, video: false });

      await expect
        .poll(() => remoteVideoHasVisibleFrame(bob.page), { timeout: 30_000 })
        .toBe(true);

      await bob.page.getByTestId("p2p-call-enable-video").click();

      await expect
        .poll(() => remoteVideoHasVisibleFrame(alice.page), { timeout: 30_000 })
        .toBe(true);

      const { longestBlankRun } = await holdsVisibleFrames(alice.page, 4_000);
      expect(longestBlankRun).toBeLessThanOrEqual(1);

      expect(aliceFaults).toEqual([]);
      expect(bobFaults).toEqual([]);
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test("the picture comes back after the peer cycles their camera", async ({
    browser,
  }) => {
    test.setTimeout(120_000);

    const alice = await newP2PUser(browser, "pnm", { media: true });
    const bob = await newP2PUser(browser, "pnn", { media: true });
    const aliceFaults = watchSignalling(alice.page);

    try {
      await connectPair(alice, bob);

      await expect
        .poll(() => remoteVideoHasVisibleFrame(alice.page), { timeout: 30_000 })
        .toBe(true);

      // Cycling the camera republishes the track, so `ontrack` fires again with
      // a fresh stream. Swapping the element's srcObject for it cancels the
      // pending play() — the picture can stay black with RTP still arriving.
      const cameraToggle = bob.page.getByTestId("p2p-call-toggle-camera");
      await cameraToggle.click();
      await expect
        .poll(() => remoteVideoHasVisibleFrame(alice.page), { timeout: 15_000 })
        .toBe(false);

      await cameraToggle.click();

      await expect
        .poll(() => remoteVideoHasVisibleFrame(alice.page), { timeout: 30_000 })
        .toBe(true);

      const { longestBlankRun } = await holdsVisibleFrames(alice.page, 4_000);
      expect(longestBlankRun).toBeLessThanOrEqual(1);
      expect(aliceFaults).toEqual([]);
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  // Two peers on one machine pick host candidates and never touch the relay.
  // Forcing relay-only is the closest a single-machine run gets to two peers on
  // different networks, which is the path a real call between two homes takes.
  test("a relay-only call carries the picture end to end", async ({
    browser,
  }) => {
    // `config/e2e.exs` sets turn_listener_count: 0, so the local server has no
    // relay to offer and a relay-only call cannot gather a candidate at all.
    test.skip(
      !process.env.E2E_BASE_URL,
      "relay-only needs a deployment with TURN; point E2E_BASE_URL at one",
    );
    test.setTimeout(150_000);

    const alice = await newP2PUser(browser, "pno", { media: true });
    const bob = await newP2PUser(browser, "pnp", { media: true });
    const aliceFaults = watchSignalling(alice.page);
    const bobFaults = watchSignalling(bob.page);

    try {
      await connectPair(alice, bob, { turnOnly: true });

      for (const page of [alice.page, bob.page]) {
        await expect
          .poll(() => remoteVideoHasVisibleFrame(page), { timeout: 60_000 })
          .toBe(true);
      }

      const { longestBlankRun } = await holdsVisibleFrames(alice.page, 5_000);
      expect(longestBlankRun).toBeLessThanOrEqual(1);
      expect(aliceFaults).toEqual([]);
      expect(bobFaults).toEqual([]);
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test("a call negotiated across intercontinental latency stays clean", async ({
    browser,
  }) => {
    test.setTimeout(120_000);

    const alice = await newP2PUser(browser, "pnk", { media: true });
    const bob = await newP2PUser(browser, "pnl", { media: true });
    const aliceFaults = watchSignalling(alice.page);
    const bobFaults = watchSignalling(bob.page);

    try {
      // Signalling rides the LiveView socket, so a slow socket batches
      // descriptions and candidates that arrive one at a time on a fast one.
      await addLatency(alice.page, 200);
      await addLatency(bob.page, 200);

      await connectPair(alice, bob);

      for (const page of [alice.page, bob.page]) {
        await expect
          .poll(() => remoteVideoHasVisibleFrame(page), { timeout: 45_000 })
          .toBe(true);
      }

      const { longestBlankRun } = await holdsVisibleFrames(alice.page, 5_000);
      expect(longestBlankRun).toBeLessThanOrEqual(1);

      expect(aliceFaults).toEqual([]);
      expect(bobFaults).toEqual([]);
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });
});

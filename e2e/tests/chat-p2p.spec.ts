/**
 * @section N - P2P, File, Call, Game
 * @flow N18 [done] Both peers enter the session by the card the invite writes into the private message
 * @flow N19 [done] The auto-started call carries real video both ways; file transfer and the game share the same connection
 * @flow N20 [done] pt-BR privacy relay setup connects both peers when TURN is available
 * @flow N21 [done] Receive-only setup joins without local tracks and keeps remote media reachable
 * @flow N22 [done] Audio-only setup publishes the microphone without a local camera and still receives remote video
 * @flow N23 [done] Screen share marks the peer tile and the P2P stats video source
 * @flow N24 [done] Failed recovery offers a retry without closing the P2P console
 * @flow N25 [done] Mini mode, the stats section, and maximize keep the P2P video alive
 * @flow N26 [done] Declining the invite tells the inviter and clears the pending state
 * @flow N27 [done] The inviter cancels a pending invite from the room the card led to
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect, Page } from "@playwright/test";
import { mkdirSync } from "node:fs";
import {
  newP2PUser,
  closeP2PUsers,
  statusBarP2P,
  sendP2PInvite,
  acceptP2PInvite,
  startP2PSession,
  enterP2PSession,
  remoteVideoLive,
  remoteVideoHasVisibleFrame,
  type P2PTestUser,
} from "../helpers/p2pFlows";

/**
 * P2P sessions, from the conversation that starts one to the tab that holds it.
 *
 * The chat has no window for a session any more. `/p2p <nick>` writes a card
 * carrying the session's own address into the private message, and both people
 * enter through it — so every test here drives two pages per person: the chat,
 * which keeps the badge and the way back, and the session, which is everything
 * else.
 */

function statusBarStop(page: Page) {
  return page.getByTestId("status-bar-p2p-stop");
}

const p2pFlowScreenshotDir = "test-results/p2p-flow-conference-parity";

function p2pFlowScreenshot(name: string) {
  mkdirSync(p2pFlowScreenshotDir, { recursive: true });
  return `${p2pFlowScreenshotDir}/${name}.png`;
}

async function reportP2PRecoveryState(
  page: Page,
  payload: {
    state: "failed" | "reconnecting";
    reason?: string;
    manual_retry?: boolean;
    attempt?: number;
  },
) {
  await page.getByTestId("p2p-webrtc").evaluate((el, detail) => {
    el.dispatchEvent(
      new CustomEvent("p2p-lobby:recovery-state", {
        detail,
      }),
    );
  }, payload);
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

function p2pStatsTab(
  page: Page,
  tab: "network" | "audio" | "video" | "game" | "file",
) {
  return page.getByTestId(`p2p-stats-tab-${tab}`);
}

function p2pStatsDetails(
  page: Page,
  details: "connection" | "audio" | "video" | "game" | "file",
) {
  return page.getByTestId(`p2p-stats-details-${details}`);
}

async function expectMobileSectionNavCue(page: Page, testId: string) {
  const cue = await page.getByTestId(testId).evaluate((nav) => {
    const scroller = nav.querySelector('[data-scroll-cue="horizontal"]');
    const start = nav.querySelector('[data-scroll-cue-edge="start"]');
    const end = nav.querySelector('[data-scroll-cue-edge="end"]');
    // Scope to the scroller: the nav also holds window-control buttons that
    // carry aria-pressed and sit outside it by design.
    const active = scroller?.querySelector('button[aria-pressed="true"]');
    const scrollerRect = scroller?.getBoundingClientRect();
    const activeRect = active?.getBoundingClientRect();

    return {
      scrollCue: scroller?.getAttribute("data-scroll-cue"),
      startText: start?.textContent?.trim(),
      endText: end?.textContent?.trim(),
      startDisplay: start ? window.getComputedStyle(start).display : null,
      endDisplay: end ? window.getComputedStyle(end).display : null,
      activeInsideScroller:
        !!scrollerRect &&
        !!activeRect &&
        activeRect.left >= scrollerRect.left - 1 &&
        activeRect.right <= scrollerRect.right + 1,
    };
  });

  expect(cue.scrollCue).toBe("horizontal");
  expect(cue.startText).toBe("<");
  expect(cue.endText).toBe(">");
  expect(cue.startDisplay).toBe("flex");
  expect(cue.endDisplay).toBe("flex");
  expect(cue.activeInsideScroller).toBe(true);
}

async function expectMediaSessionHeadersStable(page: Page, rootTestId: string) {
  const metrics = await page.getByTestId(rootTestId).evaluate((root) => {
    const rootRect = root.getBoundingClientRect();
    const overflowHeaders: string[] = [];
    const horizontalScrollHeaders: string[] = [];

    for (const header of Array.from(
      root.querySelectorAll<HTMLElement>("header"),
    )) {
      const rect = header.getBoundingClientRect();
      if (rect.width === 0 || rect.height === 0) continue;

      const label =
        header.dataset.testid ||
        header.textContent?.replace(/\s+/g, " ").trim().slice(0, 80) ||
        "header";

      if (
        rect.left < rootRect.left - 1 ||
        rect.right > rootRect.right + 1 ||
        rect.top < rootRect.top - 1 ||
        rect.bottom > rootRect.bottom + 1
      ) {
        overflowHeaders.push(label);
      }

      if (header.scrollWidth > header.clientWidth + 2) {
        horizontalScrollHeaders.push(label);
      }
    }

    return { overflowHeaders, horizontalScrollHeaders };
  });

  expect(metrics.overflowHeaders).toEqual([]);
  expect(metrics.horizontalScrollHeaders).toEqual([]);
}

async function expectP2PConsoleLayoutStable(page: Page) {
  const metrics = await page
    .getByTestId("p2p-session-console")
    .evaluate((root) => {
      const rootRect = root.getBoundingClientRect();
      const overflowElements: string[] = [];
      const horizontalScrollElements: string[] = [];

      for (const element of Array.from(
        root.querySelectorAll<HTMLElement>(
          [
            "header",
            "nav",
            '[data-testid="p2p-call-panel"]',
            '[data-testid="p2p-console-section-call"]',
            '[data-testid="p2p-console-section-files"]',
            '[data-testid="p2p-console-section-games"]',
            '[data-testid="p2p-console-section-stats"]',
            '[data-testid="lobby-file-panel"]',
            '[data-testid="lobby-game-panel"]',
          ].join(","),
        ),
      )) {
        const rect = element.getBoundingClientRect();
        if (rect.width === 0 || rect.height === 0) continue;

        const label =
          element.dataset.testid ||
          element.getAttribute("aria-label") ||
          element.tagName;

        if (
          rect.left < rootRect.left - 1 ||
          rect.right > rootRect.right + 1 ||
          rect.top < rootRect.top - 1 ||
          rect.bottom > rootRect.bottom + 1
        ) {
          overflowElements.push(label);
        }

        if (
          element.getAttribute("data-scroll-cue") !== "horizontal" &&
          element.scrollWidth > element.clientWidth + 2
        ) {
          horizontalScrollElements.push(label);
        }
      }

      return {
        overflowElements,
        horizontalScrollElements,
        rootWidth: Math.round(rootRect.width),
        rootHeight: Math.round(rootRect.height),
      };
    });

  expect(metrics.rootWidth).toBeGreaterThan(240);
  expect(metrics.rootHeight).toBeGreaterThan(180);
  expect(metrics.overflowElements).toEqual([]);
  expect(metrics.horizontalScrollElements).toEqual([]);
}

// The session header moved into the window title bar, so the call window must
// carry no inner header of its own: the chrome is the title bar plus the nav row.
async function expectP2PCallHasNoInnerHeader(page: Page) {
  const visibleHeaderCount = await page
    .getByTestId("p2p-call-window")
    .locator("header")
    .evaluateAll(
      (headers) =>
        headers.filter((header) => {
          const element = header as HTMLElement;
          const rect = element.getBoundingClientRect();
          const style = window.getComputedStyle(element);

          return (
            rect.width > 0 &&
            rect.height > 0 &&
            style.display !== "none" &&
            style.visibility !== "hidden"
          );
        }).length,
    );

  expect(visibleHeaderCount).toBe(0);
}

async function expectP2PSectionScrollHooks(page: Page) {
  for (const section of ["call", "files", "games", "stats"] as const) {
    const sectionRoot = page.getByTestId(`p2p-console-section-${section}`);
    await expect(sectionRoot).toHaveAttribute("phx-hook", "PreserveScrollHook");
    await expect(sectionRoot).toHaveAttribute(
      "data-preserve-scroll-target",
      "self",
    );
  }
}

async function expectScrollStableAcrossStatsTick(page: Page, testId: string) {
  const before = await page.getByTestId(testId).evaluate((element) => {
    element.scrollTop = Math.max(
      1,
      element.scrollHeight - element.clientHeight,
    );

    return {
      clientHeight: element.clientHeight,
      scrollHeight: element.scrollHeight,
      scrollTop: Math.round(element.scrollTop),
    };
  });

  expect(before.scrollHeight).toBeGreaterThan(before.clientHeight + 8);
  expect(before.scrollTop).toBeGreaterThan(0);

  await page.waitForTimeout(3_200);

  const after = await page
    .getByTestId(testId)
    .evaluate((element) => Math.round(element.scrollTop));

  expect(after).toBeGreaterThanOrEqual(before.scrollTop - 2);
}

async function localP2PTrackEnabled(page: Page, kind: "audio" | "video") {
  return page.evaluate((trackKind) => {
    const video = document.getElementById(
      "lobby-local-video",
    ) as HTMLVideoElement | null;
    const stream = video?.srcObject as MediaStream | null;
    const tracks =
      trackKind === "audio"
        ? stream?.getAudioTracks()
        : stream?.getVideoTracks();

    return tracks?.[0]?.enabled ?? null;
  }, kind);
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
  test("both peers enter the session by the card the invite wrote", async ({
    browser,
  }) => {
    const alice = await newP2PUser(browser, "callermax", { media: true });
    const bob = await newP2PUser(browser, "peermaxxxx", { media: true });

    try {
      const aliceSession = await sendP2PInvite(alice, bob.nick);

      // The chat is still the chat: what it says about the session is a way
      // back to the tab holding it, and nothing that acts on it.
      await expect(statusBarP2P(alice.page)).toContainText("in another tab");
      await expect(statusBarStop(alice.page)).toHaveCount(0);
      await expect(alice.page.getByTestId("chat-window")).toBeVisible();

      const pendingImage = await aliceSession
        .getByTestId("p2p-call-window")
        .screenshot({ path: p2pFlowScreenshot("p2p-pending-console") });
      expect(pendingImage.byteLength).toBeGreaterThan(8_000);

      // Bob receives the PM tab in the background, then follows the same card
      // — no page navigation of the chat, and no actionable transcript card.
      await bob.chat.expectTabVisible(alice.nick);
      await bob.chat.expectTabUnread(alice.nick, true);
      // Background means no tab of its own — the bar still belongs to #lobby.
      await expect(bob.chat.tab(alice.nick)).toHaveCount(0);
      await bob.chat.switchToTab(alice.nick);
      const bobSession = await acceptP2PInvite(bob);
      await startP2PSession(aliceSession);

      // The WebRTC link comes up in the two tabs that hold the session, and
      // each chat says which peer it is with.
      await expect(statusBarP2P(alice.page)).toContainText(`P2P: ${bob.nick}`, {
        timeout: 20_000,
      });
      await expect(statusBarP2P(bob.page)).toContainText(`P2P: ${alice.nick}`, {
        timeout: 20_000,
      });

      // The session presents itself as one P2P console and the call
      // auto-starts (mic+camera) on BOTH sides.
      for (const page of [aliceSession, bobSession]) {
        await expect(page.getByTestId("p2p-call-window")).toBeVisible();
        await expect(page.getByTestId("p2p-session-console")).toBeVisible();
        await expect(page.getByTestId("p2p-console-nav-call")).toBeVisible();
        await expect(page.getByTestId("p2p-console-nav-files")).toBeVisible();
        await expect(page.getByTestId("p2p-console-nav-games")).toBeVisible();
        await expect(page.getByTestId("p2p-console-nav-stats")).toBeVisible();
        await expect(
          page.locator('[data-lobby-media-action="end-call"]'),
        ).toBeVisible({ timeout: 20_000 });
      }

      await expect
        .poll(() => remoteVideoHasVisibleFrame(aliceSession), {
          timeout: 20_000,
        })
        .toBe(true);
      const connectedImage = await aliceSession
        .getByTestId("p2p-call-window")
        .screenshot({ path: p2pFlowScreenshot("p2p-connected-desktop") });
      expect(connectedImage.byteLength).toBeGreaterThan(8_000);

      await aliceSession.setViewportSize({ width: 768, height: 1024 });
      await expectP2PConsoleLayoutStable(aliceSession);
      await expectMediaSessionHeadersStable(
        aliceSession,
        "p2p-session-console",
      );
      await aliceSession.setViewportSize({ width: 390, height: 844 });
      await expectMobileSectionNavCue(aliceSession, "p2p-console-nav");
      await expectP2PConsoleLayoutStable(aliceSession);
      await expectMediaSessionHeadersStable(
        aliceSession,
        "p2p-session-console",
      );
      await expect
        .poll(() => remoteVideoHasVisibleFrame(aliceSession), {
          timeout: 10_000,
        })
        .toBe(true);
      const mobileImage = await aliceSession
        .getByTestId("p2p-call-window")
        .screenshot({ path: p2pFlowScreenshot("p2p-connected-mobile") });
      expect(mobileImage.byteLength).toBeGreaterThan(8_000);
      await aliceSession.setViewportSize({ width: 1280, height: 720 });
      await expectP2PConsoleLayoutStable(aliceSession);
      await expectMediaSessionHeadersStable(
        aliceSession,
        "p2p-session-console",
      );

      // Both PM tabs carry the session glyph, and the persisted P2P line
      // landed in the conversation.
      await expect(
        alice.page.getByTestId("tab-p2p-glyph").first(),
      ).toBeVisible();
      await alice.chat.expectMessageVisible("P2P session connected");

      // Ending is one control and it asks first. The session's window is
      // pinned — the page IS the session — so there is no X to close, which is
      // why End Session lives in the console.
      await aliceSession.getByTestId("p2p-console-end-session").click();
      await expect(
        aliceSession.getByTestId("p2p-confirm-dialog"),
      ).toContainText("Any call, game or file transfer in progress will stop");
      await aliceSession.getByTestId("p2p-confirm-dialog-confirm").click();

      // The session is over, so both conversations stop advertising it.
      await expect(statusBarP2P(alice.page)).toBeHidden({ timeout: 10_000 });
      await expect(statusBarP2P(bob.page)).toBeHidden({ timeout: 10_000 });
      await alice.chat.expectMessageVisible("ended the P2P session");

      // Ending closes the session console, on both sides.
      for (const page of [aliceSession, bobSession]) {
        await expect(page.getByTestId("p2p-session-console")).toBeHidden();
      }
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test("the auto-started call carries real video both ways; file and game share the connection", async ({
    browser,
  }) => {
    test.setTimeout(75_000);

    const alice = await newP2PUser(browser, "cpg", {
      media: true,
      acceptDownloads: true,
    });
    const bob = await newP2PUser(browser, "cph", {
      media: true,
      acceptDownloads: true,
    });

    try {
      const aliceSession = await sendP2PInvite(alice, bob.nick);
      await bob.chat.expectTabVisible(alice.nick);
      await bob.chat.switchToTab(alice.nick);
      const bobSession = await acceptP2PInvite(bob);
      await startP2PSession(aliceSession);

      await expect(statusBarP2P(alice.page)).toContainText(`P2P: ${bob.nick}`, {
        timeout: 20_000,
      });

      // The auto-started call must carry REAL RTP in both directions —
      // live, unmuted remote video tracks, not just visible elements.
      for (const page of [aliceSession, bobSession]) {
        await expect
          .poll(() => remoteVideoLive(page), { timeout: 30_000 })
          .toBe(true);
      }

      // File transfer over the SAME connection, mid-call: switch to Files
      // inside the session console and send.
      await openP2PConsoleSection(aliceSession, "files");
      await expect(aliceSession.getByTestId("lobby-file-panel")).toBeVisible();
      await expectP2PConsoleLayoutStable(aliceSession);
      const fileName = "chat-p2p-during-call.txt";
      await aliceSession.locator("#lobby-file-input").setInputFiles({
        name: fileName,
        mimeType: "text/plain",
        buffer: Buffer.from("concurrent call + file payload"),
      });

      // The receiver's Files window surfaces on the offer; accepting
      // downloads the file for real.
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

      // The completed transfer lands as a persisted P2P line in the PM.
      await bob.chat.expectMessageVisible("File transfer completed");

      // A game joins the party on the same connection: switch to Games,
      // propose, accept, play.
      await openP2PConsoleSection(aliceSession, "games");
      await expect(aliceSession.getByTestId("lobby-game-panel")).toBeVisible();
      await expectP2PConsoleLayoutStable(aliceSession);
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

      // The thesis carries over from the lobby: call + file + game coexist —
      // the video is STILL flowing after everything else ran.
      await expect
        .poll(() => remoteVideoLive(aliceSession), { timeout: 15_000 })
        .toBe(true);
      await expect(statusBarP2P(alice.page)).toContainText(`P2P: ${bob.nick}`);
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test("pt-BR privacy relay setup connects both peers when TURN is available", async ({
    browser,
  }) => {
    test.setTimeout(60_000);

    const alice = await newP2PUser(browser, "relayp2pa", {
      locale: "pt_BR",
      media: true,
    });
    const bob = await newP2PUser(browser, "relayp2pb", {
      locale: "pt_BR",
      media: true,
    });

    try {
      await alice.chat.sendMessage(`/p2p ${bob.nick}`);
      const aliceSession = await enterP2PSession(alice);
      await expect(aliceSession.getByTestId("p2p-starting-room")).toBeVisible();
      await aliceSession
        .getByTestId("p2p-setup-advanced")
        .locator("summary")
        .click();
      test.skip(
        await aliceSession.getByTestId("p2p-setup-turn-only").isDisabled(),
        "TURN relay is not configured in this environment.",
      );
      await aliceSession.getByTestId("p2p-setup-turn-only").setChecked(true);
      await aliceSession.getByTestId("p2p-room-ready").click();

      await bob.chat.expectTabVisible(alice.nick);
      await bob.chat.switchToTab(alice.nick);
      const bobSession = await acceptP2PInvite(bob, { turnOnly: true });
      await startP2PSession(aliceSession);

      await expect(statusBarP2P(alice.page)).toContainText(`P2P: ${bob.nick}`, {
        timeout: 30_000,
      });
      await expect(statusBarP2P(bob.page)).toContainText(`P2P: ${alice.nick}`, {
        timeout: 30_000,
      });
      // The relay is a fact about the connection, so it is reported where the
      // connection is: the session's own stats, not the chat's status bar.
      for (const page of [aliceSession, bobSession]) {
        await page.getByTestId("p2p-console-nav-stats").click();
        await expect(page.getByTestId("p2p-stats-relay")).toBeVisible({
          timeout: 20_000,
        });
      }
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test("receive-only setup joins without local tracks and keeps remote media reachable", async ({
    browser,
  }) => {
    const alice = await newP2PUser(browser, "cproa", { media: true });
    const bob = await newP2PUser(browser, "cprob", { media: true });

    try {
      const aliceSession = await sendP2PInvite(alice, bob.nick);
      await bob.chat.expectTabVisible(alice.nick);
      await bob.chat.switchToTab(alice.nick);
      const bobSession = await acceptP2PInvite(bob, {
        audio: false,
        video: false,
      });
      await startP2PSession(aliceSession);

      await expect(statusBarP2P(alice.page)).toContainText(`P2P: ${bob.nick}`, {
        timeout: 20_000,
      });
      await expect(statusBarP2P(bob.page)).toContainText(`P2P: ${alice.nick}`, {
        timeout: 20_000,
      });

      await expect
        .poll(() => remoteVideoLive(bobSession), { timeout: 30_000 })
        .toBe(true);
      await expect
        .poll(() => localP2PTrackEnabled(bobSession, "audio"))
        .toBe(null);
      await expect
        .poll(() => localP2PTrackEnabled(bobSession, "video"))
        .toBe(null);

      await expect(bobSession.getByTestId("p2p-call-kind")).toContainText(
        "Receiving",
      );
      await expect(
        bobSession.getByTestId("p2p-call-enable-audio"),
      ).toBeVisible();
      await expect(
        bobSession.getByTestId("p2p-call-enable-video"),
      ).toBeVisible();
      await expect(bobSession.getByTestId("p2p-call-panel")).toContainText(
        "Recv-only session",
      );

      await bobSession.setViewportSize({ width: 390, height: 844 });
      await expectMobileSectionNavCue(bobSession, "p2p-console-nav");
      await expectP2PConsoleLayoutStable(bobSession);
      await expectMediaSessionHeadersStable(bobSession, "p2p-session-console");
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test("audio-only setup publishes microphone without local camera and receives remote video", async ({
    browser,
  }) => {
    test.setTimeout(75_000);

    const alice = await newP2PUser(browser, "cpaoa", { media: true });
    const bob = await newP2PUser(browser, "cpaob", { media: true });

    try {
      const aliceSession = await sendP2PInvite(alice, bob.nick);
      await bob.chat.expectTabVisible(alice.nick);
      await bob.chat.switchToTab(alice.nick);
      const bobSession = await acceptP2PInvite(bob, {
        audio: true,
        video: false,
      });
      await startP2PSession(aliceSession);

      await expect(statusBarP2P(alice.page)).toContainText(`P2P: ${bob.nick}`, {
        timeout: 20_000,
      });
      await expect(statusBarP2P(bob.page)).toContainText(`P2P: ${alice.nick}`, {
        timeout: 20_000,
      });
      await expect(
        bobSession.getByTestId("p2p-session-console"),
      ).toHaveAttribute("data-p2p-media-mode", "audio");

      await expect
        .poll(() => remoteVideoLive(bobSession), { timeout: 45_000 })
        .toBe(true);
      await expect
        .poll(() => localP2PTrackEnabled(bobSession, "audio"), {
          timeout: 20_000,
        })
        .toBe(true);
      await expect
        .poll(() => localP2PTrackEnabled(bobSession, "video"))
        .toBe(null);
      await expect(bobSession.getByTestId("p2p-call-kind")).toContainText(
        "Audio",
      );
      await expect(
        bobSession.getByTestId("p2p-call-toggle-mute"),
      ).toBeVisible();
      await expect(
        bobSession.getByTestId("p2p-call-enable-audio"),
      ).toBeHidden();
      await expect(
        bobSession.getByTestId("p2p-call-enable-video"),
      ).toBeVisible();
      await expect(
        bobSession.getByTestId("p2p-call-toggle-camera"),
      ).toBeHidden();
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test("screen share marks the peer tile and the P2P stats video source", async ({
    browser,
  }) => {
    test.setTimeout(75_000);

    const alice = await newP2PUser(browser, "cpi", { media: true });
    const bob = await newP2PUser(browser, "cpj", { media: true });

    try {
      const aliceSession = await sendP2PInvite(alice, bob.nick);
      await bob.chat.expectTabVisible(alice.nick);
      await bob.chat.switchToTab(alice.nick);
      const bobSession = await acceptP2PInvite(bob);
      await startP2PSession(aliceSession);

      await expect(statusBarP2P(alice.page)).toContainText(`P2P: ${bob.nick}`, {
        timeout: 20_000,
      });
      await expect
        .poll(() => remoteVideoLive(bobSession), { timeout: 30_000 })
        .toBe(true);

      await aliceSession.getByTestId("p2p-call-screen-share").click();
      await expect(
        aliceSession.getByTestId("p2p-call-local-tile"),
      ).toHaveAttribute("data-screen-share", "true");
      await expect(
        bobSession.getByTestId("p2p-call-remote-tile"),
      ).toHaveAttribute("data-peer-screen-share", "true", { timeout: 10_000 });

      // "Open stats" is a shortcut the call panel offers when it is mini or
      // carries its own header; the console's own nav is how the section is
      // reached with the full console on screen.
      await aliceSession.getByTestId("p2p-console-nav-stats").click();
      const statsSection = aliceSession.getByTestId(
        "p2p-console-section-stats",
      );
      await expect(statsSection).toBeVisible();
      await p2pStatsTab(aliceSession, "video").click();

      const videoStats = p2pStatsDetails(aliceSession, "video");
      await expect(videoStats).toBeVisible();
      await expect(videoStats.locator("summary")).toContainText("Screen", {
        timeout: 10_000,
      });
      await videoStats.locator("summary").click();
      await expect(videoStats).toContainText("Source");
      await expect(videoStats).toContainText("Screen");

      await openP2PConsoleSection(aliceSession, "call");
      await aliceSession.getByTestId("p2p-call-screen-share").click();
      await expect(
        aliceSession.getByTestId("p2p-call-local-tile"),
      ).toHaveAttribute("data-screen-share", "false");
      await expect(
        bobSession.getByTestId("p2p-call-remote-tile"),
      ).toHaveAttribute("data-peer-screen-share", "false", { timeout: 10_000 });
      await openP2PConsoleSection(aliceSession, "stats");
      await p2pStatsTab(aliceSession, "video").click();
      await expect(videoStats.locator("summary")).toContainText("Camera", {
        timeout: 10_000,
      });
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test("failed recovery offers retry without closing the P2P console", async ({
    browser,
  }) => {
    const alice = await newP2PUser(browser, "cprx", { media: true });
    const bob = await newP2PUser(browser, "cpry", { media: true });

    try {
      const aliceSession = await sendP2PInvite(alice, bob.nick);
      await bob.chat.expectTabVisible(alice.nick);
      await bob.chat.switchToTab(alice.nick);
      const bobSession = await acceptP2PInvite(bob);
      await startP2PSession(aliceSession);

      await expect(statusBarP2P(alice.page)).toContainText(`P2P: ${bob.nick}`, {
        timeout: 20_000,
      });
      await expect
        .poll(() => remoteVideoLive(bobSession), { timeout: 30_000 })
        .toBe(true);

      await reportP2PRecoveryState(bobSession, {
        state: "failed",
        reason: "max_retries_exhausted",
        manual_retry: true,
      });

      const banner = bobSession.getByTestId("p2p-recovery-banner");
      await expect(banner).toBeVisible();
      await expect(banner).toHaveAttribute("data-p2p-recovery-state", "failed");
      await expect(banner).toContainText("Retry");

      await bobSession.getByTestId("p2p-retry-connection").click();
      await expect(bobSession.getByTestId("p2p-call-window")).toBeVisible();
      await expect(bobSession.getByTestId("p2p-session-console")).toBeVisible();
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test("mini mode, stats section and maximize keep the P2P video alive", async ({
    browser,
  }) => {
    const alice = await newP2PUser(browser, "cpk", { media: true });
    const bob = await newP2PUser(browser, "cpl", { media: true });

    try {
      const aliceSession = await sendP2PInvite(alice, bob.nick);
      await bob.chat.expectTabVisible(alice.nick);
      await bob.chat.switchToTab(alice.nick);
      const bobSession = await acceptP2PInvite(bob);
      await startP2PSession(aliceSession);

      await expect(statusBarP2P(alice.page)).toContainText(`P2P: ${bob.nick}`, {
        timeout: 20_000,
      });
      await expect
        .poll(() => remoteVideoLive(aliceSession), { timeout: 30_000 })
        .toBe(true);
      await expectP2PCallHasNoInnerHeader(aliceSession);
      await expectP2PSectionScrollHooks(aliceSession);

      const initialRemote = await remoteVideoIdentity(aliceSession);
      expect(initialRemote?.videoIdentity).toBeTruthy();
      expect(initialRemote?.streamId).toBeTruthy();

      const callWindow = aliceSession.getByTestId("p2p-call-window");
      const callPanel = aliceSession.getByTestId("p2p-call-panel");

      // The same control is offered in more than one place — the console header
      // carries it while the call is full size, the panel grows its own once
      // mini — so both are on screen at once in mini. Either does the job.
      const miniToggle = () =>
        aliceSession
          .getByTestId("p2p-call-mini-toggle")
          .filter({ visible: true })
          .first();

      await miniToggle().click();
      await expect(callPanel).toHaveAttribute("data-call-mini", "true");

      // Mini is a layout the panel adopts inside the window, not a resize of
      // the window: the P2P window is `default_maximized` and keeps its
      // geometry. What has to shrink is the call itself.
      const fullBox = await callPanel.boundingBox();
      expect(fullBox).toBeTruthy();
      const windowBox = await callWindow.boundingBox();
      expect(windowBox).toBeTruthy();
      expect(fullBox!.width).toBeLessThan(windowBox!.width);
      await expect
        .poll(() => remoteVideoIdentity(aliceSession))
        .toEqual(initialRemote);

      await miniToggle().click();
      await expect(callPanel).toHaveAttribute("data-call-mini", "false");
      await expectP2PCallHasNoInnerHeader(aliceSession);
      await expect
        .poll(() => remoteVideoIdentity(aliceSession))
        .toEqual(initialRemote);

      // "Open stats" is a shortcut the call panel offers when it is mini or
      // carries its own header; the console's own nav is how the section is
      // reached with the full console on screen.
      await aliceSession.getByTestId("p2p-console-nav-stats").click();
      const statsSection = aliceSession.getByTestId(
        "p2p-console-section-stats",
      );
      await expect(statsSection).toBeVisible();

      const callBox = await callWindow.boundingBox();
      expect(callBox).toBeTruthy();
      expect(callBox!.width).toBeGreaterThanOrEqual(400);
      await expect
        .poll(() => remoteVideoLive(aliceSession), { timeout: 10_000 })
        .toBe(true);

      await callWindow.locator('[data-window-control="maximize"]').click();
      await expect(callWindow).toHaveClass(/desktop-window--maximized/);
      await expect(statsSection).toBeVisible();
      await expect
        .poll(() => remoteVideoIdentity(aliceSession))
        .toEqual(initialRemote);

      await callWindow.locator('[data-window-control="restore"]').click();
      await expect(callWindow).not.toHaveClass(/desktop-window--maximized/);
      await expect
        .poll(() => remoteVideoIdentity(aliceSession))
        .toEqual(initialRemote);

      // A phone short enough that the stats section really overflows. The
      // session has the whole window now — no chat chrome above it — so a
      // taller viewport leaves the section fitting, and a scroll test on a box
      // that does not scroll proves nothing.
      await aliceSession.setViewportSize({ width: 390, height: 568 });
      await openP2PConsoleSection(aliceSession, "stats");
      await expectScrollStableAcrossStatsTick(
        aliceSession,
        "p2p-console-section-stats",
      );
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
      await bob.page.getByTestId("p2p-peer-decline").click();

      await alice.chat.expectMessageVisible("declined the P2P invite");
      await expect(statusBarP2P(alice.page)).toBeHidden();
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test("the inviter cancels a pending invite from the room they entered", async ({
    browser,
  }) => {
    const alice = await newP2PUser(browser, "cpe");
    const bob = await newP2PUser(browser, "cpf");

    try {
      const aliceSession = await sendP2PInvite(alice, bob.nick);
      await expect(statusBarP2P(alice.page)).toContainText("in another tab");

      // Cancel from the room the card led to. The chat has no control over a
      // session it is not holding, so P7's button lives where the session is.
      await aliceSession.getByTestId("p2p-room-cancel").click();
      await expect(statusBarP2P(alice.page)).toBeHidden();
      await alice.chat.expectMessageVisible("cancelled the P2P invite");
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });
});

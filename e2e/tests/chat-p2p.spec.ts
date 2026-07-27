import { test, expect, Page } from "@playwright/test";
import { mkdirSync } from "node:fs";
import {
  newP2PUser,
  closeP2PUsers,
  type P2PTestUser,
} from "../helpers/p2pFlows";

/**
 * In-chat P2P sessions (docs/plans/p2p-fluxo-como-conferencia.md): PM header
 * entry, accept/decline in place, the status-bar session area, and the real
 * WebRTC link established WITHOUT ever leaving /chat.
 */

function statusBarP2P(page: Page) {
  return page.getByTestId("status-bar-p2p");
}

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

async function sendP2PInvite(user: P2PTestUser, targetNick: string) {
  await user.chat.sendMessage(`/p2p ${targetNick}`);
  await expect(user.page.getByTestId("p2p-setup-accept")).toBeVisible();
  await expect(user.page.getByTestId("p2p-setup-form")).toContainText(
    "Send invite",
  );
  await user.page.getByTestId("p2p-setup-accept").click();
  await expect(user.page.getByTestId("p2p-call-window")).toBeVisible();
  await expect(user.page.getByTestId("p2p-session-console")).toBeVisible();
  await expect(user.page.getByTestId("p2p-call-disconnected")).toContainText(
    "Waiting for peer",
  );
  await expect(user.page.getByTestId("p2p-webrtc")).toBeHidden();
}

async function acceptP2PInvite(
  page: Page,
  options: { audio?: boolean; video?: boolean; turnOnly?: boolean } = {},
) {
  await expect(page.getByTestId("p2p-peer-entry")).toHaveAttribute(
    "data-p2p-state",
    "pending",
  );
  await expect(page.getByTestId("session-card-accept")).toHaveCount(0);
  await expect(page.getByTestId("session-card-decline")).toHaveCount(0);
  await page.getByTestId("p2p-peer-join").click();
  await expect(page.getByTestId("p2p-setup-accept")).toBeVisible();
  await expect(page.getByTestId("p2p-setup-preview")).toBeVisible();

  if (options.audio !== undefined) {
    const audioToggle = page.getByTestId("p2p-setup-audio");
    await audioToggle.setChecked(options.audio);
    if (options.audio) {
      await expect(audioToggle).toBeChecked();
    } else {
      await expect(audioToggle).not.toBeChecked();
    }
  }

  if (options.video !== undefined) {
    const videoToggle = page.getByTestId("p2p-setup-video");
    await videoToggle.setChecked(options.video);
    if (options.video) {
      await expect(videoToggle).toBeChecked();
    } else {
      await expect(videoToggle).not.toBeChecked();
    }
  }

  if (options.turnOnly !== undefined) {
    await page.getByTestId("p2p-setup-advanced").locator("summary").click();
    await expect(page.getByTestId("p2p-setup-turn-only")).toBeEnabled();
    await page.getByTestId("p2p-setup-turn-only").setChecked(options.turnOnly);
  }

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

async function remoteVideoHasVisibleFrame(page: Page) {
  return page.evaluate(() => {
    const video = document.getElementById(
      "lobby-remote-video",
    ) as HTMLVideoElement | null;

    if (
      !video ||
      video.readyState < HTMLMediaElement.HAVE_CURRENT_DATA ||
      video.videoWidth === 0 ||
      video.videoHeight === 0
    ) {
      return false;
    }

    const canvas = document.createElement("canvas");
    canvas.width = 32;
    canvas.height = 18;
    const context = canvas.getContext("2d", { willReadFrequently: true });
    if (!context) return false;

    try {
      context.drawImage(video, 0, 0, canvas.width, canvas.height);
      const { data } = context.getImageData(0, 0, canvas.width, canvas.height);
      let visiblePixels = 0;

      for (let index = 0; index < data.length; index += 4) {
        const red = data[index] ?? 0;
        const green = data[index + 1] ?? 0;
        const blue = data[index + 2] ?? 0;

        if (red + green + blue > 45) visiblePixels += 1;
      }

      return visiblePixels > 8;
    } catch {
      return false;
    }
  });
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
  test("accepting from the PM header connects both peers inside the chat", async ({
    browser,
  }) => {
    const alice = await newP2PUser(browser, "callermax", { media: true });
    const bob = await newP2PUser(browser, "peermaxxxx", { media: true });

    try {
      await sendP2PInvite(alice, bob.nick);
      await expect(statusBarP2P(alice.page)).toContainText("waiting for");

      const pendingImage = await alice.page
        .getByTestId("p2p-call-window")
        .screenshot({ path: p2pFlowScreenshot("p2p-pending-console") });
      expect(pendingImage.byteLength).toBeGreaterThan(8_000);

      // Bob receives the PM tab in the background, then accepts from the PM
      // header — no page navigation and no actionable transcript card.
      await bob.chat.expectTabVisible(alice.nick);
      await expect(bob.chat.tab(alice.nick)).toHaveAttribute(
        "data-unread",
        "true",
      );
      await expect(bob.chat.tab(alice.nick)).not.toHaveAttribute(
        "aria-selected",
        "true",
      );
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

      // The session presents itself as one P2P console and the call
      // auto-starts (mic+camera) on BOTH sides.
      for (const page of [alice.page, bob.page]) {
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
        .poll(() => remoteVideoHasVisibleFrame(alice.page), { timeout: 20_000 })
        .toBe(true);
      const connectedImage = await alice.page
        .getByTestId("p2p-call-window")
        .screenshot({ path: p2pFlowScreenshot("p2p-connected-desktop") });
      expect(connectedImage.byteLength).toBeGreaterThan(8_000);

      await alice.page.setViewportSize({ width: 768, height: 1024 });
      await expectP2PConsoleLayoutStable(alice.page);
      await expectMediaSessionHeadersStable(alice.page, "p2p-session-console");
      await alice.page.setViewportSize({ width: 390, height: 844 });
      await expectMobileSectionNavCue(alice.page, "p2p-console-nav");
      await expectP2PConsoleLayoutStable(alice.page);
      await expectMediaSessionHeadersStable(alice.page, "p2p-session-console");
      await expect
        .poll(() => remoteVideoHasVisibleFrame(alice.page), { timeout: 10_000 })
        .toBe(true);
      const mobileImage = await alice.page
        .getByTestId("p2p-call-window")
        .screenshot({ path: p2pFlowScreenshot("p2p-connected-mobile") });
      expect(mobileImage.byteLength).toBeGreaterThan(8_000);
      await alice.page.setViewportSize({ width: 1280, height: 720 });
      await expectP2PConsoleLayoutStable(alice.page);
      await expectMediaSessionHeadersStable(alice.page, "p2p-session-console");

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

      // Ending closes the session console, on both sides.
      for (const page of [alice.page, bob.page]) {
        await expect(page.getByTestId("p2p-call-window")).toBeHidden();
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

      // File transfer over the SAME connection, mid-call: switch to Files
      // inside the session console and send.
      await openP2PConsoleSection(alice.page, "files");
      await expect(alice.page.getByTestId("lobby-file-panel")).toBeVisible();
      await expectP2PConsoleLayoutStable(alice.page);
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

      // A game joins the party on the same connection: switch to Games,
      // propose, accept, play.
      await openP2PConsoleSection(alice.page, "games");
      await expect(alice.page.getByTestId("lobby-game-panel")).toBeVisible();
      await expectP2PConsoleLayoutStable(alice.page);
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
      await expect(alice.page.getByTestId("p2p-setup-accept")).toBeVisible();
      await alice.page
        .getByTestId("p2p-setup-advanced")
        .locator("summary")
        .click();
      test.skip(
        await alice.page.getByTestId("p2p-setup-turn-only").isDisabled(),
        "TURN relay is not configured in this environment.",
      );
      await alice.page.getByTestId("p2p-setup-turn-only").setChecked(true);
      await alice.page.getByTestId("p2p-setup-accept").click();

      await bob.chat.expectTabVisible(alice.nick);
      await bob.chat.switchToTab(alice.nick);
      await acceptP2PInvite(bob.page, { turnOnly: true });

      await expect(statusBarP2P(alice.page)).toContainText(`P2P: ${bob.nick}`, {
        timeout: 30_000,
      });
      await expect(statusBarP2P(bob.page)).toContainText(`P2P: ${alice.nick}`, {
        timeout: 30_000,
      });
      await expect(
        alice.page.getByTestId("status-bar-p2p-relay"),
      ).toBeVisible();
      await expect(bob.page.getByTestId("status-bar-p2p-relay")).toBeVisible();
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
      await sendP2PInvite(alice, bob.nick);
      await bob.chat.expectTabVisible(alice.nick);
      await bob.chat.switchToTab(alice.nick);
      await acceptP2PInvite(bob.page, { audio: false, video: false });

      await expect(statusBarP2P(alice.page)).toContainText(`P2P: ${bob.nick}`, {
        timeout: 20_000,
      });
      await expect(statusBarP2P(bob.page)).toContainText(`P2P: ${alice.nick}`, {
        timeout: 20_000,
      });

      await expect
        .poll(() => remoteVideoLive(bob.page), { timeout: 30_000 })
        .toBe(true);
      await expect
        .poll(() => localP2PTrackEnabled(bob.page, "audio"))
        .toBe(null);
      await expect
        .poll(() => localP2PTrackEnabled(bob.page, "video"))
        .toBe(null);

      await expect(bob.page.getByTestId("p2p-call-kind")).toContainText(
        "Receiving",
      );
      await expect(bob.page.getByTestId("p2p-call-enable-audio")).toBeVisible();
      await expect(bob.page.getByTestId("p2p-call-enable-video")).toBeVisible();
      await expect(bob.page.getByTestId("p2p-call-panel")).toContainText(
        "Recv-only session",
      );

      await bob.page.setViewportSize({ width: 390, height: 844 });
      await expectMobileSectionNavCue(bob.page, "p2p-console-nav");
      await expectP2PConsoleLayoutStable(bob.page);
      await expectMediaSessionHeadersStable(bob.page, "p2p-session-console");
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
      await sendP2PInvite(alice, bob.nick);
      await bob.chat.expectTabVisible(alice.nick);
      await bob.chat.switchToTab(alice.nick);
      await acceptP2PInvite(bob.page, { audio: true, video: false });

      await expect(statusBarP2P(alice.page)).toContainText(`P2P: ${bob.nick}`, {
        timeout: 20_000,
      });
      await expect(statusBarP2P(bob.page)).toContainText(`P2P: ${alice.nick}`, {
        timeout: 20_000,
      });
      await expect(bob.page.getByTestId("p2p-session-console")).toHaveAttribute(
        "data-p2p-media-mode",
        "audio",
      );

      await expect
        .poll(() => remoteVideoLive(bob.page), { timeout: 45_000 })
        .toBe(true);
      await expect
        .poll(() => localP2PTrackEnabled(bob.page, "audio"), {
          timeout: 20_000,
        })
        .toBe(true);
      await expect
        .poll(() => localP2PTrackEnabled(bob.page, "video"))
        .toBe(null);
      await expect(bob.page.getByTestId("p2p-call-kind")).toContainText(
        "Audio",
      );
      await expect(bob.page.getByTestId("p2p-call-toggle-mute")).toBeVisible();
      await expect(bob.page.getByTestId("p2p-call-enable-audio")).toBeHidden();
      await expect(bob.page.getByTestId("p2p-call-enable-video")).toBeVisible();
      await expect(bob.page.getByTestId("p2p-call-toggle-camera")).toBeHidden();
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

      await alice.page.getByTestId("p2p-call-open-stats").click();
      const statsSection = alice.page.getByTestId("p2p-console-section-stats");
      await expect(statsSection).toBeVisible();
      await p2pStatsTab(alice.page, "video").click();

      const videoStats = p2pStatsDetails(alice.page, "video");
      await expect(videoStats).toBeVisible();
      await expect(videoStats.locator("summary")).toContainText("Screen", {
        timeout: 10_000,
      });
      await videoStats.locator("summary").click();
      await expect(videoStats).toContainText("Source");
      await expect(videoStats).toContainText("Screen");

      await openP2PConsoleSection(alice.page, "call");
      await alice.page.getByTestId("p2p-call-screen-share").click();
      await expect(
        alice.page.getByTestId("p2p-call-local-tile"),
      ).toHaveAttribute("data-screen-share", "false");
      await expect(
        bob.page.getByTestId("p2p-call-remote-tile"),
      ).toHaveAttribute("data-peer-screen-share", "false", { timeout: 10_000 });
      await openP2PConsoleSection(alice.page, "stats");
      await p2pStatsTab(alice.page, "video").click();
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

      await reportP2PRecoveryState(bob.page, {
        state: "failed",
        reason: "max_retries_exhausted",
        manual_retry: true,
      });

      const banner = bob.page.getByTestId("p2p-recovery-banner");
      await expect(banner).toBeVisible();
      await expect(banner).toHaveAttribute("data-p2p-recovery-state", "failed");
      await expect(banner).toContainText("Retry");

      await bob.page.getByTestId("p2p-retry-connection").click();
      await expect(bob.page.getByTestId("p2p-call-window")).toBeVisible();
      await expect(bob.page.getByTestId("p2p-session-console")).toBeVisible();
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
      await expectP2PCallHasNoInnerHeader(alice.page);
      await expectP2PSectionScrollHooks(alice.page);

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
      await expectP2PCallHasNoInnerHeader(alice.page);
      await expect
        .poll(() => remoteVideoIdentity(alice.page))
        .toEqual(initialRemote);

      await alice.page.getByTestId("p2p-call-open-stats").click();
      const statsSection = alice.page.getByTestId("p2p-console-section-stats");
      await expect(statsSection).toBeVisible();

      const callBox = await callWindow.boundingBox();
      expect(callBox).toBeTruthy();
      expect(callBox!.width).toBeGreaterThanOrEqual(400);
      await expect
        .poll(() => remoteVideoLive(alice.page), { timeout: 10_000 })
        .toBe(true);

      await callWindow.locator('[data-window-control="maximize"]').click();
      await expect(callWindow).toHaveClass(/desktop-window--maximized/);
      await expect(statsSection).toBeVisible();
      await expect
        .poll(() => remoteVideoIdentity(alice.page))
        .toEqual(initialRemote);

      await callWindow.locator('[data-window-control="restore"]').click();
      await expect(callWindow).not.toHaveClass(/desktop-window--maximized/);
      await expect
        .poll(() => remoteVideoIdentity(alice.page))
        .toEqual(initialRemote);

      await alice.page.setViewportSize({ width: 390, height: 844 });
      await openP2PConsoleSection(alice.page, "stats");
      await expectScrollStableAcrossStatsTick(
        alice.page,
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

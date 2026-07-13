import { test, expect, Page } from "@playwright/test";
import { uniqueChannel } from "../helpers/chatUsers";
import {
  closeGroupCallUsers,
  newGroupCallUser,
} from "../helpers/groupCallUsers";

function groupCallButton(page: Page) {
  return page.getByTestId("group-call-open");
}

function groupCallWindow(page: Page) {
  return page.getByTestId("group-call-window");
}

function groupCallPanel(page: Page) {
  return page.getByTestId("group-call-panel");
}

function groupCallPrejoinDialog(page: Page) {
  return page.locator("#group-call-prejoin-dialog-surface");
}

function groupCallPrejoinJoin(page: Page) {
  return page.getByTestId("group-call-prejoin-join");
}

function groupCallPrejoinCancel(page: Page) {
  return page.getByTestId("group-call-prejoin-cancel");
}

function groupCallPrejoinAudio(page: Page) {
  return page.getByTestId("group-call-prejoin-audio");
}

function groupCallPrejoinVideo(page: Page) {
  return page.getByTestId("group-call-prejoin-video-toggle");
}

function groupCallPrejoinWarning(page: Page) {
  return page.getByTestId("group-call-prejoin-warning");
}

function groupCallPrejoinRetry(page: Page) {
  return page.getByTestId("group-call-prejoin-retry");
}

function groupCallStatsWindow(page: Page) {
  return page.getByTestId("group-call-stats-window");
}

function groupCallLeave(page: Page) {
  return page.getByTestId("group-call-leave");
}

function groupCallAudioToggle(page: Page) {
  return page.getByTestId("group-call-audio-toggle");
}

function groupCallVideoToggle(page: Page) {
  return page.getByTestId("group-call-video-toggle");
}

function groupCallHandToggle(page: Page) {
  return page.getByTestId("group-call-hand-toggle");
}

function groupCallScreenShareToggle(page: Page) {
  return page.getByTestId("group-call-screen-share-toggle");
}

function groupCallMuteAll(page: Page) {
  return page.getByTestId("group-call-mute-all");
}

function groupCallCameraOffAll(page: Page) {
  return page.getByTestId("group-call-camera-off-all");
}

function groupCallLockToggle(page: Page) {
  return page.getByTestId("group-call-lock-toggle");
}

function groupCallRaisedHandQueue(page: Page) {
  return page.getByTestId("group-call-raised-hand-queue");
}

function groupCallConfirmLeave(page: Page) {
  return page.getByTestId("group-call-confirm-dialog-confirm");
}

function groupCallConfirmCancel(page: Page) {
  return page.getByTestId("group-call-confirm-dialog-cancel");
}

function groupCallTaskbarButton(page: Page) {
  return page.getByTestId("group-call-taskbar");
}

function groupCallStatsTaskbarButton(page: Page) {
  return page.getByTestId("group-call-stats-taskbar");
}

function groupCallStatusBar(page: Page) {
  return page.getByTestId("status-bar-group-call");
}

function groupCallChannelBadge(page: Page) {
  return page.getByTestId("group-call-channel-badge");
}

function groupCallChannelPopover(page: Page) {
  return page.getByTestId("group-call-channel-popover");
}

function groupCallChannelPopoverToggle(page: Page) {
  return page.getByTestId("group-call-channel-popover-toggle");
}

function groupCallLayoutGrid(page: Page) {
  return page.getByTestId("group-call-layout-grid");
}

function groupCallLayoutFocus(page: Page) {
  return page.getByTestId("group-call-layout-focus");
}

function groupCallLayoutSpeaker(page: Page) {
  return page.getByTestId("group-call-layout-speaker");
}

function groupCallLayoutSidebar(page: Page) {
  return page.getByTestId("group-call-layout-sidebar");
}

function groupCallSelfViewToggle(page: Page) {
  return page.getByTestId("group-call-self-view-toggle");
}

function groupCallMiniToggle(page: Page) {
  return page.getByTestId("group-call-mini-toggle");
}

function groupCallMiniAudioToggle(page: Page) {
  return page.getByTestId("group-call-mini-audio-toggle");
}

function groupCallMiniVideoToggle(page: Page) {
  return page.getByTestId("group-call-mini-video-toggle");
}

function groupCallMiniExpand(page: Page) {
  return page.getByTestId("group-call-mini-expand");
}

function groupCallMiniLeave(page: Page) {
  return page.getByTestId("group-call-mini-leave");
}

function groupCallDockStats(page: Page) {
  return page.getByTestId("group-call-dock-stats");
}

function groupCallReaction(page: Page, reaction: string) {
  return page.getByTestId(`group-call-reaction-${reaction}`);
}

function groupCallReactionIcon(page: Page, reaction: string) {
  return page.getByTestId(`group-call-reaction-icon-${reaction}`).locator("svg");
}

function groupCallClearFocus(page: Page) {
  return page.getByTestId("group-call-clear-focus");
}

function groupCallRetry(page: Page) {
  return page.getByTestId("group-call-retry");
}

function groupCallError(page: Page) {
  return page.getByTestId("group-call-error");
}

function groupCallWarning(page: Page) {
  return page.getByTestId("group-call-warning");
}

function groupCallWebRTC(page: Page) {
  return page.getByTestId("group-call-webrtc");
}

function groupCallVideoGrid(page: Page) {
  return page.getByTestId("group-call-video-grid");
}

function groupCallLocalTile(page: Page) {
  return page.getByTestId("group-call-local-tile");
}

function remoteVideoTile(page: Page) {
  return page
    .locator('[data-group-call-video-tile][data-local="false"]')
    .first();
}

const remoteTileVideoSelector =
  '[data-group-call-video-tile][data-local="false"] video';

async function remoteVideoLive(page: Page) {
  return page.evaluate((selector) => {
    const videos = Array.from(
      document.querySelectorAll<HTMLVideoElement>(selector),
    );

    return videos.some((video) => {
      const stream = video.srcObject as MediaStream | null;
      const track = stream?.getVideoTracks()[0];

      return !!track && track.readyState === "live";
    });
  }, remoteTileVideoSelector);
}

async function remoteVideoIdentity(page: Page) {
  return page.evaluate((selector) => {
    const video = document.querySelector<HTMLVideoElement>(selector);
    if (!video) return null;

    video.dataset.e2eVideoIdentity ||= `video-${Date.now()}-${Math.random()}`;
    const stream = video.srcObject as MediaStream | null;
    const track = stream?.getVideoTracks()[0];

    return {
      videoIdentity: video.dataset.e2eVideoIdentity,
      streamId: stream?.id || null,
      trackReadyState: track?.readyState || null,
    };
  }, remoteTileVideoSelector);
}

async function remoteLiveVideoCount(page: Page) {
  return page.evaluate((selector) => {
    const videos = Array.from(
      document.querySelectorAll<HTMLVideoElement>(selector),
    );

    return videos.filter((video) => {
      const stream = video.srcObject as MediaStream | null;
      const track = stream?.getVideoTracks()[0];

      return !!track && track.readyState === "live";
    }).length;
  }, remoteTileVideoSelector);
}

async function localTrackEnabled(page: Page, kind: "audio" | "video") {
  return page.evaluate((trackKind) => {
    const video = document.querySelector<HTMLVideoElement>(
      "[data-group-call-local-video]",
    );
    const stream = video?.srcObject as MediaStream | null;
    const tracks =
      trackKind === "audio"
        ? stream?.getAudioTracks()
        : stream?.getVideoTracks();
    const track = tracks?.[0];

    return track ? track.enabled : null;
  }, kind);
}

function participantRow(page: Page, nickname: string) {
  return page.locator("[data-group-call-participant]", {
    hasText: nickname,
  });
}

function participantPinButton(page: Page, nickname: string) {
  return participantRow(page, nickname).getByRole("button", {
    name: /Pin participant|Unpin participant/,
  });
}

function participantReactionBadge(page: Page, nickname: string) {
  return participantRow(page, nickname).locator(
    '[data-testid^="group-call-participant-reaction-"]',
  );
}

async function participantIdForNickname(page: Page, nickname: string) {
  const testId = await participantRow(page, nickname).getAttribute(
    "data-testid",
  );
  return testId?.replace("group-call-participant-", "") || null;
}

function participantCameraModerationButton(page: Page, nickname: string) {
  return participantRow(page, nickname).getByRole("button", {
    name: /Turn participant camera off|Allow participant camera/,
  });
}

function participantScreenModerationButton(page: Page, nickname: string) {
  return participantRow(page, nickname).getByRole("button", {
    name: /Stop participant screen sharing|Allow participant screen sharing/,
  });
}

function participantVideoModeratedIndicator(page: Page, nickname: string) {
  return participantRow(page, nickname).locator(
    '[data-group-call-participant-video][data-media-moderated="true"]',
  );
}

function participantScreenModeratedIndicator(page: Page, nickname: string) {
  return participantRow(page, nickname).locator(
    '[data-group-call-participant-screen][data-media-moderated="true"]',
  );
}

function participantAllowSpeakButton(page: Page, nickname: string) {
  return page.getByRole("button", {
    name: new RegExp(`Allow ${nickname} to speak`),
  });
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
  await expect(groupCallButton(user.page)).toBeEnabled();
}

async function joinGroupCall(
  page: Page,
  options: { audio?: boolean; video?: boolean } = {},
) {
  await groupCallButton(page).click();
  await expect(groupCallPrejoinDialog(page)).toBeVisible();

  if (options.audio !== undefined) {
    await groupCallPrejoinAudio(page).setChecked(options.audio);
  }

  if (options.video !== undefined) {
    await groupCallPrejoinVideo(page).setChecked(options.video);
  }

  await groupCallPrejoinJoin(page).click();
}

async function expectGroupCallLayoutStable(page: Page) {
  const metrics = await groupCallWindow(page).evaluate((windowElement) => {
    const windowRect = windowElement.getBoundingClientRect();
    const overflowElements: string[] = [];
    const horizontalScrollElements: string[] = [];

    for (const element of Array.from(
      windowElement.querySelectorAll<HTMLElement>(
        [
          '[data-testid="group-call-panel"]',
          '[data-testid="group-call-video-grid"]',
          '[data-testid="group-call-local-tile"]',
          '[data-testid="group-call-reactions"]',
          '[data-testid="group-call-participants"]',
        ].join(","),
      ),
    )) {
      const rect = element.getBoundingClientRect();
      const testId = element.dataset.testid || element.id || element.tagName;

      if (
        rect.left < windowRect.left - 1 ||
        rect.right > windowRect.right + 1 ||
        rect.top < windowRect.top - 1 ||
        rect.bottom > windowRect.bottom + 1
      ) {
        overflowElements.push(testId);
      }

      if (element.scrollWidth > element.clientWidth + 2) {
        horizontalScrollElements.push(testId);
      }
    }

    return {
      overflowElements,
      horizontalScrollElements,
      windowWidth: Math.round(windowRect.width),
      windowHeight: Math.round(windowRect.height),
      viewportWidth: window.innerWidth,
      viewportHeight: window.innerHeight,
    };
  });

  expect(metrics.windowWidth).toBeGreaterThan(240);
  expect(metrics.windowHeight).toBeGreaterThan(180);
  expect(metrics.overflowElements).toEqual([]);
  expect(metrics.horizontalScrollElements).toEqual([]);
}

async function expectPrejoinDialogLayoutStable(page: Page) {
  const metrics = await groupCallPrejoinDialog(page).evaluate((surface) => {
    const surfaceRect = surface.getBoundingClientRect();
    const overflowElements: string[] = [];

    for (const element of Array.from(
      surface.querySelectorAll<HTMLElement>(
        [
          '[data-testid="group-call-prejoin-form"]',
          '[data-testid="group-call-prejoin-preview"]',
          '[data-testid="group-call-prejoin-audio-input"]',
          '[data-testid="group-call-prejoin-video-input"]',
          '[data-testid="group-call-prejoin-audio-output"]',
          '[data-testid="group-call-prejoin-layout"]',
          '[data-testid="group-call-prejoin-self-view"]',
          "section",
          "label",
          "select",
        ].join(","),
      ),
    )) {
      const rect = element.getBoundingClientRect();
      if (rect.width === 0 || rect.height === 0) continue;

      if (
        rect.left < surfaceRect.left - 1 ||
        rect.right > surfaceRect.right + 1
      ) {
        overflowElements.push(
          element.dataset.testid || element.id || element.tagName,
        );
      }
    }

    return {
      bodyClientWidth: document.documentElement.clientWidth,
      bodyScrollWidth: document.documentElement.scrollWidth,
      overflowElements,
      surfaceClientWidth: surface.clientWidth,
      surfaceScrollWidth: surface.scrollWidth,
    };
  });

  expect(metrics.overflowElements).toEqual([]);
  expect(metrics.surfaceScrollWidth).toBeLessThanOrEqual(
    metrics.surfaceClientWidth + 2,
  );
  expect(metrics.bodyScrollWidth).toBeLessThanOrEqual(
    metrics.bodyClientWidth + 2,
  );
}

async function participantMediaEnabled(
  page: Page,
  nickname: string,
  kind: "audio" | "video",
) {
  const attr = kind === "audio" ? "data-media-audio" : "data-media-video";
  return participantRow(page, nickname).getAttribute(attr);
}

async function storedPrejoinPreference(page: Page, key: "audio" | "video") {
  return page.evaluate((preferenceKey) => {
    const storageKey = Object.keys(window.localStorage).find((candidate) =>
      candidate.startsWith("rhc:group-call:prejoin:"),
    );

    if (!storageKey) return null;
    const preferences = JSON.parse(
      window.localStorage.getItem(storageKey) || "{}",
    );
    return preferences[preferenceKey] ?? null;
  }, key);
}

async function denyUserMedia(page: Page) {
  await page.evaluate(() => {
    Object.defineProperty(navigator.mediaDevices, "getUserMedia", {
      configurable: true,
      value: async () => {
        throw new DOMException("Permission denied", "NotAllowedError");
      },
    });
  });
}

async function pressConferenceShortcut(page: Page, key: string) {
  await page.keyboard.down("Control");
  await page.keyboard.down("Shift");
  try {
    await page.keyboard.press(key);
  } finally {
    await page.keyboard.up("Shift");
    await page.keyboard.up("Control");
  }
}

async function withConferenceShortcutHeld(
  page: Page,
  key: string,
  assertion: () => Promise<void>,
) {
  await page.keyboard.down("Control");
  await page.keyboard.down("Shift");
  await page.keyboard.down(key);
  try {
    await assertion();
  } finally {
    await page.keyboard.up(key);
    await page.keyboard.up("Shift");
    await page.keyboard.up("Control");
  }
}

test.describe("Channel group calls", () => {
  test("pre-join dialog keeps preview and controls inside the window", async ({
    browser,
  }) => {
    const alice = await newGroupCallUser(browser, "gclayout");
    const channel = uniqueChannel("gcalllayout");

    try {
      await alice.page.setViewportSize({ width: 1280, height: 720 });
      await joinChannel(alice, channel);

      await groupCallButton(alice.page).click();
      await expect(groupCallPrejoinDialog(alice.page)).toBeVisible();
      await expectPrejoinDialogLayoutStable(alice.page);

      await alice.page.setViewportSize({ width: 390, height: 844 });
      await expect(groupCallPrejoinDialog(alice.page)).toBeVisible();
      await expectPrejoinDialogLayoutStable(alice.page);
    } finally {
      await closeGroupCallUsers([alice]);
    }
  });

  test("conference visual polish renders SVG reactions and captures desktop/mobile windows", async ({
    browser,
  }) => {
    const alice = await newGroupCallUser(browser, "gcvpa");
    const channel = uniqueChannel("gcallvisual");

    try {
      await alice.page.setViewportSize({ width: 1280, height: 720 });
      await joinChannel(alice, channel);

      await joinGroupCall(alice.page, { audio: false, video: false });
      await expect(groupCallWindow(alice.page)).toBeVisible();
      await expect(groupCallPanel(alice.page)).toContainText(
        "Waiting for participants",
      );
      await expect(groupCallPanel(alice.page)).toContainText(
        "Receive-only mode",
      );

      for (const reaction of [
        "heart",
        "thumbs_up",
        "clap",
        "laugh",
        "wow",
      ]) {
        await expect(groupCallReactionIcon(alice.page, reaction)).toHaveCount(
          1,
        );
        await expect(groupCallReaction(alice.page, reaction)).not.toContainText(
          /👍|👏|😄|✨/,
        );
      }

      const desktopImage = await groupCallWindow(alice.page).screenshot();
      expect(desktopImage.byteLength).toBeGreaterThan(8_000);
      await expectGroupCallLayoutStable(alice.page);

      await alice.page.setViewportSize({ width: 390, height: 844 });
      await expect(groupCallWindow(alice.page)).toBeVisible();
      await expect(groupCallPanel(alice.page)).toBeVisible();

      const mobileImage = await groupCallWindow(alice.page).screenshot();
      expect(mobileImage.byteLength).toBeGreaterThan(8_000);
      await expectGroupCallLayoutStable(alice.page);
    } finally {
      await closeGroupCallUsers([alice]);
    }
  });

  test("two identified channel users join the same SFU call and exchange video", async ({
    browser,
  }) => {
    const alice = await newGroupCallUser(browser, "gca");
    const bob = await newGroupCallUser(browser, "gcb");
    const channel = uniqueChannel("gcall");

    try {
      for (const user of [alice, bob]) {
        await user.chat.sendMessage(`/join ${channel}`);
        await user.chat.expectTabVisible(channel);
        await user.chat.switchToTab(channel);
        await expect(groupCallButton(user.page)).toBeEnabled();
      }

      await joinGroupCall(alice.page);
      await expect(groupCallWindow(alice.page)).toBeVisible();
      await expect(groupCallTaskbarButton(alice.page)).toBeVisible();
      await expect(groupCallTaskbarButton(alice.page)).toContainText(channel);
      await expect(groupCallStatusBar(alice.page)).toContainText("Call:");
      await expect(alice.page.getByTestId("group-call-webrtc")).toBeVisible();

      await expect(groupCallChannelBadge(bob.page)).toBeVisible();
      await expect(groupCallChannelBadge(bob.page)).toContainText("Live");
      await expect(groupCallChannelBadge(bob.page)).toContainText("1/100");
      await groupCallChannelPopoverToggle(bob.page).click();
      await expect(groupCallChannelPopover(bob.page)).toBeVisible();
      await expect(groupCallChannelPopover(bob.page)).toContainText(alice.nick);
      await expect(groupCallChannelPopover(bob.page)).toContainText("Join");

      await joinGroupCall(bob.page);
      await expect(groupCallWindow(bob.page)).toBeVisible();
      await expect(groupCallTaskbarButton(bob.page)).toBeVisible();
      await expect(groupCallTaskbarButton(bob.page)).toContainText(channel);
      await expect(groupCallStatusBar(bob.page)).toContainText("Call:");
      await expect(bob.page.getByTestId("group-call-webrtc")).toBeVisible();
      await expect(groupCallChannelBadge(alice.page)).toContainText("2/100");

      await expect
        .poll(() => remoteVideoLive(alice.page), { timeout: 30_000 })
        .toBe(true);
      await expect
        .poll(() => remoteVideoLive(bob.page), { timeout: 30_000 })
        .toBe(true);

      await expect(
        alice.page.getByTestId("group-call-participants"),
      ).toContainText(bob.nick);
      await expect(
        bob.page.getByTestId("group-call-participants"),
      ).toContainText(alice.nick);

      await expect(groupCallStatsTaskbarButton(alice.page)).toBeVisible();
      await groupCallStatsTaskbarButton(alice.page).click();
      await expect(groupCallStatsWindow(alice.page)).toBeVisible();
      await expect(groupCallStatsWindow(alice.page)).toContainText(
        "Server runtime",
      );
      await expect(groupCallStatsWindow(alice.page)).toContainText(
        "Browser connection",
      );
      await expect(groupCallStatsWindow(alice.page)).toContainText(
        "Peer connections",
      );

      await groupCallStatsWindow(alice.page)
        .locator('[data-window-control="close"]')
        .click();
      await expect(groupCallConfirmLeave(alice.page)).toBeVisible();
      await expect(
        alice.page.getByTestId("group-call-confirm-dialog"),
      ).toContainText("Closing this window leaves");
      await groupCallConfirmCancel(alice.page).click();
      await expect(groupCallStatsWindow(alice.page)).toBeVisible();
      await groupCallStatusBar(alice.page).click();
      await expect(groupCallWindow(alice.page)).toBeVisible();

      await expect
        .poll(() => localTrackEnabled(alice.page, "audio"))
        .toBe(true);
      await expect
        .poll(() => localTrackEnabled(alice.page, "video"))
        .toBe(true);
      await expect
        .poll(() => participantMediaEnabled(bob.page, alice.nick, "audio"))
        .toBe("true");
      await expect
        .poll(() => participantMediaEnabled(bob.page, alice.nick, "video"))
        .toBe("true");

      await groupCallAudioToggle(alice.page).click();
      await expect(groupCallAudioToggle(alice.page)).toHaveAttribute(
        "aria-pressed",
        "false",
      );
      await expect
        .poll(() => localTrackEnabled(alice.page, "audio"))
        .toBe(false);
      await expect
        .poll(() => participantMediaEnabled(bob.page, alice.nick, "audio"), {
          timeout: 10_000,
        })
        .toBe("false");

      await groupCallAudioToggle(alice.page).click();
      await expect(groupCallAudioToggle(alice.page)).toHaveAttribute(
        "aria-pressed",
        "true",
      );
      await expect
        .poll(() => localTrackEnabled(alice.page, "audio"))
        .toBe(true);
      await expect
        .poll(() => participantMediaEnabled(bob.page, alice.nick, "audio"), {
          timeout: 10_000,
        })
        .toBe("true");

      await groupCallVideoToggle(alice.page).click();
      await expect(groupCallVideoToggle(alice.page)).toHaveAttribute(
        "aria-pressed",
        "false",
      );
      await expect
        .poll(() => localTrackEnabled(alice.page, "video"))
        .toBe(false);
      await expect
        .poll(() => participantMediaEnabled(bob.page, alice.nick, "video"), {
          timeout: 10_000,
        })
        .toBe("false");

      await groupCallVideoToggle(alice.page).click();
      await expect(groupCallVideoToggle(alice.page)).toHaveAttribute(
        "aria-pressed",
        "true",
      );
      await expect
        .poll(() => localTrackEnabled(alice.page, "video"))
        .toBe(true);
      await expect
        .poll(() => participantMediaEnabled(bob.page, alice.nick, "video"), {
          timeout: 10_000,
        })
        .toBe("true");

      await groupCallLeave(alice.page).click();
      await expect(groupCallConfirmLeave(alice.page)).toBeVisible();
      await groupCallConfirmLeave(alice.page).click();
      await expect(groupCallWindow(alice.page)).toBeHidden();
      await expect(groupCallTaskbarButton(alice.page)).toBeHidden();
      await expect(groupCallStatusBar(alice.page)).toBeHidden();
      await expect(
        bob.page.getByTestId("group-call-participants"),
      ).not.toContainText(alice.nick, { timeout: 10_000 });
    } finally {
      await closeGroupCallUsers([alice, bob]);
    }
  });

  test("conference keyboard shortcuts toggle real media, layout, focus, and leave confirmation", async ({
    browser,
  }) => {
    const alice = await newGroupCallUser(browser, "gck");
    const bob = await newGroupCallUser(browser, "gcl");
    const channel = uniqueChannel("gkeys");

    try {
      for (const user of [alice, bob]) {
        await joinChannel(user, channel);
      }

      await joinGroupCall(alice.page);
      await joinGroupCall(bob.page);
      await expect(groupCallWindow(alice.page)).toBeVisible();
      await expect(groupCallWindow(bob.page)).toBeVisible();

      await expect
        .poll(() => remoteVideoLive(alice.page), { timeout: 30_000 })
        .toBe(true);
      await expect
        .poll(() => remoteVideoLive(bob.page), { timeout: 30_000 })
        .toBe(true);

      await expect
        .poll(() => localTrackEnabled(alice.page, "audio"))
        .toBe(true);
      await expect
        .poll(() => localTrackEnabled(alice.page, "video"))
        .toBe(true);

      await groupCallLocalTile(alice.page).focus();
      await expect(groupCallLocalTile(alice.page)).toBeFocused();
      await pressConferenceShortcut(alice.page, "ArrowUp");
      await expect(groupCallAudioToggle(alice.page)).toHaveAttribute(
        "aria-pressed",
        "false",
      );
      await expect
        .poll(() => localTrackEnabled(alice.page, "audio"))
        .toBe(false);
      await expect
        .poll(() => participantMediaEnabled(bob.page, alice.nick, "audio"), {
          timeout: 10_000,
        })
        .toBe("false");

      await withConferenceShortcutHeld(alice.page, "KeyZ", async () => {
        await expect
          .poll(() => localTrackEnabled(alice.page, "audio"))
          .toBe(true);
        await expect
          .poll(() => participantMediaEnabled(bob.page, alice.nick, "audio"), {
            timeout: 10_000,
          })
          .toBe("true");
      });
      await expect
        .poll(() => localTrackEnabled(alice.page, "audio"))
        .toBe(false);
      await expect
        .poll(() => participantMediaEnabled(bob.page, alice.nick, "audio"), {
          timeout: 10_000,
        })
        .toBe("false");

      await pressConferenceShortcut(alice.page, "ArrowUp");
      await expect(groupCallAudioToggle(alice.page)).toHaveAttribute(
        "aria-pressed",
        "true",
      );
      await expect
        .poll(() => localTrackEnabled(alice.page, "audio"))
        .toBe(true);

      await pressConferenceShortcut(alice.page, "ArrowLeft");
      await expect(groupCallVideoToggle(alice.page)).toHaveAttribute(
        "aria-pressed",
        "false",
      );
      await expect
        .poll(() => localTrackEnabled(alice.page, "video"))
        .toBe(false);
      await expect
        .poll(() => participantMediaEnabled(bob.page, alice.nick, "video"), {
          timeout: 10_000,
        })
        .toBe("false");

      await pressConferenceShortcut(alice.page, "ArrowLeft");
      await expect(groupCallVideoToggle(alice.page)).toHaveAttribute(
        "aria-pressed",
        "true",
      );
      await expect
        .poll(() => localTrackEnabled(alice.page, "video"))
        .toBe(true);

      await pressConferenceShortcut(alice.page, "ArrowRight");
      await expect(groupCallWebRTC(alice.page)).toHaveAttribute(
        "data-layout-mode",
        "grid",
      );

      await pressConferenceShortcut(alice.page, "ArrowDown");
      await expect(groupCallWebRTC(alice.page)).toHaveAttribute(
        "data-layout-mode",
        "focus",
      );
      await expect(remoteVideoTile(alice.page)).toHaveAttribute(
        "data-focused",
        "true",
      );

      await pressConferenceShortcut(alice.page, "KeyQ");
      await expect(groupCallConfirmLeave(alice.page)).toBeVisible();
      await groupCallConfirmCancel(alice.page).click();
      await expect(groupCallWindow(alice.page)).toBeVisible();
    } finally {
      await closeGroupCallUsers([alice, bob]);
    }
  });

  test("pre-join can enter with microphone and camera disabled", async ({
    browser,
  }) => {
    const alice = await newGroupCallUser(browser, "gcpja");
    const bob = await newGroupCallUser(browser, "gcpjb");
    const channel = uniqueChannel("gcallpj");

    try {
      for (const user of [alice, bob]) {
        await joinChannel(user, channel);
      }

      await groupCallButton(alice.page).click();
      await expect(groupCallPrejoinDialog(alice.page)).toBeVisible();
      await groupCallPrejoinAudio(alice.page).setChecked(false);
      await groupCallPrejoinVideo(alice.page).setChecked(false);
      await expect
        .poll(() => storedPrejoinPreference(alice.page, "audio"))
        .toBe(false);
      await expect
        .poll(() => storedPrejoinPreference(alice.page, "video"))
        .toBe(false);
      await groupCallPrejoinCancel(alice.page).click();
      await expect(groupCallPrejoinDialog(alice.page)).toBeHidden();

      await groupCallButton(alice.page).click();
      await expect(groupCallPrejoinDialog(alice.page)).toBeVisible();
      await expect(groupCallPrejoinAudio(alice.page)).not.toBeChecked();
      await expect(groupCallPrejoinVideo(alice.page)).not.toBeChecked();
      await groupCallPrejoinJoin(alice.page).click();

      await expect(groupCallWindow(alice.page)).toBeVisible();
      await expect(groupCallWebRTC(alice.page)).toHaveAttribute(
        "data-audio",
        "false",
      );
      await expect(groupCallWebRTC(alice.page)).toHaveAttribute(
        "data-video",
        "false",
      );
      await expect
        .poll(() => localTrackEnabled(alice.page, "audio"))
        .toBe(null);
      await expect
        .poll(() => localTrackEnabled(alice.page, "video"))
        .toBe(null);

      await joinGroupCall(bob.page);
      await expect(groupCallWindow(bob.page)).toBeVisible();

      await expect
        .poll(() => participantMediaEnabled(bob.page, alice.nick, "audio"), {
          timeout: 10_000,
        })
        .toBe("false");
      await expect
        .poll(() => participantMediaEnabled(bob.page, alice.nick, "video"), {
          timeout: 10_000,
        })
        .toBe("false");
    } finally {
      await closeGroupCallUsers([alice, bob]);
    }
  });

  test("pre-join permission denial can retry and still enter receive-only", async ({
    browser,
  }) => {
    const alice = await newGroupCallUser(browser, "gcpda");
    const channel = uniqueChannel("gcallperm");

    try {
      await joinChannel(alice, channel);
      await denyUserMedia(alice.page);

      await groupCallButton(alice.page).click();
      await expect(groupCallPrejoinDialog(alice.page)).toBeVisible();
      await expect(groupCallPrejoinWarning(alice.page)).toBeVisible();
      await expect(groupCallPrejoinWarning(alice.page)).toContainText(
        /permission|microphone|camera/i,
      );

      await groupCallPrejoinRetry(alice.page).click();
      await expect(groupCallPrejoinWarning(alice.page)).toBeVisible();

      await groupCallPrejoinAudio(alice.page).setChecked(false);
      await groupCallPrejoinVideo(alice.page).setChecked(false);
      await groupCallPrejoinJoin(alice.page).click();

      await expect(groupCallWindow(alice.page)).toBeVisible();
      await expect(groupCallPanel(alice.page)).toContainText(
        "Receive-only mode",
      );
      await expect(groupCallWebRTC(alice.page)).toHaveAttribute(
        "data-audio",
        "false",
      );
      await expect(groupCallWebRTC(alice.page)).toHaveAttribute(
        "data-video",
        "false",
      );
      await expect.poll(() => localTrackEnabled(alice.page, "audio")).toBe(null);
      await expect.poll(() => localTrackEnabled(alice.page, "video")).toBe(null);
    } finally {
      await closeGroupCallUsers([alice]);
    }
  });

  test("moderator camera-off disables the target local video track until released", async ({
    browser,
  }) => {
    const alice = await newGroupCallUser(browser, "gcmva");
    const bob = await newGroupCallUser(browser, "gcmvb");
    const channel = uniqueChannel("gcallcammod");

    try {
      for (const user of [alice, bob]) {
        await joinChannel(user, channel);
      }

      await joinGroupCall(alice.page);
      await expect(groupCallWindow(alice.page)).toBeVisible();

      await joinGroupCall(bob.page);
      await expect(groupCallWindow(bob.page)).toBeVisible();

      await expect
        .poll(() => remoteVideoLive(alice.page), { timeout: 30_000 })
        .toBe(true);
      await expect.poll(() => localTrackEnabled(bob.page, "video")).toBe(true);
      await expect
        .poll(() => participantMediaEnabled(alice.page, bob.nick, "video"), {
          timeout: 10_000,
        })
        .toBe("true");

      await participantCameraModerationButton(alice.page, bob.nick).click();

      await expect
        .poll(() => localTrackEnabled(bob.page, "video"), { timeout: 10_000 })
        .toBe(false);
      await expect
        .poll(() => participantMediaEnabled(alice.page, bob.nick, "video"), {
          timeout: 10_000,
        })
        .toBe("false");
      await expect(
        participantVideoModeratedIndicator(alice.page, bob.nick),
      ).toBeVisible();

      await groupCallVideoToggle(bob.page).click();
      await expect
        .poll(() => localTrackEnabled(bob.page, "video"), { timeout: 10_000 })
        .toBe(false);
      await expect(groupCallVideoToggle(bob.page)).toHaveAttribute(
        "aria-pressed",
        "false",
      );

      await participantCameraModerationButton(alice.page, bob.nick).click();

      await expect
        .poll(() => localTrackEnabled(bob.page, "video"), { timeout: 10_000 })
        .toBe(true);
      await expect
        .poll(() => participantMediaEnabled(alice.page, bob.nick, "video"), {
          timeout: 10_000,
        })
        .toBe("true");
      await expect(
        participantVideoModeratedIndicator(alice.page, bob.nick),
      ).toBeHidden();
    } finally {
      await closeGroupCallUsers([alice, bob]);
    }
  });

  test("bulk moderation mutes and turns off cameras for lower-ranked participants", async ({
    browser,
  }) => {
    const alice = await newGroupCallUser(browser, "gcbma");
    const bob = await newGroupCallUser(browser, "gcbmb");
    const carol = await newGroupCallUser(browser, "gcbmc");
    const channel = uniqueChannel("gcallbulkmod");

    try {
      for (const user of [alice, bob, carol]) {
        await joinChannel(user, channel);
      }

      await joinGroupCall(alice.page);
      await expect(groupCallWindow(alice.page)).toBeVisible();
      await joinGroupCall(bob.page);
      await expect(groupCallWindow(bob.page)).toBeVisible();
      await joinGroupCall(carol.page);
      await expect(groupCallWindow(carol.page)).toBeVisible();

      await expect
        .poll(() => remoteLiveVideoCount(alice.page), { timeout: 30_000 })
        .toBe(2);
      await expect
        .poll(() => localTrackEnabled(alice.page, "audio"))
        .toBe(true);
      await expect.poll(() => localTrackEnabled(bob.page, "audio")).toBe(true);
      await expect
        .poll(() => localTrackEnabled(carol.page, "audio"))
        .toBe(true);

      await groupCallMuteAll(alice.page).click();
      await expect(
        alice.page.getByTestId("group-call-confirm-dialog"),
      ).toContainText("Mute all lower-ranked participants");
      await groupCallConfirmLeave(alice.page).click();

      await expect
        .poll(() => localTrackEnabled(alice.page, "audio"), { timeout: 10_000 })
        .toBe(true);
      await expect
        .poll(() => localTrackEnabled(bob.page, "audio"), { timeout: 10_000 })
        .toBe(false);
      await expect
        .poll(() => localTrackEnabled(carol.page, "audio"), { timeout: 10_000 })
        .toBe(false);
      await expect
        .poll(() => participantMediaEnabled(alice.page, bob.nick, "audio"), {
          timeout: 10_000,
        })
        .toBe("false");
      await expect
        .poll(() => participantMediaEnabled(alice.page, carol.nick, "audio"), {
          timeout: 10_000,
        })
        .toBe("false");

      await groupCallAudioToggle(bob.page).click();
      await expect
        .poll(() => localTrackEnabled(bob.page, "audio"), { timeout: 10_000 })
        .toBe(false);

      await groupCallCameraOffAll(alice.page).click();
      await expect(
        alice.page.getByTestId("group-call-confirm-dialog"),
      ).toContainText("Turn off cameras for all lower-ranked participants");
      await groupCallConfirmLeave(alice.page).click();

      await expect
        .poll(() => localTrackEnabled(alice.page, "video"), { timeout: 10_000 })
        .toBe(true);
      await expect
        .poll(() => localTrackEnabled(bob.page, "video"), { timeout: 10_000 })
        .toBe(false);
      await expect
        .poll(() => localTrackEnabled(carol.page, "video"), { timeout: 10_000 })
        .toBe(false);
      await expect(
        participantVideoModeratedIndicator(alice.page, bob.nick),
      ).toBeVisible();
      await expect(
        participantVideoModeratedIndicator(alice.page, carol.nick),
      ).toBeVisible();
    } finally {
      await closeGroupCallUsers([alice, bob, carol]);
    }
  });

  test("request to speak lets a muted participant ask and moderator allow audio", async ({
    browser,
  }) => {
    const alice = await newGroupCallUser(browser, "gcrha");
    const bob = await newGroupCallUser(browser, "gcrhb");
    const channel = uniqueChannel("gcallraisehand");

    try {
      for (const user of [alice, bob]) {
        await joinChannel(user, channel);
      }

      await joinGroupCall(alice.page);
      await expect(groupCallWindow(alice.page)).toBeVisible();
      await joinGroupCall(bob.page);
      await expect(groupCallWindow(bob.page)).toBeVisible();

      await expect
        .poll(() => remoteVideoLive(alice.page), { timeout: 30_000 })
        .toBe(true);
      await expect.poll(() => localTrackEnabled(bob.page, "audio")).toBe(true);

      await groupCallMuteAll(alice.page).click();
      await expect(
        alice.page.getByTestId("group-call-confirm-dialog"),
      ).toContainText("Mute all lower-ranked participants");
      await groupCallConfirmLeave(alice.page).click();

      await expect
        .poll(() => localTrackEnabled(bob.page, "audio"), { timeout: 10_000 })
        .toBe(false);

      await groupCallHandToggle(bob.page).click();
      await expect(groupCallHandToggle(bob.page)).toHaveAttribute(
        "aria-pressed",
        "true",
      );
      await expect(groupCallRaisedHandQueue(alice.page)).toContainText(
        bob.nick,
        {
          timeout: 10_000,
        },
      );

      await participantAllowSpeakButton(alice.page, bob.nick).first().click();

      await expect
        .poll(() => localTrackEnabled(bob.page, "audio"), { timeout: 10_000 })
        .toBe(true);
      await expect(groupCallHandToggle(bob.page)).toHaveAttribute(
        "aria-pressed",
        "false",
      );
      await expect
        .poll(() => participantMediaEnabled(alice.page, bob.nick, "audio"), {
          timeout: 10_000,
        })
        .toBe("true");
      await expect(groupCallRaisedHandQueue(alice.page)).toBeHidden();
    } finally {
      await closeGroupCallUsers([alice, bob]);
    }
  });

  test("locked conference blocks lower-ranked users from joining", async ({
    browser,
  }) => {
    const alice = await newGroupCallUser(browser, "gclka");
    const bob = await newGroupCallUser(browser, "gclkb");
    const channel = uniqueChannel("gcalllock");

    try {
      for (const user of [alice, bob]) {
        await joinChannel(user, channel);
      }

      await joinGroupCall(alice.page);
      await expect(groupCallWindow(alice.page)).toBeVisible();
      await expect(groupCallLockToggle(alice.page)).toBeVisible();

      await groupCallLockToggle(alice.page).click();
      await expect(groupCallLockToggle(alice.page)).toHaveAttribute(
        "aria-pressed",
        "true",
      );

      await expect(groupCallChannelBadge(bob.page)).toContainText("Locked", {
        timeout: 10_000,
      });

      await groupCallButton(bob.page).click();
      await expect(groupCallPrejoinDialog(bob.page)).toBeVisible();
      await groupCallPrejoinJoin(bob.page).click();

      await expect(groupCallError(bob.page)).toContainText("locked", {
        timeout: 15_000,
      });
      await expect(
        alice.page.getByTestId("group-call-participants"),
      ).not.toContainText(bob.nick);
    } finally {
      await closeGroupCallUsers([alice, bob]);
    }
  });

  test("screen share replaces the published video and marks the remote tile", async ({
    browser,
  }) => {
    const alice = await newGroupCallUser(browser, "gcsha");
    const bob = await newGroupCallUser(browser, "gcshb");
    const channel = uniqueChannel("gcallscreen");

    try {
      for (const user of [alice, bob]) {
        await joinChannel(user, channel);
      }

      await joinGroupCall(alice.page);
      await expect(groupCallWindow(alice.page)).toBeVisible();

      await joinGroupCall(bob.page);
      await expect(groupCallWindow(bob.page)).toBeVisible();

      await expect
        .poll(() => remoteVideoLive(bob.page), { timeout: 30_000 })
        .toBe(true);

      await groupCallScreenShareToggle(alice.page).click();
      await expect(groupCallScreenShareToggle(alice.page)).toHaveAttribute(
        "aria-pressed",
        "true",
      );
      await expect(groupCallLocalTile(alice.page)).toHaveAttribute(
        "data-track-source",
        "screen",
      );

      await expect
        .poll(
          () => remoteVideoTile(bob.page).getAttribute("data-track-source"),
          { timeout: 15_000 },
        )
        .toBe("screen");
      await expect(remoteVideoTile(bob.page)).toContainText("screen");
      await expect
        .poll(() => remoteVideoLive(bob.page), { timeout: 10_000 })
        .toBe(true);

      await groupCallScreenShareToggle(alice.page).click();
      await expect(groupCallScreenShareToggle(alice.page)).toHaveAttribute(
        "aria-pressed",
        "false",
      );
      await expect
        .poll(
          () => remoteVideoTile(bob.page).getAttribute("data-track-source"),
          { timeout: 15_000 },
        )
        .toBe("camera");
    } finally {
      await closeGroupCallUsers([alice, bob]);
    }
  });

  test("layout controls focus tiles without interrupting remote video", async ({
    browser,
  }) => {
    const alice = await newGroupCallUser(browser, "gcla");
    const bob = await newGroupCallUser(browser, "gclb");
    const channel = uniqueChannel("gcallui");

    try {
      for (const user of [alice, bob]) {
        await joinChannel(user, channel);
      }

      await joinGroupCall(alice.page);
      await expect(groupCallWindow(alice.page)).toBeVisible();

      await joinGroupCall(bob.page);
      await expect(groupCallWindow(bob.page)).toBeVisible();

      await expect
        .poll(() => remoteVideoLive(alice.page), { timeout: 30_000 })
        .toBe(true);

      await expect(remoteVideoTile(alice.page)).toBeVisible();
      await expect
        .poll(() => remoteVideoIdentity(alice.page), { timeout: 10_000 })
        .toMatchObject({ trackReadyState: "live" });

      const initialRemote = await remoteVideoIdentity(alice.page);
      expect(initialRemote?.videoIdentity).toBeTruthy();
      expect(initialRemote?.streamId).toBeTruthy();

      await groupCallLayoutGrid(alice.page).click();
      await expect(groupCallLayoutGrid(alice.page)).toHaveAttribute(
        "aria-pressed",
        "true",
      );
      await expect(groupCallWebRTC(alice.page)).toHaveAttribute(
        "data-layout-mode",
        "grid",
      );
      await expect(groupCallVideoGrid(alice.page)).toHaveAttribute(
        "data-tile-count",
        "2",
      );
      await expect
        .poll(() => remoteVideoIdentity(alice.page))
        .toEqual(initialRemote);

      await groupCallLayoutFocus(alice.page).click();
      await expect(groupCallWebRTC(alice.page)).toHaveAttribute(
        "data-layout-mode",
        "focus",
      );
      await expect(groupCallClearFocus(alice.page)).toBeVisible();
      await expect(remoteVideoTile(alice.page)).toHaveAttribute(
        "data-focused",
        "true",
      );
      await expect
        .poll(() => remoteVideoIdentity(alice.page))
        .toEqual(initialRemote);

      const remoteParticipantId = await participantIdForNickname(
        alice.page,
        bob.nick,
      );
      expect(remoteParticipantId).toBeTruthy();

      await groupCallWebRTC(alice.page).evaluate((el, participantId) => {
        el.dispatchEvent(
          new CustomEvent("group-call:participant-quality", {
            detail: {
              active_speaker_participant_id: participantId,
              participants: [
                {
                  participant_id: participantId,
                  level: "good",
                  speaking: true,
                  rtt_ms: 80,
                  jitter_ms: 8,
                  loss_pct: 0,
                  bitrate_kbps: 900,
                  fps: 30,
                },
              ],
            },
          }),
        );
      }, remoteParticipantId);

      await groupCallLayoutSpeaker(alice.page).click();
      await expect(groupCallLayoutSpeaker(alice.page)).toHaveAttribute(
        "aria-pressed",
        "true",
      );
      await expect(groupCallWebRTC(alice.page)).toHaveAttribute(
        "data-layout-mode",
        "speaker",
      );
      await expect(remoteVideoTile(alice.page)).toHaveAttribute(
        "data-focused",
        "true",
      );
      await expect
        .poll(() => remoteVideoIdentity(alice.page))
        .toEqual(initialRemote);

      await participantPinButton(alice.page, bob.nick).click();
      await expect(participantPinButton(alice.page, bob.nick)).toHaveAttribute(
        "aria-pressed",
        "true",
      );
      await expect(remoteVideoTile(alice.page)).toHaveAttribute(
        "data-pinned",
        "true",
      );
      await expect
        .poll(() => remoteVideoIdentity(alice.page))
        .toEqual(initialRemote);

      await groupCallSelfViewToggle(alice.page).click();
      await expect(groupCallWebRTC(alice.page)).toHaveAttribute(
        "data-self-view",
        "pip",
      );
      await expect(groupCallLocalTile(alice.page)).toBeVisible();

      await groupCallSelfViewToggle(alice.page).click();
      await expect(groupCallWebRTC(alice.page)).toHaveAttribute(
        "data-self-view",
        "hidden",
      );
      await expect(groupCallLocalTile(alice.page)).toBeHidden();
      await expect(groupCallVideoGrid(alice.page)).toHaveAttribute(
        "data-tile-count",
        "1",
      );

      await groupCallSelfViewToggle(alice.page).click();
      await expect(groupCallWebRTC(alice.page)).toHaveAttribute(
        "data-self-view",
        "tile",
      );
      await expect(groupCallLocalTile(alice.page)).toBeVisible();

      await groupCallLayoutSidebar(alice.page).click();
      await expect(groupCallLayoutSidebar(alice.page)).toHaveAttribute(
        "aria-pressed",
        "false",
      );
      await expect(
        alice.page.getByTestId("group-call-participants"),
      ).toBeHidden();
      await expect(groupCallWebRTC(alice.page)).toHaveAttribute(
        "data-sidebar-open",
        "false",
      );

      await groupCallLayoutSidebar(alice.page).click();
      await expect(groupCallLayoutSidebar(alice.page)).toHaveAttribute(
        "aria-pressed",
        "true",
      );
      await expect(
        alice.page.getByTestId("group-call-participants"),
      ).toBeVisible();

      await groupCallClearFocus(alice.page).click();
      await expect(groupCallWebRTC(alice.page)).toHaveAttribute(
        "data-layout-mode",
        "auto",
      );
      await expect(remoteVideoTile(alice.page)).toHaveAttribute(
        "data-focused",
        "false",
      );
      await expect
        .poll(() => remoteVideoIdentity(alice.page))
        .toEqual(initialRemote);
    } finally {
      await closeGroupCallUsers([alice, bob]);
    }
  });

  test("mini mode keeps the call alive and preserves the remote video element", async ({
    browser,
  }) => {
    const alice = await newGroupCallUser(browser, "gcmia");
    const bob = await newGroupCallUser(browser, "gcmib");
    const channel = uniqueChannel("gcallmini");

    try {
      for (const user of [alice, bob]) {
        await joinChannel(user, channel);
      }

      await joinGroupCall(alice.page);
      await expect(groupCallWindow(alice.page)).toBeVisible();

      await joinGroupCall(bob.page);
      await expect(groupCallWindow(bob.page)).toBeVisible();

      await expect
        .poll(() => remoteVideoLive(alice.page), { timeout: 30_000 })
        .toBe(true);

      const initialRemote = await remoteVideoIdentity(alice.page);
      expect(initialRemote?.videoIdentity).toBeTruthy();
      expect(initialRemote?.streamId).toBeTruthy();

      await groupCallMiniToggle(alice.page).click();
      await expect(groupCallPanel(alice.page)).toHaveAttribute(
        "data-mini-mode",
        "true",
      );
      await expect(groupCallWebRTC(alice.page)).toBeVisible();
      await expect(groupCallMiniAudioToggle(alice.page)).toBeVisible();
      await expect(groupCallMiniVideoToggle(alice.page)).toBeVisible();
      await expect(groupCallMiniLeave(alice.page)).toBeVisible();
      await expect(groupCallMiniExpand(alice.page)).toBeVisible();
      await expect
        .poll(() => remoteVideoIdentity(alice.page))
        .toEqual(initialRemote);

      await groupCallMiniAudioToggle(alice.page).click();
      await expect(groupCallMiniAudioToggle(alice.page)).toHaveAttribute(
        "aria-pressed",
        "false",
      );
      await expect
        .poll(() => localTrackEnabled(alice.page, "audio"), { timeout: 10_000 })
        .toBe(false);
      await expect
        .poll(() => participantMediaEnabled(bob.page, alice.nick, "audio"), {
          timeout: 10_000,
        })
        .toBe("false");

      await groupCallMiniExpand(alice.page).click();
      await expect(groupCallPanel(alice.page)).toHaveAttribute(
        "data-mini-mode",
        "false",
      );
      await expect(groupCallAudioToggle(alice.page)).toHaveAttribute(
        "aria-pressed",
        "false",
      );
      await expect
        .poll(() => remoteVideoIdentity(alice.page))
        .toEqual(initialRemote);
    } finally {
      await closeGroupCallUsers([alice, bob]);
    }
  });

  test("conference can dock statistics beside the call and maximize the call window", async ({
    browser,
  }) => {
    const alice = await newGroupCallUser(browser, "gcdka");
    const channel = uniqueChannel("gcalldock");

    try {
      await joinChannel(alice, channel);
      await joinGroupCall(alice.page);
      await expect(groupCallWindow(alice.page)).toBeVisible();

      await groupCallDockStats(alice.page).click();
      await expect(groupCallStatsWindow(alice.page)).toBeVisible();

      const callBox = await groupCallWindow(alice.page).boundingBox();
      const statsBox = await groupCallStatsWindow(alice.page).boundingBox();
      expect(callBox).toBeTruthy();
      expect(statsBox).toBeTruthy();
      expect(statsBox!.x).toBeGreaterThan(callBox!.x + callBox!.width - 2);
      expect(Math.abs(statsBox!.y - callBox!.y)).toBeLessThanOrEqual(2);
      expect(Math.abs(statsBox!.height - callBox!.height)).toBeLessThanOrEqual(
        2,
      );

      await groupCallWindow(alice.page)
        .locator('[data-window-control="maximize"]')
        .click();
      await expect(groupCallWindow(alice.page)).toHaveClass(
        /desktop-window--maximized/,
      );
      await expect(groupCallStatsWindow(alice.page)).toBeVisible();

      await groupCallWindow(alice.page)
        .locator('[data-window-control="restore"]')
        .click();
      await expect(groupCallWindow(alice.page)).not.toHaveClass(
        /desktop-window--maximized/,
      );
    } finally {
      await closeGroupCallUsers([alice]);
    }
  });

  test("participant quality and active speaker indicators update in the conference UI", async ({
    browser,
  }) => {
    const alice = await newGroupCallUser(browser, "gcqa");
    const bob = await newGroupCallUser(browser, "gcqb");
    const channel = uniqueChannel("gcallq");

    try {
      for (const user of [alice, bob]) {
        await joinChannel(user, channel);
      }

      await joinGroupCall(alice.page);
      await expect(groupCallWindow(alice.page)).toBeVisible();

      await joinGroupCall(bob.page);
      await expect(groupCallWindow(bob.page)).toBeVisible();

      await expect
        .poll(() => remoteVideoLive(bob.page), { timeout: 30_000 })
        .toBe(true);
      await expect(participantRow(bob.page, alice.nick)).toBeVisible();

      const participantRowTestId = await participantRow(
        bob.page,
        alice.nick,
      ).getAttribute("data-testid");
      const participantId = participantRowTestId?.replace(
        "group-call-participant-",
        "",
      );
      if (!participantId) throw new Error("remote participant id missing");

      await groupCallWebRTC(bob.page).evaluate(
        (el, detail) => {
          el.dispatchEvent(
            new CustomEvent("group-call:participant-quality", { detail }),
          );
        },
        {
          active_speaker_participant_id: participantId,
          participants: [
            {
              participant_id: participantId,
              level: "poor",
              speaking: true,
              rtt_ms: 260,
              jitter_ms: 55,
              loss_pct: 8.5,
              bitrate_kbps: 240,
              fps: 12,
              freeze_count: 3,
            },
          ],
        },
      );

      await expect(remoteVideoTile(bob.page)).toHaveAttribute(
        "data-active-speaker",
        "true",
      );
      await expect(remoteVideoTile(bob.page)).toHaveAttribute(
        "data-quality-level",
        "poor",
      );
      await expect(participantRow(bob.page, alice.nick)).toHaveAttribute(
        "data-active-speaker",
        "true",
      );
      await expect(participantRow(bob.page, alice.nick)).toHaveAttribute(
        "data-quality-level",
        "poor",
      );
      await expect(
        bob.page.getByTestId(`group-call-participant-quality-${participantId}`),
      ).toHaveAttribute("data-quality-level", "poor");
      await expect(
        bob.page.getByTestId(
          `group-call-participant-active-speaker-${participantId}`,
        ),
      ).toBeVisible();
    } finally {
      await closeGroupCallUsers([alice, bob]);
    }
  });

  test("conference reactions propagate to remote tiles and expire", async ({
    browser,
  }) => {
    const alice = await newGroupCallUser(browser, "gcxa");
    const bob = await newGroupCallUser(browser, "gcxb");
    const channel = uniqueChannel("gcallreact");

    try {
      for (const user of [alice, bob]) {
        await joinChannel(user, channel);
      }

      await joinGroupCall(alice.page);
      await expect(groupCallWindow(alice.page)).toBeVisible();

      await joinGroupCall(bob.page);
      await expect(groupCallWindow(bob.page)).toBeVisible();

      await expect
        .poll(() => remoteVideoLive(bob.page), { timeout: 30_000 })
        .toBe(true);
      await expect(groupCallLocalTile(alice.page)).toHaveAttribute(
        "data-participant-id",
        /\d+/,
      );
      await expect(participantRow(bob.page, alice.nick)).toBeVisible();
      const aliceParticipantId = await participantIdForNickname(
        bob.page,
        alice.nick,
      );
      expect(aliceParticipantId).toBeTruthy();
      await groupCallWebRTC(bob.page).evaluate((el, participantId) => {
        el.dispatchEvent(
          new CustomEvent("group-call:participant-quality", {
            detail: {
              active_speaker_participant_id: null,
              participants: [
                {
                  participant_id: participantId,
                  level: "good",
                  speaking: false,
                },
              ],
            },
          }),
        );
      }, aliceParticipantId);
      await expect(remoteVideoTile(bob.page)).toHaveAttribute(
        "data-participant-id",
        aliceParticipantId || "",
      );

      await groupCallReaction(alice.page, "clap").click();

      const remoteReaction = bob.page.locator(
        '[data-group-call-reaction-bubble][data-reaction="clap"]',
      );

      await expect(remoteReaction).toBeVisible();
      await expect(
        participantReactionBadge(bob.page, alice.nick),
      ).toHaveAttribute("data-reaction", "clap");
      await expect(remoteReaction).toHaveCount(0, { timeout: 5_000 });
    } finally {
      await closeGroupCallUsers([alice, bob]);
    }
  });

  test("failed media recovery offers a manual retry without closing the conference", async ({
    browser,
  }) => {
    const alice = await newGroupCallUser(browser, "gcra");
    const bob = await newGroupCallUser(browser, "gcrb");
    const channel = uniqueChannel("gcallr");

    try {
      for (const user of [alice, bob]) {
        await joinChannel(user, channel);
      }

      await joinGroupCall(alice.page);
      await expect(groupCallWindow(alice.page)).toBeVisible();

      await joinGroupCall(bob.page);
      await expect(groupCallWindow(bob.page)).toBeVisible();

      await expect
        .poll(() => remoteVideoLive(bob.page), { timeout: 30_000 })
        .toBe(true);

      await groupCallWebRTC(bob.page).evaluate((el) => {
        el.dispatchEvent(
          new CustomEvent("group-call:recovery-state", {
            detail: {
              state: "failed",
              manual_retry: true,
              attempt: 3,
              max_attempts: 3,
              message: "Media recovery failed. Retry the media connection.",
            },
          }),
        );
      });

      await expect(groupCallError(bob.page)).toContainText("Retry");
      await expect(groupCallRetry(bob.page)).toBeVisible();

      await groupCallRetry(bob.page).click();

      await expect(groupCallWarning(bob.page)).toContainText(
        "Requesting a fresh media offer",
      );
      await expect(groupCallWindow(bob.page)).toBeVisible();
      await expect
        .poll(() => remoteVideoLive(bob.page), { timeout: 10_000 })
        .toBe(true);
    } finally {
      await closeGroupCallUsers([alice, bob]);
    }
  });

  test("three users renegotiate when a participant joins and leaves", async ({
    browser,
  }) => {
    const alice = await newGroupCallUser(browser, "gcnna");
    const bob = await newGroupCallUser(browser, "gcnnb");
    const carol = await newGroupCallUser(browser, "gcnnc");
    const channel = uniqueChannel("gcallnn");

    try {
      for (const user of [alice, bob, carol]) {
        await joinChannel(user, channel);
      }

      await joinGroupCall(alice.page);
      await expect(groupCallWindow(alice.page)).toBeVisible();

      await joinGroupCall(bob.page);
      await expect(groupCallWindow(bob.page)).toBeVisible();

      await expect
        .poll(() => remoteVideoLive(alice.page), { timeout: 30_000 })
        .toBe(true);
      await expect
        .poll(() => remoteVideoLive(bob.page), { timeout: 30_000 })
        .toBe(true);

      await joinGroupCall(carol.page);
      await expect(groupCallWindow(carol.page)).toBeVisible();

      for (const user of [alice, bob, carol]) {
        await expect
          .poll(() => remoteLiveVideoCount(user.page), { timeout: 30_000 })
          .toBeGreaterThanOrEqual(2);
      }

      await expect(
        alice.page.getByTestId("group-call-participants"),
      ).toContainText(bob.nick);
      await expect(
        alice.page.getByTestId("group-call-participants"),
      ).toContainText(carol.nick);
      await expect(
        carol.page.getByTestId("group-call-participants"),
      ).toContainText(alice.nick);
      await expect(
        carol.page.getByTestId("group-call-participants"),
      ).toContainText(bob.nick);

      for (const observer of [alice, carol]) {
        await expect
          .poll(() => participantMediaEnabled(observer.page, bob.nick, "audio"))
          .toBe("true");
        await expect
          .poll(() => participantMediaEnabled(observer.page, bob.nick, "video"))
          .toBe("true");
      }

      await groupCallVideoToggle(bob.page).click();
      await expect(groupCallVideoToggle(bob.page)).toHaveAttribute(
        "aria-pressed",
        "false",
      );
      await expect.poll(() => localTrackEnabled(bob.page, "video")).toBe(false);

      for (const observer of [alice, carol]) {
        await expect
          .poll(
            () => participantMediaEnabled(observer.page, bob.nick, "video"),
            {
              timeout: 10_000,
            },
          )
          .toBe("false");
      }

      await groupCallVideoToggle(bob.page).click();
      await expect(groupCallVideoToggle(bob.page)).toHaveAttribute(
        "aria-pressed",
        "true",
      );
      await expect.poll(() => localTrackEnabled(bob.page, "video")).toBe(true);

      for (const observer of [alice, carol]) {
        await expect
          .poll(
            () => participantMediaEnabled(observer.page, bob.nick, "video"),
            {
              timeout: 10_000,
            },
          )
          .toBe("true");
      }

      await groupCallAudioToggle(bob.page).click();
      await expect(groupCallAudioToggle(bob.page)).toHaveAttribute(
        "aria-pressed",
        "false",
      );
      await expect.poll(() => localTrackEnabled(bob.page, "audio")).toBe(false);

      for (const observer of [alice, carol]) {
        await expect
          .poll(
            () => participantMediaEnabled(observer.page, bob.nick, "audio"),
            {
              timeout: 10_000,
            },
          )
          .toBe("false");
      }

      await groupCallAudioToggle(bob.page).click();
      await expect(groupCallAudioToggle(bob.page)).toHaveAttribute(
        "aria-pressed",
        "true",
      );
      await expect.poll(() => localTrackEnabled(bob.page, "audio")).toBe(true);

      for (const observer of [alice, carol]) {
        await expect
          .poll(
            () => participantMediaEnabled(observer.page, bob.nick, "audio"),
            {
              timeout: 10_000,
            },
          )
          .toBe("true");
      }

      for (const user of [alice, bob, carol]) {
        await expect
          .poll(() => remoteLiveVideoCount(user.page), { timeout: 30_000 })
          .toBeGreaterThanOrEqual(2);
      }

      await groupCallLeave(carol.page).click();
      await expect(groupCallConfirmLeave(carol.page)).toBeVisible();
      await groupCallConfirmLeave(carol.page).click();
      await expect(groupCallWindow(carol.page)).toBeHidden();

      await expect(
        alice.page.getByTestId("group-call-participants"),
      ).not.toContainText(carol.nick, { timeout: 10_000 });
      await expect(
        bob.page.getByTestId("group-call-participants"),
      ).not.toContainText(carol.nick, { timeout: 10_000 });

      await expect
        .poll(() => remoteVideoLive(alice.page), { timeout: 10_000 })
        .toBe(true);
      await expect
        .poll(() => remoteVideoLive(bob.page), { timeout: 10_000 })
        .toBe(true);
    } finally {
      await closeGroupCallUsers([alice, bob, carol]);
    }
  });

  test("moderator can stop and block participant screen sharing", async ({
    browser,
  }) => {
    const alice = await newGroupCallUser(browser, "gcsma");
    const bob = await newGroupCallUser(browser, "gcsmb");
    const channel = uniqueChannel("gcallscreenmod");

    try {
      for (const user of [alice, bob]) {
        await joinChannel(user, channel);
      }

      await joinGroupCall(alice.page);
      await expect(groupCallWindow(alice.page)).toBeVisible();
      await joinGroupCall(bob.page);
      await expect(groupCallWindow(bob.page)).toBeVisible();

      await expect
        .poll(() => remoteVideoLive(alice.page), { timeout: 30_000 })
        .toBe(true);

      await groupCallScreenShareToggle(bob.page).click();
      await expect(groupCallScreenShareToggle(bob.page)).toHaveAttribute(
        "aria-pressed",
        "true",
      );
      await expect
        .poll(
          () => remoteVideoTile(alice.page).getAttribute("data-track-source"),
          { timeout: 15_000 },
        )
        .toBe("screen");

      await participantScreenModerationButton(alice.page, bob.nick).click();

      await expect(groupCallScreenShareToggle(bob.page)).toHaveAttribute(
        "aria-pressed",
        "false",
        { timeout: 10_000 },
      );
      await expect(groupCallScreenShareToggle(bob.page)).toBeDisabled();
      await expect(
        participantScreenModeratedIndicator(alice.page, bob.nick),
      ).toBeVisible();
      await expect
        .poll(
          () => remoteVideoTile(alice.page).getAttribute("data-track-source"),
          { timeout: 15_000 },
        )
        .not.toBe("screen");

      await participantScreenModerationButton(alice.page, bob.nick).click();
      await expect(groupCallScreenShareToggle(bob.page)).toBeEnabled({
        timeout: 10_000,
      });
      await expect(
        participantScreenModeratedIndicator(alice.page, bob.nick),
      ).toBeHidden();
    } finally {
      await closeGroupCallUsers([alice, bob]);
    }
  });
});

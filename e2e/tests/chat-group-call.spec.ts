/**
 * @section N - P2P, File, Call, Game
 * @flow N1 [done] Channel group call opens for two registered users, shows the rich live channel badge/popover before the second user joins, exchanges live remote video both ways, names each remote tile after its participant, toggles mic/camera by asserting local `MediaStreamTrack.enabled` and remote participant media state, then removes a leaver (features P0)
 * @flow N2 [done] Channel group call renegotiates with three registered media users: third participant joins, all clients receive two live remote videos each named after its participant, audio/video off-on state propagates to both observers, the third participant leaves, and remaining users keep media (features P0)
 * @flow N3 [done] Channel group call pre-join persists muted media preferences after cancel/reopen, enters with microphone and camera disabled, mounts WebRTC with disabled media state, avoids local media tracks, and propagates disabled media to another participant (features P0)
 * @flow N4 [done] Channel group call screen share uses browser display capture, replaces the published video, marks the remote tile as `source=screen`, and returns to camera when stopped (features P0)
 * @flow N5 [done] Channel group call participant quality and active speaker indicators update the ignored video tile and LiveView participant row from a browser stats summary (features P0)
 * @flow N6 [done] Channel group call failed media recovery shows a manual Retry action, requests a fresh media offer, keeps the conference window open, and preserves remote video (features P0)
 * @flow N7 [done] Channel group call camera moderation lets a higher-ranked participant disable another user's camera, verifies the target browser video track is disabled, prevents local re-enable while blocked, and restores video after release (features P0)
 * @flow N8 [done] Channel group call bulk moderation lets a higher-ranked participant mute microphones and turn off cameras for lower-ranked participants, verifies two target browsers are forced off, and confirms local attempts cannot bypass the server block (features P0)
 * @flow N9 [done] Channel group call lock lets a moderator prevent lower-ranked users from joining, shows the locked state in the channel badge, and returns a locked-call error when a blocked user attempts to enter (features P0)
 * @flow N10 [done] Channel group call request-to-speak lets a muted participant raise a hand, shows the moderator queue, lets the moderator allow speech, and verifies the target browser audio track is re-enabled (features P0)
 * @flow N11 [done] Channel group call screen-share moderation lets a moderator stop a participant screen share, blocks immediate re-share on the target browser, and re-allows sharing afterward (features P0)
 * @flow N12 [done] Channel group call mini mode shrinks the call to a small window and expanding restores its size, keeps the WebRTC surface mounted, preserves the same remote video element, exposes compact mic/camera/leave/expand controls, and verifies compact mute affects the real local track and remote participant state (features P0)
 * @flow N13 [done] Channel group call can dock the statistics window beside the conference without stealing the call workflow, then maximize and restore the conference window while stats remains visible (features P1)
 * @flow N14 [done] Channel group call advanced layouts switch to speaker view from active-speaker state, pin a participant, preserve the same remote video element across layout transitions, and expose compact grid density through the WebRTC surface (features P1)
 * @flow N15 [done] Channel group call reactions send through the conference signaling channel, appear on the remote video tile and participant row, then expire from the tile overlay (features P1)
 * @flow N16 [done] Channel group call pre-join handles denied microphone/camera permission with a visible warning, retry action, and a receive-only join path that mounts without local tracks (features P0)
 * @flow N17 [done] Channel group call visual polish renders SVG reaction controls, captures desktop/mobile windows, and asserts the conference panel has no horizontal layout overflow (features P1)
 * @flow N52 [done] Channel group call per-participant moderation mutes one participant's microphone from their row's menu: their own browser's audio track goes off, their row is marked as muted by the moderator, their own toggle cannot turn it back on, and the moderator's "Allow participant microphone" restores it (features P0)
 * @flow N53 [done] Removing a participant from the conference bans them from its channel: after the confirm, their row leaves the moderator's call, their own tab says they were removed and banned, and the channel's tab leaves their chat (features P0)
 * @flow N54 [done] Focusing a participant from their row's menu puts their tile on the stage, the Settings section names the layout in use, and Auto layout lets the call arrange itself again (features P1)
 * @flow N55 [done] The speaker picked before joining is the one the call plays through: the remote participant's audio is routed to that output device (features P1)
 * @flow N56 [done] Six people in one channel conference each receive live video from the other five, and the Leave confirmation stays on top of the full grid: its button is what a click on it reaches, never a tile's nameplate (features P1)
 * @flow N57 [done] A participant whose microphone carries sound lights up as the active speaker on another participant's screen, from the audio level measured in the call, with no simulated stats (features P0)
 * @flow N59 [done] The layout picked before joining offers every layout the call has, Speaker included, and the call opens in the one picked (features P1)
 * @flow N60 [done] A call tab that loses the server says so: its status reads "Reconnecting to the server…" instead of the last state it heard, and its controls read as unavailable until the page is connected again, when the status and the controls come back by themselves (features P0)
 * @flow N61 [done] Closing the call tab by accident is not leaving: reopening the call's address within the reconnection window puts you straight back in your seat — even after a moderator locked the room — with no antechamber, live video both ways, and one row for you on the other side (features P0)
 * @flow N62 [done] While your conference runs in its own tab, the chat keeps up: coming back to it shows the newest lines of the channel, the call's card included, and a line you send scrolls into view (features P0)
 * @flow N63 [done] Ending the conference for everyone ends it on every page and says so: the moderator's tab says they ended it, each other participant's tab names who did, and neither points back at a room that no longer exists (features P0)
 * @flow N58 [done] Push-to-talk: holding Ctrl+Shift+Z while muted turns the microphone on for as long as it is held, and letting go turns it off again (features P1)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect, BrowserContext, Page } from "@playwright/test";
import { mkdirSync } from "node:fs";
import { uniqueChannel } from "../helpers/chatUsers";
import {
  closeGroupCallUsers,
  conferenceAddress,
  GroupCallUser,
  newGroupCallUser,
  openConference,
  openModerationMenu,
} from "../helpers/groupCallUsers";

const groupCallScreenshotDir = "test-results/group-call-visual-polish";

function groupCallScreenshot(name: string) {
  mkdirSync(groupCallScreenshotDir, { recursive: true });
  return `${groupCallScreenshotDir}/${name}.png`;
}

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
  return page.getByTestId("group-call-prejoin");
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

function groupCallPrejoinPreviewVideo(page: Page) {
  return page.getByTestId("group-call-prejoin-video");
}

function groupCallPrejoinEmpty(page: Page) {
  return page.getByTestId("group-call-prejoin-empty");
}

function groupCallInlineStats(page: Page) {
  return page.getByTestId("group-call-inline-stats");
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

function groupCallViewRail(page: Page) {
  return page.getByTestId("group-call-view-rail");
}

function groupCallMediaControls(page: Page) {
  return page.getByTestId("group-call-media-controls");
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

function groupCallStatusBar(page: Page) {
  return page.getByTestId("status-bar-group-call");
}

function groupCallStatusAnnouncer(page: Page) {
  return page.getByTestId("group-call-status-announcer");
}

// The entry has one shape and keeps it: it writes the room's card and goes
// nowhere, so it reads the same before and after the call this person is in.
function groupCallChannelIndicator(page: Page) {
  return page.getByTestId("group-call-open");
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

function groupCallSection(page: Page, section: string) {
  return page.getByTestId(`group-call-section-${section}`);
}

function groupCallSettingsPanel(page: Page) {
  return page.getByTestId("group-call-settings-panel");
}

function groupCallReaction(page: Page, reaction: string) {
  return page.getByTestId(`group-call-reaction-${reaction}`);
}

function groupCallReactionIcon(page: Page, reaction: string) {
  return page
    .getByTestId(`group-call-reaction-icon-${reaction}`)
    .locator("svg");
}

function groupCallReactionsToggle(page: Page) {
  return page.getByTestId("group-call-reactions-toggle");
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

async function openGroupCallStatsDetails(page: Page) {
  for (const testId of [
    "group-call-stats-details-server",
    "group-call-stats-details-server-runtime",
    "group-call-stats-details-browser-connection",
    "group-call-stats-details-audio",
    "group-call-stats-details-video",
    "group-call-stats-details-browser-summary",
  ]) {
    const group = page.getByTestId(testId);
    await expect(group).toBeVisible();

    const isOpen = await group.evaluate(
      (element) => (element as HTMLDetailsElement).open,
    );
    if (!isOpen) {
      await group.locator("summary").click();
    }
    await expect
      .poll(() =>
        group.evaluate((element) => (element as HTMLDetailsElement).open),
      )
      .toBe(true);
  }
}

function remoteVideoTile(page: Page) {
  return page
    .locator('[data-group-call-video-tile][data-local="false"]')
    .first();
}

const remoteTileVideoSelector =
  '[data-group-call-video-tile][data-local="false"] video';

type RemoteVideoPlaybackSnapshot = {
  frameCount: number;
  currentTimeMs: number;
  paused: boolean;
  readyState: number;
  trackReadyState: string | null;
  videoHeight: number;
  videoWidth: number;
};

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

async function remoteVideoPlaybackSnapshot(
  page: Page,
): Promise<RemoteVideoPlaybackSnapshot | null> {
  return page.evaluate((selector) => {
    const videos = Array.from(
      document.querySelectorAll<HTMLVideoElement>(selector),
    );

    const snapshots = videos
      .map((video) => {
        const stream = video.srcObject as MediaStream | null;
        const track = stream?.getVideoTracks()[0] || null;
        const videoWithCounters = video as HTMLVideoElement & {
          mozDecodedFrames?: number;
          webkitDecodedFrameCount?: number;
        };
        const quality = video.getVideoPlaybackQuality?.();
        const frameCount = Math.max(
          Number(quality?.totalVideoFrames || 0),
          Number(videoWithCounters.webkitDecodedFrameCount || 0),
          Number(videoWithCounters.mozDecodedFrames || 0),
        );

        return {
          frameCount,
          currentTimeMs: Math.round(video.currentTime * 1000),
          paused: video.paused,
          readyState: video.readyState,
          trackReadyState: track?.readyState || null,
          videoHeight: video.videoHeight,
          videoWidth: video.videoWidth,
        };
      })
      .filter((snapshot) => snapshot.trackReadyState === "live")
      .sort((a, b) => b.frameCount - a.frameCount);

    return snapshots[0] || null;
  }, remoteTileVideoSelector);
}

async function expectRemoteVideoFramesToAdvance(page: Page, label: string) {
  let baseline: RemoteVideoPlaybackSnapshot | null = null;

  await expect
    .poll(
      async () => {
        baseline = await remoteVideoPlaybackSnapshot(page);

        return (
          !!baseline &&
          baseline.trackReadyState === "live" &&
          baseline.videoWidth > 0 &&
          baseline.videoHeight > 0
        );
      },
      { timeout: 30_000 },
    )
    .toBe(true);

  // TS cannot see the assignment inside the poll closure and narrows the
  // variable back to its `null` initializer — assert the declared type.
  const baselineFrameCount =
    (baseline as RemoteVideoPlaybackSnapshot | null)?.frameCount || 0;

  await expect
    .poll(
      async () => {
        const current = await remoteVideoPlaybackSnapshot(page);
        if (!current || current.trackReadyState !== "live") return -1;

        return current.frameCount - baselineFrameCount;
      },
      { intervals: [500, 1_000, 2_000], timeout: 15_000 },
    )
    .toBeGreaterThanOrEqual(3);

  const current = await remoteVideoPlaybackSnapshot(page);
  expect(current?.paused, `${label} remote video is paused`).toBe(false);
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

// The participant panel is bound to the People tab, so anything reaching for a
// participant row has to open that section first.
async function openPeopleSection(page: Page) {
  await groupCallSection(page, "people").click();
  await expect(page.getByTestId("group-call-participants")).toBeVisible();
}

function participantRow(page: Page, nickname: string) {
  return page.locator("[data-group-call-participant]", {
    hasText: nickname,
  });
}

async function openParticipantActions(page: Page, nickname: string) {
  await openPeopleSection(page);
  const row = participantRow(page, nickname);
  const menu = row.locator("details").first();

  if ((await menu.getAttribute("open")) === null) {
    await row
      .locator('[data-testid^="group-call-participant-actions-"]')
      .click();
  }
}

function participantPinButton(page: Page, nickname: string) {
  return participantRow(page, nickname).getByRole("menuitemcheckbox", {
    name: /Pin participant/,
  });
}

function participantReactionBadge(page: Page, nickname: string) {
  return participantRow(page, nickname).locator(
    '[data-testid^="group-call-participant-reaction-"][data-reaction]',
  );
}

async function participantIdForNickname(page: Page, nickname: string) {
  await openPeopleSection(page);
  const testId = await participantRow(page, nickname).getAttribute(
    "data-testid",
  );
  return testId?.replace("group-call-participant-", "") || null;
}

function participantCameraModerationButton(page: Page, nickname: string) {
  return participantRow(page, nickname).getByRole("menuitem", {
    name: /Turn participant camera off|Allow participant camera/,
  });
}

function participantScreenModerationButton(page: Page, nickname: string) {
  return participantRow(page, nickname).getByRole("menuitem", {
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

function participantAudioModerationButton(page: Page, nickname: string) {
  return participantRow(page, nickname).getByRole("menuitem", {
    name: /Mute participant|Unmute participant|Allow participant microphone/,
  });
}

function participantAudioModeratedIndicator(page: Page, nickname: string) {
  return participantRow(page, nickname).locator(
    '[data-group-call-participant-audio][data-media-moderated="true"]',
  );
}

function participantFocusButton(page: Page, nickname: string) {
  return participantRow(page, nickname).getByRole("menuitemcheckbox", {
    name: /Focus participant/,
  });
}

function participantRemoveButton(page: Page, nickname: string) {
  return participantRow(page, nickname).getByRole("menuitem", {
    name: /Remove from conference and ban from channel/,
  });
}

// Auto is in the view rail and again in Settings; the spec presses the one in
// the section it has open.
function groupCallLayoutAuto(page: Page) {
  return groupCallSettingsPanel(page).getByTestId("group-call-layout-auto");
}

// A second speaker on the machine, and a record of where the page routes
// sound: `setSinkId` is the one place an output device is chosen.
async function installSecondSpeaker(user: GroupCallUser) {
  await user.ctx.addInitScript(() => {
    const devices = navigator.mediaDevices as MediaDevices & {
      enumerateDevices: () => Promise<MediaDeviceInfo[]>;
    };
    const original = devices.enumerateDevices.bind(devices);
    const speaker = (deviceId: string, label: string) =>
      ({
        deviceId,
        groupId: deviceId,
        kind: "audiooutput",
        label,
        toJSON() {
          return this;
        },
      }) as MediaDeviceInfo;
    devices.enumerateDevices = async () => [
      ...(await original()).filter((d) => d.kind !== "audiooutput"),
      speaker("laptop-speakers", "Laptop Speakers"),
      speaker("desk-speakers", "Desk Speakers"),
    ];
    const sinks: string[] = [];
    (window as typeof window & { __sinkIds?: string[] }).__sinkIds = sinks;
    Object.defineProperty(HTMLMediaElement.prototype, "setSinkId", {
      configurable: true,
      value: async function (id: string) {
        sinks.push(id);
      },
    });
  });
}

// A microphone that carries sound: the suite's synthetic tone is quiet on
// purpose, under the level the call counts as speaking.
async function installAudibleMicrophone(user: GroupCallUser) {
  await user.ctx.addInitScript(() => {
    const devices = navigator.mediaDevices;
    const original = devices.getUserMedia.bind(devices);
    devices.getUserMedia = async (constraints?: MediaStreamConstraints) => {
      const stream = await original(constraints);
      if (!constraints?.audio) return stream;
      for (const track of stream.getAudioTracks()) stream.removeTrack(track);
      const audio = new AudioContext();
      void audio.resume();
      const tone = audio.createOscillator();
      tone.type = "sawtooth";
      tone.frequency.value = 160;
      const loud = audio.createGain();
      loud.gain.value = 0.6;
      const out = audio.createMediaStreamDestination();
      tone.connect(loud).connect(out);
      tone.start();
      stream.addTrack(out.stream.getAudioTracks()[0]);
      return stream;
    };
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

// A conference is a page of its own, reached through the card the chat writes
// when the room is opened. Everything about being in the call happens on the
// returned page; the chat keeps only the zone that points at it.
async function openPrejoin(user: GroupCallUser): Promise<Page> {
  const call = await openConference(user);
  await expect(groupCallPrejoinDialog(call)).toBeVisible();
  return call;
}

async function joinGroupCall(
  user: GroupCallUser,
  options: { audio?: boolean; video?: boolean } = {},
): Promise<Page> {
  const call = await openPrejoin(user);

  if (options.audio !== undefined) {
    await groupCallPrejoinAudio(call).setChecked(options.audio);
  }

  if (options.video !== undefined) {
    await groupCallPrejoinVideo(call).setChecked(options.video);
  }

  await groupCallPrejoinJoin(call).click();
  return call;
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
      const isRendered = rect.width > 0 && rect.height > 0;
      if (!isRendered) continue;

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

async function expectPrejoinCameraPreviewLive(page: Page) {
  await expect(groupCallPrejoinPreviewVideo(page)).toBeVisible();
  await expect
    .poll(
      () =>
        groupCallPrejoinPreviewVideo(page).evaluate((video) => {
          const stream = (video as HTMLVideoElement)
            .srcObject as MediaStream | null;
          return (
            !!stream &&
            stream
              .getVideoTracks()
              .some((track) => track.readyState === "live" && track.enabled)
          );
        }),
      { timeout: 10_000 },
    )
    .toBe(true);
  await expect(groupCallPrejoinEmpty(page)).toBeHidden();
}

async function participantMediaEnabled(
  page: Page,
  nickname: string,
  kind: "audio" | "video",
) {
  const attr = kind === "audio" ? "data-media-audio" : "data-media-video";
  return participantRow(page, nickname).getAttribute(attr);
}

// On the context and not on a page: the antechamber asks for media the moment
// its page loads, and that page does not exist until the address is opened.
async function denyUserMedia(ctx: BrowserContext) {
  await ctx.addInitScript(() => {
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
      await joinChannel(alice, channel);

      const aliceCall = await openPrejoin(alice);
      // Sizing the call's own page, not the chat's: the antechamber is over
      // there, and a viewport set on the wrong tab measures nothing.
      await aliceCall.setViewportSize({ width: 1280, height: 720 });
      await expect(groupCallPrejoinDialog(aliceCall)).toBeVisible();
      await expectPrejoinCameraPreviewLive(aliceCall);
      await expectPrejoinDialogLayoutStable(aliceCall);

      await aliceCall.setViewportSize({ width: 390, height: 844 });
      await expect(groupCallPrejoinDialog(aliceCall)).toBeVisible();
      await expectPrejoinCameraPreviewLive(aliceCall);
      await expectPrejoinDialogLayoutStable(aliceCall);
    } finally {
      await closeGroupCallUsers([alice]);
    }
  });

  test("conference visual polish renders SVG reactions and captures desktop/mobile windows", async ({
    browser,
  }) => {
    const alice = await newGroupCallUser(browser, "gcvpa");
    const channel = uniqueChannel("gcallvisual-long-room-name");

    try {
      await joinChannel(alice, channel);

      const aliceCall = await joinGroupCall(alice, {
        audio: false,
        video: false,
      });
      // The size that matters is the call's own page: it is a separate tab, so
      // resizing the chat would leave every layout assertion below measuring a
      // window nobody looked at.
      await aliceCall.setViewportSize({ width: 1280, height: 720 });
      await expect(groupCallWindow(aliceCall)).toBeVisible();
      await openPeopleSection(aliceCall);
      await expect(groupCallPanel(aliceCall)).toContainText(
        "Waiting for participants",
      );
      await expect(groupCallPanel(aliceCall)).toContainText(
        "Receive-only mode",
      );

      for (const reaction of ["heart", "thumbs_up", "clap", "laugh", "wow"]) {
        await expect(groupCallReactionIcon(aliceCall, reaction)).toHaveCount(1);
        await expect(groupCallReaction(aliceCall, reaction)).not.toContainText(
          /👍|👏|😄|✨/,
        );
      }

      const desktopImage = await groupCallWindow(aliceCall).screenshot({
        path: groupCallScreenshot("conference-desktop"),
      });
      expect(desktopImage.byteLength).toBeGreaterThan(8_000);
      await expectGroupCallLayoutStable(aliceCall);
      await expectMediaSessionHeadersStable(aliceCall, "group-call-panel");

      await aliceCall.setViewportSize({ width: 768, height: 1024 });
      await expect(groupCallWindow(aliceCall)).toBeVisible();
      await expect(groupCallPanel(aliceCall)).toBeVisible();
      await expectGroupCallLayoutStable(aliceCall);
      await expectMediaSessionHeadersStable(aliceCall, "group-call-panel");

      await groupCallSection(aliceCall, "settings").click();
      await expect(groupCallSettingsPanel(aliceCall)).toBeVisible();
      await expect(
        aliceCall.getByTestId("group-call-settings-scroll"),
      ).toHaveAttribute("phx-hook", "PreserveScrollHook");
      await expect(groupCallSection(aliceCall, "settings")).toHaveAttribute(
        "aria-pressed",
        "true",
      );

      await groupCallSection(aliceCall, "people").click();
      await expect(
        aliceCall.getByTestId("group-call-participants"),
      ).toBeVisible();
      await expect(
        aliceCall.getByTestId("group-call-participants"),
      ).toHaveAttribute("phx-hook", "PreserveScrollHook");
      await expect(groupCallSection(aliceCall, "people")).toHaveAttribute(
        "aria-pressed",
        "true",
      );

      await groupCallSection(aliceCall, "call").click();
      await expect(groupCallVideoGrid(aliceCall)).toBeVisible();
      await expect(groupCallSection(aliceCall, "call")).toHaveAttribute(
        "aria-pressed",
        "true",
      );

      await groupCallSection(aliceCall, "stats").click();
      await expect(groupCallInlineStats(aliceCall)).toBeVisible();
      await expect(groupCallInlineStats(aliceCall)).toContainText(
        "Browser connection",
      );
      await expect(groupCallInlineStats(aliceCall)).toHaveAttribute(
        "phx-hook",
        "PreserveScrollHook",
      );
      await expect(groupCallSection(aliceCall, "stats")).toHaveAttribute(
        "aria-pressed",
        "true",
      );
      await expect(groupCallWindow(aliceCall)).toBeVisible();

      await aliceCall.setViewportSize({ width: 390, height: 844 });
      await expect(groupCallWindow(aliceCall)).toBeVisible();
      await expect(groupCallPanel(aliceCall)).toBeVisible();
      await expect(groupCallInlineStats(aliceCall)).toBeVisible();
      await expect(groupCallVideoGrid(aliceCall)).toBeHidden();
      await expect(groupCallViewRail(aliceCall)).toBeHidden();
      await expect(groupCallMediaControls(aliceCall)).toBeHidden();
      await expectMobileSectionNavCue(aliceCall, "group-call-section-nav");
      await expectMediaSessionHeadersStable(aliceCall, "group-call-panel");

      const mobileImage = await groupCallWindow(aliceCall).screenshot({
        path: groupCallScreenshot("conference-mobile"),
      });
      expect(mobileImage.byteLength).toBeGreaterThan(8_000);
      await expectGroupCallLayoutStable(aliceCall);
    } finally {
      await closeGroupCallUsers([alice]);
    }
  });

  test("two identified channel users join the same SFU call and exchange decoded video frames", async ({
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

      const aliceCall = await joinGroupCall(alice);
      await expect(groupCallWindow(aliceCall)).toBeVisible();
      await expect(groupCallStatusBar(alice.page)).toContainText(channel);
      await expect(groupCallStatusBar(alice.page)).toContainText("another tab");
      await expect(aliceCall.getByTestId("group-call-webrtc")).toBeVisible();

      await expect(groupCallChannelIndicator(bob.page)).toBeVisible();
      await expect(groupCallChannelIndicator(bob.page)).toHaveAttribute(
        "data-state",
        "active",
      );
      await expect(groupCallChannelIndicator(bob.page)).toHaveAttribute(
        "data-participant-count",
        "1",
      );
      await expect(groupCallChannelIndicator(bob.page)).toHaveAttribute(
        "data-max-participants",
        "100",
      );
      await groupCallChannelPopoverToggle(bob.page).click();
      await expect(groupCallChannelPopover(bob.page)).toBeVisible();
      await expect(groupCallChannelPopover(bob.page)).toContainText(alice.nick);

      // The popover reports the room; it does not offer a way into it. The
      // card in the channel is the only door.
      await expect(
        groupCallChannelPopover(bob.page).locator("a[href^='/call/']"),
      ).toHaveCount(0);

      const bobCall = await joinGroupCall(bob);
      await expect(groupCallWindow(bobCall)).toBeVisible();

      await openPeopleSection(aliceCall);
      await openPeopleSection(bobCall);
      await expect(groupCallStatusBar(bob.page)).toContainText(channel);
      await expect(groupCallStatusBar(bob.page)).toContainText("another tab");
      await expect(bobCall.getByTestId("group-call-webrtc")).toBeVisible();
      await expect(groupCallChannelIndicator(alice.page)).toHaveAttribute(
        "data-participant-count",
        "2",
      );

      await expect
        .poll(() => remoteVideoLive(aliceCall), { timeout: 30_000 })
        .toBe(true);
      await expect
        .poll(() => remoteVideoLive(bobCall), { timeout: 30_000 })
        .toBe(true);
      await expectRemoteVideoFramesToAdvance(aliceCall, "Alice");
      await expectRemoteVideoFramesToAdvance(bobCall, "Bob");
      // Each side names the other's tile after them, including the one who
      // joined second (whose streams were all minted before its first offer).
      for (const [call, other] of [
        [aliceCall, bob.nick],
        [bobCall, alice.nick],
      ] as const) {
        await expect(
          call
            .locator(
              ".group-call-video-tile--remote [data-group-call-tile-name]",
            )
            .first(),
        ).toHaveText(other, { timeout: 20_000 });
      }
      await expect(groupCallStatusAnnouncer(aliceCall)).toContainText(
        "Connected",
        { timeout: 20_000 },
      );
      await expect(groupCallStatusAnnouncer(bobCall)).toContainText(
        "Connected",
        { timeout: 20_000 },
      );

      await expect(
        aliceCall.getByTestId("group-call-participants"),
      ).toContainText(bob.nick);
      await expect(
        bobCall.getByTestId("group-call-participants"),
      ).toContainText(alice.nick);

      await groupCallSection(aliceCall, "stats").click();
      await expect(groupCallInlineStats(aliceCall)).toBeVisible();
      await expect(groupCallInlineStats(aliceCall)).toContainText(
        "Server runtime",
      );
      await expect(groupCallInlineStats(aliceCall)).toContainText(
        "Browser connection",
      );
      await expect(groupCallInlineStats(aliceCall)).toContainText(
        "Peer connections",
      );
      await aliceCall.setViewportSize({ width: 390, height: 640 });
      await expect(groupCallInlineStats(aliceCall)).toBeVisible();
      await openGroupCallStatsDetails(aliceCall);
      await expectScrollStableAcrossStatsTick(
        aliceCall,
        "group-call-inline-stats",
      );
      await aliceCall.setViewportSize({ width: 1280, height: 720 });
      await expect(groupCallWindow(aliceCall)).toBeVisible();
      await groupCallSection(aliceCall, "call").click();

      // The chat's zone says where the call is and nothing else: it carries no
      // address, because the card in the channel is the only door.
      await expect(groupCallStatusBar(alice.page)).toContainText(channel);
      await expect(groupCallStatusBar(alice.page)).not.toHaveAttribute(
        "href",
        /.*/,
      );

      await expect.poll(() => localTrackEnabled(aliceCall, "audio")).toBe(true);
      await expect.poll(() => localTrackEnabled(aliceCall, "video")).toBe(true);
      await expect
        .poll(() => participantMediaEnabled(bobCall, alice.nick, "audio"))
        .toBe("true");
      await expect
        .poll(() => participantMediaEnabled(bobCall, alice.nick, "video"))
        .toBe("true");

      await groupCallAudioToggle(aliceCall).click();
      await expect(groupCallAudioToggle(aliceCall)).toHaveAttribute(
        "aria-pressed",
        "false",
      );
      await expect
        .poll(() => localTrackEnabled(aliceCall, "audio"))
        .toBe(false);
      await expect
        .poll(() => participantMediaEnabled(bobCall, alice.nick, "audio"), {
          timeout: 10_000,
        })
        .toBe("false");

      await groupCallAudioToggle(aliceCall).click();
      await expect(groupCallAudioToggle(aliceCall)).toHaveAttribute(
        "aria-pressed",
        "true",
      );
      await expect.poll(() => localTrackEnabled(aliceCall, "audio")).toBe(true);
      await expect
        .poll(() => participantMediaEnabled(bobCall, alice.nick, "audio"), {
          timeout: 10_000,
        })
        .toBe("true");

      await groupCallVideoToggle(aliceCall).click();
      await expect(groupCallVideoToggle(aliceCall)).toHaveAttribute(
        "aria-pressed",
        "false",
      );
      await expect
        .poll(() => localTrackEnabled(aliceCall, "video"))
        .toBe(false);
      await expect
        .poll(() => participantMediaEnabled(bobCall, alice.nick, "video"), {
          timeout: 10_000,
        })
        .toBe("false");

      await groupCallVideoToggle(aliceCall).click();
      await expect(groupCallVideoToggle(aliceCall)).toHaveAttribute(
        "aria-pressed",
        "true",
      );
      await expect.poll(() => localTrackEnabled(aliceCall, "video")).toBe(true);
      await expect
        .poll(() => participantMediaEnabled(bobCall, alice.nick, "video"), {
          timeout: 10_000,
        })
        .toBe("true");

      await groupCallLeave(aliceCall).click();
      await expect(groupCallConfirmLeave(aliceCall)).toBeVisible();
      await groupCallConfirmLeave(aliceCall).click();
      // The page says it is finished rather than navigating: mounting the chat
      // from here would announce a second chat session and end the first. And
      // the chat drops the zone, because the tab gave up the address with it.
      await expect(aliceCall.getByTestId("call-left")).toBeVisible({
        timeout: 15_000,
      });
      await expect(groupCallStatusBar(alice.page)).toBeHidden({
        timeout: 15_000,
      });
      await expect(
        bobCall.getByTestId("group-call-participants"),
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

      const aliceCall = await joinGroupCall(alice);
      const bobCall = await joinGroupCall(bob);
      await expect(groupCallWindow(aliceCall)).toBeVisible();
      await expect(groupCallWindow(bobCall)).toBeVisible();
      await openPeopleSection(bobCall);

      await expect
        .poll(() => remoteVideoLive(aliceCall), { timeout: 30_000 })
        .toBe(true);
      await expect
        .poll(() => remoteVideoLive(bobCall), { timeout: 30_000 })
        .toBe(true);

      await expect.poll(() => localTrackEnabled(aliceCall, "audio")).toBe(true);
      await expect.poll(() => localTrackEnabled(aliceCall, "video")).toBe(true);

      await groupCallLocalTile(aliceCall).focus();
      await expect(groupCallLocalTile(aliceCall)).toBeFocused();
      await pressConferenceShortcut(aliceCall, "ArrowUp");
      await expect(groupCallAudioToggle(aliceCall)).toHaveAttribute(
        "aria-pressed",
        "false",
      );
      await expect
        .poll(() => localTrackEnabled(aliceCall, "audio"))
        .toBe(false);
      await expect
        .poll(() => participantMediaEnabled(bobCall, alice.nick, "audio"), {
          timeout: 10_000,
        })
        .toBe("false");

      await withConferenceShortcutHeld(aliceCall, "KeyZ", async () => {
        await expect
          .poll(() => localTrackEnabled(aliceCall, "audio"))
          .toBe(true);
        await expect
          .poll(() => participantMediaEnabled(bobCall, alice.nick, "audio"), {
            timeout: 10_000,
          })
          .toBe("true");
      });
      await expect
        .poll(() => localTrackEnabled(aliceCall, "audio"))
        .toBe(false);
      await expect
        .poll(() => participantMediaEnabled(bobCall, alice.nick, "audio"), {
          timeout: 10_000,
        })
        .toBe("false");

      await pressConferenceShortcut(aliceCall, "ArrowUp");
      await expect(groupCallAudioToggle(aliceCall)).toHaveAttribute(
        "aria-pressed",
        "true",
      );
      await expect.poll(() => localTrackEnabled(aliceCall, "audio")).toBe(true);

      await pressConferenceShortcut(aliceCall, "ArrowLeft");
      await expect(groupCallVideoToggle(aliceCall)).toHaveAttribute(
        "aria-pressed",
        "false",
      );
      await expect
        .poll(() => localTrackEnabled(aliceCall, "video"))
        .toBe(false);
      await expect
        .poll(() => participantMediaEnabled(bobCall, alice.nick, "video"), {
          timeout: 10_000,
        })
        .toBe("false");

      await pressConferenceShortcut(aliceCall, "ArrowLeft");
      await expect(groupCallVideoToggle(aliceCall)).toHaveAttribute(
        "aria-pressed",
        "true",
      );
      await expect.poll(() => localTrackEnabled(aliceCall, "video")).toBe(true);

      await pressConferenceShortcut(aliceCall, "ArrowRight");
      await expect(groupCallWebRTC(aliceCall)).toHaveAttribute(
        "data-layout-mode",
        "grid",
      );

      await pressConferenceShortcut(aliceCall, "ArrowDown");
      await expect(groupCallWebRTC(aliceCall)).toHaveAttribute(
        "data-layout-mode",
        "focus",
      );
      await expect(remoteVideoTile(aliceCall)).toHaveAttribute(
        "data-focused",
        "true",
      );

      await pressConferenceShortcut(aliceCall, "KeyQ");
      await expect(groupCallConfirmLeave(aliceCall)).toBeVisible();
      await groupCallConfirmCancel(aliceCall).click();
      await expect(groupCallWindow(aliceCall)).toBeVisible();
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

      const cancelled = await openPrejoin(alice);
      await groupCallPrejoinAudio(cancelled).setChecked(false);
      await groupCallPrejoinVideo(cancelled).setChecked(false);
      await groupCallPrejoinCancel(cancelled).click();
      // Backing out of the antechamber finishes its page, because the
      // antechamber *is* the page now — and it does not navigate to the chat,
      // which would end the chat this person already has open.
      await expect(cancelled.getByTestId("call-left")).toBeVisible({
        timeout: 15_000,
      });

      // The choice is remembered, and this is the only assertion that says so
      // that is true of where it is remembered. It used to poll localStorage for
      // an `rhc:group-call:prejoin:` key, which stopped existing when device
      // preferences moved to the trusted-device record on the server — so the
      // helper returned null forever and the test failed on a feature that
      // works. Ask the screen: it is the same question, and it survives the
      // answer moving — including the answer moving to a different page.
      const aliceCall = await openPrejoin(alice);
      await expect(groupCallPrejoinAudio(aliceCall)).not.toBeChecked();
      await expect(groupCallPrejoinVideo(aliceCall)).not.toBeChecked();
      await groupCallPrejoinJoin(aliceCall).click();

      await expect(groupCallWindow(aliceCall)).toBeVisible();
      await expect(groupCallWebRTC(aliceCall)).toHaveAttribute(
        "data-audio",
        "false",
      );
      await expect(groupCallWebRTC(aliceCall)).toHaveAttribute(
        "data-video",
        "false",
      );
      await expect.poll(() => localTrackEnabled(aliceCall, "audio")).toBe(null);
      await expect.poll(() => localTrackEnabled(aliceCall, "video")).toBe(null);

      const bobCall = await joinGroupCall(bob);
      await expect(groupCallWindow(bobCall)).toBeVisible();
      await openPeopleSection(bobCall);

      await expect
        .poll(() => participantMediaEnabled(bobCall, alice.nick, "audio"), {
          timeout: 10_000,
        })
        .toBe("false");
      await expect
        .poll(() => participantMediaEnabled(bobCall, alice.nick, "video"), {
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
      await denyUserMedia(alice.ctx);

      const aliceCall = await openPrejoin(alice);
      await expect(groupCallPrejoinDialog(aliceCall)).toBeVisible();
      await expect(groupCallPrejoinWarning(aliceCall)).toBeVisible();
      await expect(groupCallPrejoinWarning(aliceCall)).toContainText(
        /permission|microphone|camera/i,
      );

      await groupCallPrejoinRetry(aliceCall).click();
      await expect(groupCallPrejoinWarning(aliceCall)).toBeVisible();

      await groupCallPrejoinAudio(aliceCall).setChecked(false);
      await groupCallPrejoinVideo(aliceCall).setChecked(false);
      await groupCallPrejoinJoin(aliceCall).click();

      await expect(groupCallWindow(aliceCall)).toBeVisible();
      await expect(groupCallPanel(aliceCall)).toContainText(
        "Receive-only mode",
      );
      await expect(groupCallWebRTC(aliceCall)).toHaveAttribute(
        "data-audio",
        "false",
      );
      await expect(groupCallWebRTC(aliceCall)).toHaveAttribute(
        "data-video",
        "false",
      );
      await expect.poll(() => localTrackEnabled(aliceCall, "audio")).toBe(null);
      await expect.poll(() => localTrackEnabled(aliceCall, "video")).toBe(null);
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

      const aliceCall = await joinGroupCall(alice);
      await expect(groupCallWindow(aliceCall)).toBeVisible();

      const bobCall = await joinGroupCall(bob);
      await expect(groupCallWindow(bobCall)).toBeVisible();
      await openPeopleSection(aliceCall);

      await expect
        .poll(() => remoteVideoLive(aliceCall), { timeout: 30_000 })
        .toBe(true);
      await expect.poll(() => localTrackEnabled(bobCall, "video")).toBe(true);
      await expect
        .poll(() => participantMediaEnabled(aliceCall, bob.nick, "video"), {
          timeout: 10_000,
        })
        .toBe("true");

      await openParticipantActions(aliceCall, bob.nick);
      await participantCameraModerationButton(aliceCall, bob.nick).click();

      await expect
        .poll(() => localTrackEnabled(bobCall, "video"), { timeout: 10_000 })
        .toBe(false);
      await expect
        .poll(() => participantMediaEnabled(aliceCall, bob.nick, "video"), {
          timeout: 10_000,
        })
        .toBe("false");
      await expect(
        participantVideoModeratedIndicator(aliceCall, bob.nick),
      ).toBeVisible();

      await groupCallVideoToggle(bobCall).click();
      await expect
        .poll(() => localTrackEnabled(bobCall, "video"), { timeout: 10_000 })
        .toBe(false);
      await expect(groupCallVideoToggle(bobCall)).toHaveAttribute(
        "aria-pressed",
        "false",
      );

      await openParticipantActions(aliceCall, bob.nick);
      await participantCameraModerationButton(aliceCall, bob.nick).click();

      await expect
        .poll(() => localTrackEnabled(bobCall, "video"), { timeout: 10_000 })
        .toBe(true);
      await expect
        .poll(() => participantMediaEnabled(aliceCall, bob.nick, "video"), {
          timeout: 10_000,
        })
        .toBe("true");
      await expect(
        participantVideoModeratedIndicator(aliceCall, bob.nick),
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

      const aliceCall = await joinGroupCall(alice);
      await expect(groupCallWindow(aliceCall)).toBeVisible();
      const bobCall = await joinGroupCall(bob);
      await expect(groupCallWindow(bobCall)).toBeVisible();
      const carolCall = await joinGroupCall(carol);
      await expect(groupCallWindow(carolCall)).toBeVisible();
      await openPeopleSection(aliceCall);

      await expect
        .poll(() => remoteLiveVideoCount(aliceCall), { timeout: 30_000 })
        .toBe(2);
      await expect.poll(() => localTrackEnabled(aliceCall, "audio")).toBe(true);
      await expect.poll(() => localTrackEnabled(bobCall, "audio")).toBe(true);
      await expect.poll(() => localTrackEnabled(carolCall, "audio")).toBe(true);

      await openModerationMenu(aliceCall);
      await groupCallMuteAll(aliceCall).click();
      await expect(
        aliceCall.getByTestId("group-call-confirm-dialog"),
      ).toContainText("Mute all lower-ranked participants");
      await groupCallConfirmLeave(aliceCall).click();

      await expect
        .poll(() => localTrackEnabled(aliceCall, "audio"), { timeout: 10_000 })
        .toBe(true);
      await expect
        .poll(() => localTrackEnabled(bobCall, "audio"), { timeout: 10_000 })
        .toBe(false);
      await expect
        .poll(() => localTrackEnabled(carolCall, "audio"), { timeout: 10_000 })
        .toBe(false);
      await expect
        .poll(() => participantMediaEnabled(aliceCall, bob.nick, "audio"), {
          timeout: 10_000,
        })
        .toBe("false");
      await expect
        .poll(() => participantMediaEnabled(aliceCall, carol.nick, "audio"), {
          timeout: 10_000,
        })
        .toBe("false");

      await groupCallAudioToggle(bobCall).click();
      await expect
        .poll(() => localTrackEnabled(bobCall, "audio"), { timeout: 10_000 })
        .toBe(false);

      await openModerationMenu(aliceCall);
      await groupCallCameraOffAll(aliceCall).click();
      await expect(
        aliceCall.getByTestId("group-call-confirm-dialog"),
      ).toContainText("Turn off cameras for all lower-ranked participants");
      await groupCallConfirmLeave(aliceCall).click();

      await expect
        .poll(() => localTrackEnabled(aliceCall, "video"), { timeout: 10_000 })
        .toBe(true);
      await expect
        .poll(() => localTrackEnabled(bobCall, "video"), { timeout: 10_000 })
        .toBe(false);
      await expect
        .poll(() => localTrackEnabled(carolCall, "video"), { timeout: 10_000 })
        .toBe(false);
      await expect(
        participantVideoModeratedIndicator(aliceCall, bob.nick),
      ).toBeVisible();
      await expect(
        participantVideoModeratedIndicator(aliceCall, carol.nick),
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

      const aliceCall = await joinGroupCall(alice);
      await expect(groupCallWindow(aliceCall)).toBeVisible();
      const bobCall = await joinGroupCall(bob);
      await expect(groupCallWindow(bobCall)).toBeVisible();
      await openPeopleSection(aliceCall);

      await expect
        .poll(() => remoteVideoLive(aliceCall), { timeout: 30_000 })
        .toBe(true);
      await expect.poll(() => localTrackEnabled(bobCall, "audio")).toBe(true);

      await openModerationMenu(aliceCall);
      await groupCallMuteAll(aliceCall).click();
      await expect(
        aliceCall.getByTestId("group-call-confirm-dialog"),
      ).toContainText("Mute all lower-ranked participants");
      await groupCallConfirmLeave(aliceCall).click();

      await expect
        .poll(() => localTrackEnabled(bobCall, "audio"), { timeout: 10_000 })
        .toBe(false);

      await groupCallHandToggle(bobCall).click();
      await expect(groupCallHandToggle(bobCall)).toHaveAttribute(
        "aria-pressed",
        "true",
      );
      await expect(groupCallRaisedHandQueue(aliceCall)).toContainText(
        bob.nick,
        {
          timeout: 10_000,
        },
      );

      await participantAllowSpeakButton(aliceCall, bob.nick).first().click();

      await expect
        .poll(() => localTrackEnabled(bobCall, "audio"), { timeout: 10_000 })
        .toBe(true);
      await expect(groupCallHandToggle(bobCall)).toHaveAttribute(
        "aria-pressed",
        "false",
      );
      await expect
        .poll(() => participantMediaEnabled(aliceCall, bob.nick, "audio"), {
          timeout: 10_000,
        })
        .toBe("true");
      await expect(groupCallRaisedHandQueue(aliceCall)).toBeHidden();
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

      const aliceCall = await joinGroupCall(alice);
      await expect(groupCallWindow(aliceCall)).toBeVisible();
      await openModerationMenu(aliceCall);
      await expect(groupCallLockToggle(aliceCall)).toBeVisible();
      await openPeopleSection(aliceCall);

      await openModerationMenu(aliceCall);
      await groupCallLockToggle(aliceCall).click();
      await expect(groupCallLockToggle(aliceCall)).toHaveAttribute(
        "aria-checked",
        "true",
      );
      // Choosing an action closes the menu it was chosen from.
      await expect(
        aliceCall.getByTestId("group-call-moderation"),
      ).not.toHaveAttribute("open");

      await expect(groupCallChannelIndicator(bob.page)).toHaveAttribute(
        "data-state",
        "locked",
        { timeout: 10_000 },
      );

      // The refusal moved to the door. A locked room is one of the gates
      // `/call/:token` applies in `resolve_room`, so Bob is turned away on
      // arrival — with the policy's own sentence — instead of choosing a
      // camera first and being refused after.
      const callPath = conferenceAddress(aliceCall);
      const bobCall = await bob.ctx.newPage();
      await bobCall.goto(callPath);

      await expect(bobCall.getByTestId("call-denied")).toContainText("locked", {
        timeout: 15_000,
      });
      await expect(bobCall.getByTestId("group-call-prejoin")).toHaveCount(0);
      await expect(
        aliceCall.getByTestId("group-call-participants"),
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

      const aliceCall = await joinGroupCall(alice);
      await expect(groupCallWindow(aliceCall)).toBeVisible();

      const bobCall = await joinGroupCall(bob);
      await expect(groupCallWindow(bobCall)).toBeVisible();

      await expect
        .poll(() => remoteVideoLive(bobCall), { timeout: 30_000 })
        .toBe(true);

      await groupCallScreenShareToggle(aliceCall).click();
      await expect(groupCallScreenShareToggle(aliceCall)).toHaveAttribute(
        "aria-pressed",
        "true",
      );
      await expect(groupCallLocalTile(aliceCall)).toHaveAttribute(
        "data-track-source",
        "screen",
      );

      await expect
        .poll(
          () => remoteVideoTile(bobCall).getAttribute("data-track-source"),
          { timeout: 15_000 },
        )
        .toBe("screen");
      await expect(remoteVideoTile(bobCall)).toContainText("screen");
      await expect
        .poll(() => remoteVideoLive(bobCall), { timeout: 10_000 })
        .toBe(true);

      await groupCallScreenShareToggle(aliceCall).click();
      await expect(groupCallScreenShareToggle(aliceCall)).toHaveAttribute(
        "aria-pressed",
        "false",
      );
      await expect
        .poll(
          () => remoteVideoTile(bobCall).getAttribute("data-track-source"),
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

      const aliceCall = await joinGroupCall(alice);
      await expect(groupCallWindow(aliceCall)).toBeVisible();

      const bobCall = await joinGroupCall(bob);
      await expect(groupCallWindow(bobCall)).toBeVisible();
      await openPeopleSection(aliceCall);

      await expect
        .poll(() => remoteVideoLive(aliceCall), { timeout: 30_000 })
        .toBe(true);

      await expect(remoteVideoTile(aliceCall)).toBeVisible();
      await expect
        .poll(() => remoteVideoIdentity(aliceCall), { timeout: 10_000 })
        .toMatchObject({ trackReadyState: "live" });

      const initialRemote = await remoteVideoIdentity(aliceCall);
      expect(initialRemote?.videoIdentity).toBeTruthy();
      expect(initialRemote?.streamId).toBeTruthy();

      await groupCallLayoutGrid(aliceCall).click();
      await expect(groupCallLayoutGrid(aliceCall)).toHaveAttribute(
        "aria-pressed",
        "true",
      );
      await expect(groupCallWebRTC(aliceCall)).toHaveAttribute(
        "data-layout-mode",
        "grid",
      );
      await expect(groupCallVideoGrid(aliceCall)).toHaveAttribute(
        "data-tile-count",
        "2",
      );
      await expect
        .poll(() => remoteVideoIdentity(aliceCall))
        .toEqual(initialRemote);

      await groupCallLayoutFocus(aliceCall).click();
      await expect(groupCallWebRTC(aliceCall)).toHaveAttribute(
        "data-layout-mode",
        "focus",
      );
      await expect(groupCallClearFocus(aliceCall)).toBeVisible();
      await expect(remoteVideoTile(aliceCall)).toHaveAttribute(
        "data-focused",
        "true",
      );
      await expect
        .poll(() => remoteVideoIdentity(aliceCall))
        .toEqual(initialRemote);

      const remoteParticipantId = await participantIdForNickname(
        aliceCall,
        bob.nick,
      );
      expect(remoteParticipantId).toBeTruthy();

      await groupCallWebRTC(aliceCall).evaluate((el, participantId) => {
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

      await groupCallLayoutSpeaker(aliceCall).click();
      await expect(groupCallLayoutSpeaker(aliceCall)).toHaveAttribute(
        "aria-pressed",
        "true",
      );
      await expect(groupCallWebRTC(aliceCall)).toHaveAttribute(
        "data-layout-mode",
        "speaker",
      );
      await expect(remoteVideoTile(aliceCall)).toHaveAttribute(
        "data-focused",
        "true",
      );
      await expect
        .poll(() => remoteVideoIdentity(aliceCall))
        .toEqual(initialRemote);

      await openParticipantActions(aliceCall, bob.nick);
      await participantPinButton(aliceCall, bob.nick).click();
      await openParticipantActions(aliceCall, bob.nick);
      await expect(participantPinButton(aliceCall, bob.nick)).toHaveAttribute(
        "aria-checked",
        "true",
      );
      await expect(remoteVideoTile(aliceCall)).toHaveAttribute(
        "data-pinned",
        "true",
      );
      await expect
        .poll(() => remoteVideoIdentity(aliceCall))
        .toEqual(initialRemote);

      await groupCallSelfViewToggle(aliceCall).click();
      await expect(groupCallWebRTC(aliceCall)).toHaveAttribute(
        "data-self-view",
        "pip",
      );
      await expect(groupCallLocalTile(aliceCall)).toBeVisible();

      await groupCallSelfViewToggle(aliceCall).click();
      await expect(groupCallWebRTC(aliceCall)).toHaveAttribute(
        "data-self-view",
        "hidden",
      );
      await expect(groupCallLocalTile(aliceCall)).toBeHidden();
      await expect(groupCallVideoGrid(aliceCall)).toHaveAttribute(
        "data-tile-count",
        "1",
      );

      await groupCallSelfViewToggle(aliceCall).click();
      await expect(groupCallWebRTC(aliceCall)).toHaveAttribute(
        "data-self-view",
        "tile",
      );
      await expect(groupCallLocalTile(aliceCall)).toBeVisible();

      // The participant panel follows the People tab; there is no separate
      // sidebar toggle competing with it.
      await groupCallSection(aliceCall, "call").click();
      await expect(
        aliceCall.getByTestId("group-call-participants"),
      ).toBeHidden();

      await groupCallSection(aliceCall, "people").click();
      await expect(
        aliceCall.getByTestId("group-call-participants"),
      ).toBeVisible();

      await groupCallClearFocus(aliceCall).click();
      await expect(groupCallWebRTC(aliceCall)).toHaveAttribute(
        "data-layout-mode",
        "auto",
      );
      await expect(remoteVideoTile(aliceCall)).toHaveAttribute(
        "data-focused",
        "false",
      );
      await expect
        .poll(() => remoteVideoIdentity(aliceCall))
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

      const aliceCall = await joinGroupCall(alice);
      await expect(groupCallWindow(aliceCall)).toBeVisible();

      const bobCall = await joinGroupCall(bob);
      await expect(groupCallWindow(bobCall)).toBeVisible();
      await openPeopleSection(bobCall);

      await expect
        .poll(() => remoteVideoLive(aliceCall), { timeout: 30_000 })
        .toBe(true);

      const initialRemote = await remoteVideoIdentity(aliceCall);
      expect(initialRemote?.videoIdentity).toBeTruthy();
      expect(initialRemote?.streamId).toBeTruthy();

      await groupCallMiniToggle(aliceCall).click();
      await expect(groupCallPanel(aliceCall)).toHaveAttribute(
        "data-mini-mode",
        "true",
      );
      await expect(groupCallWebRTC(aliceCall)).toBeVisible();
      await expect(groupCallMiniAudioToggle(aliceCall)).toBeVisible();
      await expect(groupCallMiniVideoToggle(aliceCall)).toBeVisible();
      await expect(groupCallMiniLeave(aliceCall)).toBeVisible();
      await expect(groupCallMiniExpand(aliceCall)).toBeVisible();
      await expect
        .poll(() => remoteVideoIdentity(aliceCall))
        .toEqual(initialRemote);
      // Compact is a small window, not the whole page with its tiles squeezed.
      const windowWidth = async () =>
        (await groupCallWindow(aliceCall).boundingBox())?.width ?? 0;
      await expect.poll(windowWidth).toBeLessThan(400);

      await groupCallMiniAudioToggle(aliceCall).click();
      await expect(groupCallMiniAudioToggle(aliceCall)).toHaveAttribute(
        "aria-pressed",
        "false",
      );
      await expect
        .poll(() => localTrackEnabled(aliceCall, "audio"), { timeout: 10_000 })
        .toBe(false);
      await expect
        .poll(() => participantMediaEnabled(bobCall, alice.nick, "audio"), {
          timeout: 10_000,
        })
        .toBe("false");

      await groupCallMiniExpand(aliceCall).click();
      await expect(groupCallPanel(aliceCall)).toHaveAttribute(
        "data-mini-mode",
        "false",
      );
      await expect.poll(windowWidth).toBeGreaterThan(800);
      await expect(groupCallAudioToggle(aliceCall)).toHaveAttribute(
        "aria-pressed",
        "false",
      );
      await expect
        .poll(() => remoteVideoIdentity(aliceCall))
        .toEqual(initialRemote);
    } finally {
      await closeGroupCallUsers([alice, bob]);
    }
  });

  test("conference keeps statistics inline while maximizing the call window", async ({
    browser,
  }) => {
    const alice = await newGroupCallUser(browser, "gcsta");
    const channel = uniqueChannel("gcallstats");

    try {
      await joinChannel(alice, channel);
      const aliceCall = await joinGroupCall(alice);
      await expect(groupCallWindow(aliceCall)).toBeVisible();

      await groupCallSection(aliceCall, "stats").click();
      await expect(groupCallInlineStats(aliceCall)).toBeVisible();
      await expect(groupCallInlineStats(aliceCall)).toContainText(
        "Browser connection",
      );

      await groupCallWindow(aliceCall)
        .locator('[data-window-control="restore"]')
        .click();
      await expect(groupCallWindow(aliceCall)).not.toHaveClass(
        /desktop-window--maximized/,
      );
      await expect(groupCallInlineStats(aliceCall)).toBeVisible();

      await groupCallWindow(aliceCall)
        .locator('[data-window-control="maximize"]')
        .click();
      await expect(groupCallWindow(aliceCall)).toHaveClass(
        /desktop-window--maximized/,
      );
      await expect(groupCallInlineStats(aliceCall)).toBeVisible();
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

      const aliceCall = await joinGroupCall(alice);
      await expect(groupCallWindow(aliceCall)).toBeVisible();

      const bobCall = await joinGroupCall(bob);
      await expect(groupCallWindow(bobCall)).toBeVisible();
      await openPeopleSection(bobCall);

      await expect
        .poll(() => remoteVideoLive(bobCall), { timeout: 30_000 })
        .toBe(true);
      await expect(participantRow(bobCall, alice.nick)).toBeVisible();

      const participantRowTestId = await participantRow(
        bobCall,
        alice.nick,
      ).getAttribute("data-testid");
      const participantId = participantRowTestId?.replace(
        "group-call-participant-",
        "",
      );
      if (!participantId) throw new Error("remote participant id missing");

      await groupCallWebRTC(bobCall).evaluate(
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

      await expect(remoteVideoTile(bobCall)).toHaveAttribute(
        "data-active-speaker",
        "true",
      );
      await expect(remoteVideoTile(bobCall)).toHaveAttribute(
        "data-quality-level",
        "poor",
      );
      await expect(participantRow(bobCall, alice.nick)).toHaveAttribute(
        "data-active-speaker",
        "true",
      );
      await expect(participantRow(bobCall, alice.nick)).toHaveAttribute(
        "data-quality-level",
        "poor",
      );
      await expect(
        bobCall.getByTestId(`group-call-participant-quality-${participantId}`),
      ).toHaveAttribute("data-quality-level", "poor");
      await expect(
        bobCall.getByTestId(
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

      const aliceCall = await joinGroupCall(alice);
      await expect(groupCallWindow(aliceCall)).toBeVisible();

      const bobCall = await joinGroupCall(bob);
      await expect(groupCallWindow(bobCall)).toBeVisible();
      await openPeopleSection(bobCall);

      await expect
        .poll(() => remoteVideoLive(bobCall), { timeout: 30_000 })
        .toBe(true);
      await expect(groupCallLocalTile(aliceCall)).toHaveAttribute(
        "data-participant-id",
        /\d+/,
      );
      await expect(participantRow(bobCall, alice.nick)).toBeVisible();
      const aliceParticipantId = await participantIdForNickname(
        bobCall,
        alice.nick,
      );
      expect(aliceParticipantId).toBeTruthy();
      await groupCallWebRTC(bobCall).evaluate((el, participantId) => {
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
      await expect(remoteVideoTile(bobCall)).toHaveAttribute(
        "data-participant-id",
        aliceParticipantId || "",
      );

      await groupCallReactionsToggle(aliceCall).click();
      await groupCallReaction(aliceCall, "clap").click();

      const remoteReaction = bobCall.locator(
        '[data-group-call-reaction-bubble][data-reaction="clap"]',
      );

      await expect(remoteReaction).toBeVisible();
      await expect(
        participantReactionBadge(bobCall, alice.nick),
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

      const aliceCall = await joinGroupCall(alice);
      await expect(groupCallWindow(aliceCall)).toBeVisible();

      const bobCall = await joinGroupCall(bob);
      await expect(groupCallWindow(bobCall)).toBeVisible();

      await expect
        .poll(() => remoteVideoLive(bobCall), { timeout: 30_000 })
        .toBe(true);

      await expect(async () => {
        await groupCallWebRTC(bobCall).evaluate((el) => {
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

        await expect(groupCallError(bobCall)).toContainText("Retry", {
          timeout: 1_000,
        });
        await groupCallRetry(bobCall).click({ timeout: 1_000 });
      }).toPass({ timeout: 10_000 });

      await expect(groupCallWarning(bobCall)).toContainText(
        "Requesting a fresh media offer",
      );
      await expect(groupCallWindow(bobCall)).toBeVisible();
      await expect
        .poll(() => remoteVideoLive(bobCall), { timeout: 10_000 })
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

      const aliceCall = await joinGroupCall(alice);
      await expect(groupCallWindow(aliceCall)).toBeVisible();

      const bobCall = await joinGroupCall(bob);
      await expect(groupCallWindow(bobCall)).toBeVisible();

      await expect
        .poll(() => remoteVideoLive(aliceCall), { timeout: 30_000 })
        .toBe(true);
      await expect
        .poll(() => remoteVideoLive(bobCall), { timeout: 30_000 })
        .toBe(true);

      const carolCall = await joinGroupCall(carol);
      await expect(groupCallWindow(carolCall)).toBeVisible();
      await openPeopleSection(bobCall);
      await openPeopleSection(carolCall);
      await openPeopleSection(aliceCall);

      for (const call of [aliceCall, bobCall, carolCall]) {
        await expect
          .poll(() => remoteLiveVideoCount(call), { timeout: 30_000 })
          .toBeGreaterThanOrEqual(2);
      }

      // With two remote tiles the client cannot guess whose is whose: every
      // name comes from the offer saying which stream belongs to whom.
      for (const [call, others] of [
        [aliceCall, [bob.nick, carol.nick]],
        [bobCall, [alice.nick, carol.nick]],
        [carolCall, [alice.nick, bob.nick]],
      ] as const) {
        await expect
          .poll(
            () =>
              call
                .locator(
                  ".group-call-video-tile--remote [data-group-call-tile-name]",
                )
                .allTextContents()
                .then((names) => names.map((n) => n.trim()).sort()),
            { timeout: 20_000 },
          )
          .toEqual([...others].sort());
      }

      await expect(
        aliceCall.getByTestId("group-call-participants"),
      ).toContainText(bob.nick);
      await expect(
        aliceCall.getByTestId("group-call-participants"),
      ).toContainText(carol.nick);
      await expect(
        carolCall.getByTestId("group-call-participants"),
      ).toContainText(alice.nick);
      await expect(
        carolCall.getByTestId("group-call-participants"),
      ).toContainText(bob.nick);

      for (const observer of [aliceCall, carolCall]) {
        await expect
          .poll(() => participantMediaEnabled(observer, bob.nick, "audio"))
          .toBe("true");
        await expect
          .poll(() => participantMediaEnabled(observer, bob.nick, "video"))
          .toBe("true");
      }

      await groupCallVideoToggle(bobCall).click();
      await expect(groupCallVideoToggle(bobCall)).toHaveAttribute(
        "aria-pressed",
        "false",
      );
      await expect.poll(() => localTrackEnabled(bobCall, "video")).toBe(false);

      for (const observer of [aliceCall, carolCall]) {
        await expect
          .poll(() => participantMediaEnabled(observer, bob.nick, "video"), {
            timeout: 10_000,
          })
          .toBe("false");
      }

      await groupCallVideoToggle(bobCall).click();
      await expect(groupCallVideoToggle(bobCall)).toHaveAttribute(
        "aria-pressed",
        "true",
      );
      await expect.poll(() => localTrackEnabled(bobCall, "video")).toBe(true);

      for (const observer of [aliceCall, carolCall]) {
        await expect
          .poll(() => participantMediaEnabled(observer, bob.nick, "video"), {
            timeout: 10_000,
          })
          .toBe("true");
      }

      await groupCallAudioToggle(bobCall).click();
      await expect(groupCallAudioToggle(bobCall)).toHaveAttribute(
        "aria-pressed",
        "false",
      );
      await expect.poll(() => localTrackEnabled(bobCall, "audio")).toBe(false);

      for (const observer of [aliceCall, carolCall]) {
        await expect
          .poll(() => participantMediaEnabled(observer, bob.nick, "audio"), {
            timeout: 10_000,
          })
          .toBe("false");
      }

      await groupCallAudioToggle(bobCall).click();
      await expect(groupCallAudioToggle(bobCall)).toHaveAttribute(
        "aria-pressed",
        "true",
      );
      await expect.poll(() => localTrackEnabled(bobCall, "audio")).toBe(true);

      for (const observer of [aliceCall, carolCall]) {
        await expect
          .poll(() => participantMediaEnabled(observer, bob.nick, "audio"), {
            timeout: 10_000,
          })
          .toBe("true");
      }

      for (const call of [aliceCall, bobCall, carolCall]) {
        await expect
          .poll(() => remoteLiveVideoCount(call), { timeout: 30_000 })
          .toBeGreaterThanOrEqual(2);
      }

      await groupCallLeave(carolCall).click();
      await expect(groupCallConfirmLeave(carolCall)).toBeVisible();
      await groupCallConfirmLeave(carolCall).click();
      // The page says it is finished rather than navigating: going to the chat
      // from here would announce a second chat session and end the first.
      await expect(carolCall.getByTestId("call-left")).toBeVisible({
        timeout: 15_000,
      });

      await expect(
        aliceCall.getByTestId("group-call-participants"),
      ).not.toContainText(carol.nick, { timeout: 10_000 });
      await expect(
        bobCall.getByTestId("group-call-participants"),
      ).not.toContainText(carol.nick, { timeout: 10_000 });

      await expect
        .poll(() => remoteVideoLive(aliceCall), { timeout: 10_000 })
        .toBe(true);
      await expect
        .poll(() => remoteVideoLive(bobCall), { timeout: 10_000 })
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

      const aliceCall = await joinGroupCall(alice);
      await expect(groupCallWindow(aliceCall)).toBeVisible();
      const bobCall = await joinGroupCall(bob);
      await expect(groupCallWindow(bobCall)).toBeVisible();

      await expect
        .poll(() => remoteVideoLive(aliceCall), { timeout: 30_000 })
        .toBe(true);

      await groupCallScreenShareToggle(bobCall).click();
      await expect(groupCallScreenShareToggle(bobCall)).toHaveAttribute(
        "aria-pressed",
        "true",
      );
      await expect
        .poll(
          () => remoteVideoTile(aliceCall).getAttribute("data-track-source"),
          { timeout: 15_000 },
        )
        .toBe("screen");

      await openParticipantActions(aliceCall, bob.nick);
      await participantScreenModerationButton(aliceCall, bob.nick).click();

      await expect(groupCallScreenShareToggle(bobCall)).toHaveAttribute(
        "aria-pressed",
        "false",
        { timeout: 10_000 },
      );
      await expect(groupCallScreenShareToggle(bobCall)).toBeDisabled();
      await expect(
        participantScreenModeratedIndicator(aliceCall, bob.nick),
      ).toBeVisible();
      await expect
        .poll(
          () => remoteVideoTile(aliceCall).getAttribute("data-track-source"),
          { timeout: 15_000 },
        )
        .not.toBe("screen");

      await openParticipantActions(aliceCall, bob.nick);
      await participantScreenModerationButton(aliceCall, bob.nick).click();
      await expect(groupCallScreenShareToggle(bobCall)).toBeEnabled({
        timeout: 10_000,
      });
      await expect(
        participantScreenModeratedIndicator(aliceCall, bob.nick),
      ).toBeHidden();
    } finally {
      await closeGroupCallUsers([alice, bob]);
    }
  });

  test("moderator mutes one participant and their microphone stays off until allowed", async ({
    browser,
  }) => {
    const alice = await newGroupCallUser(browser, "gcmaa");
    const bob = await newGroupCallUser(browser, "gcmab");
    const channel = uniqueChannel("gcallmicmod");

    try {
      for (const user of [alice, bob]) {
        await joinChannel(user, channel);
      }

      const aliceCall = await joinGroupCall(alice);
      await expect(groupCallWindow(aliceCall)).toBeVisible();
      const bobCall = await joinGroupCall(bob);
      await expect(groupCallWindow(bobCall)).toBeVisible();
      await openPeopleSection(aliceCall);

      await expect
        .poll(() => remoteVideoLive(aliceCall), { timeout: 30_000 })
        .toBe(true);
      await expect.poll(() => localTrackEnabled(bobCall, "audio")).toBe(true);
      await expect
        .poll(() => participantMediaEnabled(aliceCall, bob.nick, "audio"), {
          timeout: 10_000,
        })
        .toBe("true");

      await openParticipantActions(aliceCall, bob.nick);
      await expect(
        participantAudioModerationButton(aliceCall, bob.nick),
      ).toHaveText(/Mute participant/);
      await participantAudioModerationButton(aliceCall, bob.nick).click();

      await expect
        .poll(() => localTrackEnabled(bobCall, "audio"), { timeout: 10_000 })
        .toBe(false);
      await expect
        .poll(() => participantMediaEnabled(aliceCall, bob.nick, "audio"), {
          timeout: 10_000,
        })
        .toBe("false");
      await expect(
        participantAudioModeratedIndicator(aliceCall, bob.nick),
      ).toBeVisible();

      // Bob's own switch cannot undo the moderator.
      await groupCallAudioToggle(bobCall).click();
      await expect
        .poll(() => localTrackEnabled(bobCall, "audio"), { timeout: 5_000 })
        .toBe(false);

      await openParticipantActions(aliceCall, bob.nick);
      await expect(
        participantAudioModerationButton(aliceCall, bob.nick),
      ).toHaveText(/Allow participant microphone/);
      await participantAudioModerationButton(aliceCall, bob.nick).click();
      await expect(
        participantAudioModeratedIndicator(aliceCall, bob.nick),
      ).toBeHidden();
      // Allowed again, the microphone comes back as it was before the mute.
      await expect
        .poll(() => localTrackEnabled(bobCall, "audio"), { timeout: 10_000 })
        .toBe(true);
    } finally {
      await closeGroupCallUsers([alice, bob]);
    }
  });

  test("removing a participant bans them from the channel and ends their call", async ({
    browser,
  }) => {
    const alice = await newGroupCallUser(browser, "gcrma");
    const bob = await newGroupCallUser(browser, "gcrmb");
    const channel = uniqueChannel("gcallremove");

    try {
      for (const user of [alice, bob]) {
        await joinChannel(user, channel);
      }

      const aliceCall = await joinGroupCall(alice);
      await expect(groupCallWindow(aliceCall)).toBeVisible();
      const bobCall = await joinGroupCall(bob);
      await expect(groupCallWindow(bobCall)).toBeVisible();
      await expect
        .poll(() => remoteVideoLive(aliceCall), { timeout: 30_000 })
        .toBe(true);

      await openParticipantActions(aliceCall, bob.nick);
      await participantRemoveButton(aliceCall, bob.nick).click();
      await groupCallConfirmLeave(aliceCall).click();

      await expect(participantRow(aliceCall, bob.nick)).toHaveCount(0, {
        timeout: 10_000,
      });
      await expect(aliceCall.getByTestId("call-notice")).toContainText(
        `${bob.nick} was removed from the conference and banned from ${channel}`,
      );

      const left = bobCall.getByTestId("call-left");
      await expect(left).toBeVisible({ timeout: 10_000 });
      await expect(left).toContainText(`You were banned from ${channel}`);
      await expect(left).not.toContainText("The room is still at this address");

      await bob.chat.expectTabHidden(channel);
    } finally {
      await closeGroupCallUsers([alice, bob]);
    }
  });

  test("focus from a participant's menu, the layout named in Settings, then Auto", async ({
    browser,
  }) => {
    const alice = await newGroupCallUser(browser, "gcfoa");
    const bob = await newGroupCallUser(browser, "gcfob");
    const channel = uniqueChannel("gcallfocus");

    try {
      for (const user of [alice, bob]) {
        await joinChannel(user, channel);
      }

      const aliceCall = await joinGroupCall(alice);
      await expect(groupCallWindow(aliceCall)).toBeVisible();
      const bobCall = await joinGroupCall(bob);
      await expect(groupCallWindow(bobCall)).toBeVisible();
      await expect
        .poll(() => remoteVideoLive(aliceCall), { timeout: 30_000 })
        .toBe(true);

      await openParticipantActions(aliceCall, bob.nick);
      await participantFocusButton(aliceCall, bob.nick).click();
      await expect(groupCallWebRTC(aliceCall)).toHaveAttribute(
        "data-layout-mode",
        "focus",
      );
      await expect(remoteVideoTile(aliceCall)).toHaveAttribute(
        "data-focused",
        "true",
      );

      await groupCallSection(aliceCall, "settings").click();
      await expect(groupCallSettingsPanel(aliceCall)).toBeVisible();
      await expect(groupCallSettingsPanel(aliceCall)).toContainText("Focus");

      await groupCallLayoutAuto(aliceCall).click();
      await expect(groupCallLayoutAuto(aliceCall)).toHaveAttribute(
        "aria-pressed",
        "true",
      );
      await expect(groupCallWebRTC(aliceCall)).toHaveAttribute(
        "data-layout-mode",
        "auto",
      );
      await expect(groupCallSettingsPanel(aliceCall)).toContainText("Auto");
    } finally {
      await closeGroupCallUsers([alice, bob]);
    }
  });

  test("the speaker picked before joining is the one the call plays through", async ({
    browser,
  }) => {
    const alice = await newGroupCallUser(browser, "gcspa");
    const bob = await newGroupCallUser(browser, "gcspb");
    const channel = uniqueChannel("gcallspeaker");

    try {
      for (const user of [alice, bob]) {
        await joinChannel(user, channel);
      }
      await installSecondSpeaker(alice);

      const bobCall = await joinGroupCall(bob);
      await expect(groupCallWindow(bobCall)).toBeVisible();

      const aliceCall = await openPrejoin(alice);
      const output = aliceCall.getByTestId("group-call-prejoin-audio-output");
      await expect(output).toContainText("Desk Speakers", {
        timeout: 10_000,
      });
      await output.selectOption("desk-speakers");
      await groupCallPrejoinJoin(aliceCall).click();
      await expect(groupCallWindow(aliceCall)).toBeVisible();

      await expect
        .poll(() => remoteVideoLive(aliceCall), { timeout: 30_000 })
        .toBe(true);
      await expect
        .poll(
          () =>
            aliceCall.evaluate(
              () =>
                (window as typeof window & { __sinkIds?: string[] }).__sinkIds,
            ),
          { timeout: 10_000 },
        )
        .toContain("desk-speakers");
    } finally {
      await closeGroupCallUsers([alice, bob]);
    }
  });

  test("six people in one call each receive the other five", async ({
    browser,
  }) => {
    test.setTimeout(240_000);
    const users: GroupCallUser[] = [];
    const channel = uniqueChannel("gcallsix");

    try {
      for (let i = 0; i < 6; i++) {
        users.push(await newGroupCallUser(browser, `gcsix${i}`));
      }
      for (const user of users) {
        await joinChannel(user, channel);
      }

      const calls: Page[] = [];
      for (const user of users) {
        const call = await joinGroupCall(user);
        await expect(groupCallWindow(call)).toBeVisible();
        calls.push(call);
      }

      for (const call of calls) {
        await expect
          .poll(() => remoteLiveVideoCount(call), { timeout: 60_000 })
          .toBe(5);
      }

      const leaving = calls[0];
      await groupCallLeave(leaving).click();
      const confirm = groupCallConfirmLeave(leaving);
      await expect(confirm).toBeVisible();
      // Every point of the dialog is the dialog's: nothing from the grid
      // underneath — a tile's nameplate — paints over it or takes a click.
      const covered = await confirm.evaluate((button) => {
        let frame: Element = button;
        while (
          frame.parentElement &&
          frame.parentElement.getBoundingClientRect().width <
            window.innerWidth * 0.9
        ) {
          frame = frame.parentElement;
        }
        const box = frame.getBoundingClientRect();
        const misses: string[] = [];
        for (let i = 1; i < 8; i++) {
          for (let j = 1; j < 8; j++) {
            const x = box.left + (box.width * i) / 8;
            const y = box.top + (box.height * j) / 8;
            const hit = document.elementFromPoint(x, y);
            if (!hit || !frame.contains(hit)) {
              misses.push(hit?.outerHTML.slice(0, 80) ?? "nothing");
            }
          }
        }
        return misses;
      });
      expect(covered).toEqual([]);
      await confirm.click();
      await expect(leaving.getByTestId("call-left")).toBeVisible({
        timeout: 15_000,
      });
    } finally {
      await closeGroupCallUsers(users);
    }
  });

  test("whoever speaks lights up on the others' screens from the call's own audio", async ({
    browser,
  }) => {
    const alice = await newGroupCallUser(browser, "gctka");
    const bob = await newGroupCallUser(browser, "gctkb");
    const channel = uniqueChannel("gcalltalk");

    try {
      for (const user of [alice, bob]) {
        await joinChannel(user, channel);
      }
      await installAudibleMicrophone(alice);

      const aliceCall = await joinGroupCall(alice);
      await expect(groupCallWindow(aliceCall)).toBeVisible();
      const bobCall = await joinGroupCall(bob);
      await expect(groupCallWindow(bobCall)).toBeVisible();
      await openPeopleSection(bobCall);

      await expect
        .poll(() => remoteVideoLive(bobCall), { timeout: 30_000 })
        .toBe(true);

      await expect(remoteVideoTile(bobCall)).toHaveAttribute(
        "data-active-speaker",
        "true",
        { timeout: 20_000 },
      );
      await expect(participantRow(bobCall, alice.nick)).toHaveAttribute(
        "data-active-speaker",
        "true",
      );
    } finally {
      await closeGroupCallUsers([alice, bob]);
    }
  });

  test("speaker view can be picked before joining and the call opens in it", async ({
    browser,
  }) => {
    const alice = await newGroupCallUser(browser, "gcpsa");
    const channel = uniqueChannel("gcallpjspeaker");

    try {
      await joinChannel(alice, channel);
      const aliceCall = await openPrejoin(alice);
      await aliceCall
        .getByTestId("group-call-prejoin-advanced")
        .locator("summary")
        .click();
      await aliceCall
        .getByTestId("group-call-prejoin-layout")
        .selectOption("speaker");
      await groupCallPrejoinJoin(aliceCall).click();

      await expect(groupCallWindow(aliceCall)).toBeVisible();
      await expect(groupCallWebRTC(aliceCall)).toHaveAttribute(
        "data-layout-mode",
        "speaker",
        { timeout: 10_000 },
      );
      await expect(groupCallLayoutSpeaker(aliceCall).first()).toHaveAttribute(
        "aria-pressed",
        "true",
      );
    } finally {
      await closeGroupCallUsers([alice]);
    }
  });

  test("a call tab that loses the server says so until it is back", async ({
    browser,
  }) => {
    test.setTimeout(120_000);
    const alice = await newGroupCallUser(browser, "gcdra");
    const bob = await newGroupCallUser(browser, "gcdrb");
    const channel = uniqueChannel("gcalldrop");

    try {
      for (const user of [alice, bob]) {
        await joinChannel(user, channel);
      }

      await joinGroupCall(alice);
      const bobCall = await joinGroupCall(bob);
      await expect(groupCallWindow(bobCall)).toBeVisible();
      await expect(groupCallStatusAnnouncer(bobCall)).toContainText(
        "Connected",
        { timeout: 20_000 },
      );
      await expect(
        bobCall.getByTestId("group-call-status-offline"),
      ).toBeHidden();

      // The page's own link to the server goes: what a dropped network does
      // to it once the socket notices. Emulating "offline" leaves an open
      // socket standing, so the socket itself is closed.
      await bobCall.evaluate(() =>
        (
          window as typeof window & { liveSocket: { disconnect: () => void } }
        ).liveSocket.disconnect(),
      );
      await expect(
        bobCall.getByTestId("group-call-status-offline"),
      ).toBeVisible({ timeout: 20_000 });
      await expect(groupCallStatusAnnouncer(bobCall)).toHaveText(
        /Reconnecting to the server/,
      );
      await expect(groupCallMediaControls(bobCall)).toHaveCSS(
        "pointer-events",
        "none",
      );

      await bobCall.evaluate(() =>
        (
          window as typeof window & { liveSocket: { connect: () => void } }
        ).liveSocket.connect(),
      );
      await expect(bobCall.getByTestId("group-call-status-offline")).toBeHidden(
        { timeout: 30_000 },
      );
      await expect(groupCallStatusAnnouncer(bobCall)).toContainText(
        "Connected",
      );
      await expect(groupCallMediaControls(bobCall)).toHaveCSS(
        "pointer-events",
        "auto",
      );
    } finally {
      await closeGroupCallUsers([alice, bob]);
    }
  });

  test("closing the call tab by accident and reopening it puts you back in your seat", async ({
    browser,
  }) => {
    test.setTimeout(120_000);
    const alice = await newGroupCallUser(browser, "gcrea");
    const bob = await newGroupCallUser(browser, "gcreb");
    const channel = uniqueChannel("gcallreopen");

    try {
      for (const user of [alice, bob]) {
        await joinChannel(user, channel);
      }

      const aliceCall = await joinGroupCall(alice);
      const bobCall = await joinGroupCall(bob);
      await expect
        .poll(() => remoteVideoLive(aliceCall), { timeout: 30_000 })
        .toBe(true);
      const address = conferenceAddress(bobCall);

      // The lock keeps newcomers out; bob is not one.
      await openModerationMenu(aliceCall);
      await groupCallLockToggle(aliceCall).click();
      await expect(groupCallLockToggle(aliceCall)).toHaveAttribute(
        "aria-checked",
        "true",
      );

      await bobCall.close();
      await aliceCall.waitForTimeout(3_000);

      const reopened = await bob.ctx.newPage();
      await reopened.goto(address);
      await expect(groupCallWindow(reopened)).toBeVisible({ timeout: 20_000 });
      await expect(reopened.getByTestId("group-call-prejoin")).toHaveCount(0);
      await expect(groupCallWebRTC(reopened)).toBeVisible({ timeout: 20_000 });
      for (const call of [aliceCall, reopened]) {
        await expect
          .poll(() => remoteVideoLive(call), { timeout: 45_000 })
          .toBe(true);
      }
      await openPeopleSection(aliceCall);
      await expect(participantRow(aliceCall, bob.nick)).toHaveCount(1);
    } finally {
      await closeGroupCallUsers([alice, bob]);
    }
  });

  test("the chat keeps up with the channel while the call is in its own tab", async ({
    browser,
  }) => {
    test.setTimeout(120_000);
    const alice = await newGroupCallUser(browser, "gcsca");
    const bob = await newGroupCallUser(browser, "gcscb");
    const channel = uniqueChannel("gcallscroll");

    try {
      for (const user of [alice, bob]) {
        await joinChannel(user, channel);
      }
      // Enough of a conversation that the list scrolls.
      for (let i = 0; i < 4; i++) {
        await alice.chat.sendMessage(`earlier from alice ${i}`);
        await bob.chat.sendMessage(`earlier from bob ${i}`);
        await bob.page.waitForTimeout(2_500);
      }

      const aliceCall = await joinGroupCall(alice);
      await expect(groupCallWindow(aliceCall)).toBeVisible();
      await bob.chat.sendMessage("said while alice was on the call");
      await bob.page.waitForTimeout(2_500);

      await alice.page.bringToFront();
      await expect(
        alice.chat.messageList.getByText("said while alice was on the call"),
      ).toBeInViewport({ timeout: 10_000 });

      await bob.page.waitForTimeout(2_500);
      await bob.chat.sendMessage("and one more after she came back");
      await expect(
        alice.chat.messageList.getByText("and one more after she came back"),
      ).toBeInViewport({ timeout: 10_000 });

      await alice.chat.sendMessage("back from the call");
      await expect(
        alice.chat.messageList.getByText("back from the call"),
      ).toBeInViewport({ timeout: 10_000 });
    } finally {
      await closeGroupCallUsers([alice, bob]);
    }
  });

  test("ending the call for everyone says who ended it on every page", async ({
    browser,
  }) => {
    const alice = await newGroupCallUser(browser, "gcena");
    const bob = await newGroupCallUser(browser, "gcenb");
    const channel = uniqueChannel("gcallend");

    try {
      for (const user of [alice, bob]) {
        await joinChannel(user, channel);
      }
      const aliceCall = await joinGroupCall(alice);
      const bobCall = await joinGroupCall(bob);
      await expect
        .poll(() => remoteVideoLive(aliceCall), { timeout: 30_000 })
        .toBe(true);

      await openModerationMenu(aliceCall);
      await aliceCall.getByTestId("group-call-close-room").click();
      await groupCallConfirmLeave(aliceCall).click();

      const mine = aliceCall.getByTestId("call-left");
      await expect(mine).toContainText(
        `You ended the conference in ${channel} for everyone.`,
        { timeout: 15_000 },
      );
      const theirs = bobCall.getByTestId("call-left");
      await expect(theirs).toContainText(
        `${alice.nick} ended the conference in ${channel} for everyone.`,
        { timeout: 15_000 },
      );
      for (const page of [mine, theirs]) {
        await expect(page).not.toContainText("still at this address");
      }
    } finally {
      await closeGroupCallUsers([alice, bob]);
    }
  });
});

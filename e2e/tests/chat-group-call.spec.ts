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

function groupCallLeave(page: Page) {
  return page.getByTestId("group-call-leave");
}

function groupCallAudioToggle(page: Page) {
  return page.getByTestId("group-call-audio-toggle");
}

function groupCallVideoToggle(page: Page) {
  return page.getByTestId("group-call-video-toggle");
}

function groupCallConfirmLeave(page: Page) {
  return page.getByTestId("group-call-confirm-dialog-confirm");
}

function groupCallTaskbarButton(page: Page) {
  return page.getByTestId("group-call-taskbar");
}

function groupCallStatusBar(page: Page) {
  return page.getByTestId("status-bar-group-call");
}

function groupCallLayoutGrid(page: Page) {
  return page.getByTestId("group-call-layout-grid");
}

function groupCallLayoutFocus(page: Page) {
  return page.getByTestId("group-call-layout-focus");
}

function groupCallLayoutSidebar(page: Page) {
  return page.getByTestId("group-call-layout-sidebar");
}

function groupCallSelfViewToggle(page: Page) {
  return page.getByTestId("group-call-self-view-toggle");
}

function groupCallClearFocus(page: Page) {
  return page.getByTestId("group-call-clear-focus");
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

async function participantMediaEnabled(
  page: Page,
  nickname: string,
  kind: "audio" | "video",
) {
  const attr = kind === "audio" ? "data-media-audio" : "data-media-video";
  return participantRow(page, nickname).getAttribute(attr);
}

test.describe("Channel group calls", () => {
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

      await groupCallButton(alice.page).click();
      await expect(groupCallWindow(alice.page)).toBeVisible();
      await expect(groupCallTaskbarButton(alice.page)).toBeVisible();
      await expect(groupCallTaskbarButton(alice.page)).toContainText(channel);
      await expect(groupCallStatusBar(alice.page)).toContainText("Call:");
      await expect(alice.page.getByTestId("group-call-webrtc")).toBeVisible();

      await groupCallButton(bob.page).click();
      await expect(groupCallWindow(bob.page)).toBeVisible();
      await expect(groupCallTaskbarButton(bob.page)).toBeVisible();
      await expect(groupCallTaskbarButton(bob.page)).toContainText(channel);
      await expect(groupCallStatusBar(bob.page)).toContainText("Call:");
      await expect(bob.page.getByTestId("group-call-webrtc")).toBeVisible();

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

      await groupCallButton(alice.page).click();
      await expect(groupCallWindow(alice.page)).toBeVisible();

      await groupCallButton(bob.page).click();
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

      await groupCallButton(alice.page).click();
      await expect(groupCallWindow(alice.page)).toBeVisible();

      await groupCallButton(bob.page).click();
      await expect(groupCallWindow(bob.page)).toBeVisible();

      await expect
        .poll(() => remoteVideoLive(alice.page), { timeout: 30_000 })
        .toBe(true);
      await expect
        .poll(() => remoteVideoLive(bob.page), { timeout: 30_000 })
        .toBe(true);

      await groupCallButton(carol.page).click();
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
});

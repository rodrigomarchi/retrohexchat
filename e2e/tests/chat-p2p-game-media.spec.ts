import { Browser, BrowserContext, Page, expect, test } from "@playwright/test";
import { ChatPage } from "../pages/ChatPage";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import {
  GameSessionPage,
  openGameSessionFromInvite,
} from "../pages/GameSessionPage";

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  page: Page;
  nick: string;
};

async function installMockMedia(ctx: BrowserContext) {
  await ctx.addInitScript(() => {
    (window as any).__mockMediaSources = [];

    function createSyntheticAudioTrack() {
      const AudioContextCtor =
        window.AudioContext || (window as any).webkitAudioContext;
      const audioContext = new AudioContextCtor();
      const oscillator = audioContext.createOscillator();
      const gain = audioContext.createGain();
      const destination = audioContext.createMediaStreamDestination();

      oscillator.frequency.value = 220;
      gain.gain.value = 0.01;
      oscillator.connect(gain);
      gain.connect(destination);
      oscillator.start();

      (window as any).__mockMediaSources.push({ audioContext, oscillator });

      return destination.stream.getAudioTracks()[0];
    }

    function createSyntheticVideoTrack() {
      const canvas = document.createElement("canvas");
      canvas.width = 320;
      canvas.height = 240;
      const context = canvas.getContext("2d");
      let frame = 0;

      const paint = () => {
        if (!context) return;

        frame += 1;
        context.fillStyle = "#001818";
        context.fillRect(0, 0, canvas.width, canvas.height);
        context.fillStyle = "#00ffff";
        context.fillRect((frame * 7) % canvas.width, 32, 64, 64);
        context.fillStyle = "#ffffff";
        context.font = "16px monospace";
        context.fillText(`game media ${frame}`, 16, 180);
      };

      paint();
      const timer = window.setInterval(paint, 100);
      const stream = canvas.captureStream(10);
      const track = stream.getVideoTracks()[0];
      track.addEventListener("ended", () => window.clearInterval(timer));

      (window as any).__mockMediaSources.push({ canvas, timer });

      return track;
    }

    const mediaDevices = {
      getUserMedia: async (constraints: MediaStreamConstraints = {}) => {
        const stream = new MediaStream();

        if (constraints.audio) {
          stream.addTrack(createSyntheticAudioTrack());
        }

        if (constraints.video) {
          stream.addTrack(createSyntheticVideoTrack());
        }

        (window as any).__mockGetUserMediaCalls =
          ((window as any).__mockGetUserMediaCalls || 0) + 1;

        return stream;
      },
      enumerateDevices: async () => [
        {
          deviceId: "mock-mic",
          groupId: "mock-game-media",
          kind: "audioinput",
          label: "Mock Microphone",
          toJSON() {
            return this;
          },
        },
        {
          deviceId: "mock-camera",
          groupId: "mock-game-media",
          kind: "videoinput",
          label: "Mock Camera",
          toJSON() {
            return this;
          },
        },
      ],
      addEventListener: () => {},
      removeEventListener: () => {},
    };

    Object.defineProperty(navigator, "mediaDevices", {
      configurable: true,
      value: mediaDevices,
    });
  });
}

async function newSignedInMediaUser(
  browser: Browser,
  prefix = "p2pgm",
): Promise<TestUser> {
  const ctx = await browser.newContext({
    permissions: ["microphone", "camera"],
  });
  await installMockMedia(ctx);

  const page: Page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();

  return { chat, ctx, page, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

async function openSharedGame(alice: TestUser, bob: TestUser) {
  await alice.chat.sendMessage(`/game ${bob.nick}`);
  await alice.chat.expectTabVisible(bob.nick);
  await alice.chat.expectTabSelected(bob.nick);
  await alice.chat.expectMessageVisible("Game session started");

  const aliceLink = alice.chat
    .p2pInviteCard()
    .getByRole("link", { name: "Join lobby" });
  await expect(aliceLink).toHaveAttribute("href", /^\/game\/[A-Za-z0-9_-]+$/);
  const inviteHref = await aliceLink.getAttribute("href");

  await bob.chat.expectTabVisible(alice.nick);
  await bob.chat.expectTabSelected("#lobby");
  await bob.chat.switchToTab(alice.nick);

  const bobLink = bob.chat
    .p2pInviteCard()
    .getByRole("link", { name: "Join lobby" });
  await expect(bobLink).toHaveAttribute("href", inviteHref || "");

  const aliceGame = await openGameSessionFromInvite(alice.page, aliceLink);
  const bobGame = await openGameSessionFromInvite(bob.page, bobLink);

  await aliceGame.selectGame("hex_pong");
  await bobGame.acceptGame("Hex Pong");
  await aliceGame.expectGameCanvas("hex_pong");
  await bobGame.expectGameCanvas("hex_pong");
  await aliceGame.expectCanvasPainted();
  await bobGame.expectCanvasPainted();

  return { aliceGame, bobGame };
}

test.describe("P2P game media", () => {
  test("video call controls run inside an active shared game without closing the canvas", async ({
    browser,
  }) => {
    const alice = await newSignedInMediaUser(browser, "gmva");
    const bob = await newSignedInMediaUser(browser, "gmvb");
    let aliceGame: GameSessionPage | undefined;
    let bobGame: GameSessionPage | undefined;

    try {
      ({ aliceGame, bobGame } = await openSharedGame(alice, bob));

      await aliceGame.expectMediaIdle();
      await bobGame.expectMediaIdle();

      await aliceGame.startVideoButton.click();
      await aliceGame.expectVideoCallActive();
      await aliceGame.expectLocalVideoStreamTracks();
      await bobGame.expectIncomingVideoCall();
      await bobGame.expectRemoteVideoStreamTrack();
      await bobGame.expectRemoteAudioTrack();

      await aliceGame.layoutSideBySideButton.click();
      await expect(aliceGame.mediaDock).toHaveClass(/game-media--side_by_side/);

      await aliceGame.layoutMaximizedButton.click();
      await expect(aliceGame.mediaDock).toHaveClass(/game-media--maximized/);

      await aliceGame.endCallButton.click();
      await aliceGame.expectMediaIdle();
      await bobGame.expectMediaIdle();
      await expect(aliceGame.canvas).toBeVisible();
      await expect(bobGame.canvas).toBeVisible();
    } finally {
      await aliceGame?.page.close().catch(() => {});
      await bobGame?.page.close().catch(() => {});
      await closeUsers([alice, bob]);
    }
  });

  test("peer-started video call renegotiates through the host and delivers media tracks", async ({
    browser,
  }) => {
    const alice = await newSignedInMediaUser(browser, "gmha");
    const bob = await newSignedInMediaUser(browser, "gmhb");
    let aliceGame: GameSessionPage | undefined;
    let bobGame: GameSessionPage | undefined;

    try {
      ({ aliceGame, bobGame } = await openSharedGame(alice, bob));

      await aliceGame.expectMediaIdle();
      await bobGame.expectMediaIdle();

      await bobGame.startVideoButton.click();
      await bobGame.expectVideoCallActive();
      await bobGame.expectLocalVideoStreamTracks();
      await aliceGame.expectIncomingVideoCall();
      await aliceGame.expectRemoteVideoStreamTrack();
      await aliceGame.expectRemoteAudioTrack();

      await bobGame.endCallButton.click();
      await aliceGame.expectMediaIdle();
      await bobGame.expectMediaIdle();
      await expect(aliceGame.canvas).toBeVisible();
      await expect(bobGame.canvas).toBeVisible();
    } finally {
      await aliceGame?.page.close().catch(() => {});
      await bobGame?.page.close().catch(() => {});
      await closeUsers([alice, bob]);
    }
  });
});

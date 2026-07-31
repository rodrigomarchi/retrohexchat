import {
  Browser,
  BrowserContext,
  BrowserContextOptions,
  Page,
  expect,
} from "@playwright/test";
import { ChatPage } from "../pages/ChatPage";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";

export type P2PTestUser = {
  chat: ChatPage;
  connect: ConnectPage;
  ctx: BrowserContext;
  page: Page;
  nick: string;
  password: string;
};

type NewP2PUserOptions = {
  acceptDownloads?: boolean;
  locale?: string;
  media?:
    | boolean
    | "camera-denied"
    | "camera-missing"
    | "camera-busy"
    | "mic-missing"
    | "mic-busy";
  permissions?: BrowserContextOptions["permissions"];
};

export async function installSyntheticMedia(ctx: BrowserContext) {
  await ctx.addInitScript(() => {
    type MockWindow = typeof window & {
      __mockGetUserMediaCalls?: number;
      __mockMediaSources?: unknown[];
      webkitAudioContext?: typeof AudioContext;
    };

    const mockWindow = window as MockWindow;
    mockWindow.__mockMediaSources = [];

    function createSyntheticAudioTrack() {
      const AudioContextCtor =
        window.AudioContext || mockWindow.webkitAudioContext;
      const audioContext = new AudioContextCtor();
      const oscillator = audioContext.createOscillator();
      const gain = audioContext.createGain();
      const destination = audioContext.createMediaStreamDestination();

      oscillator.frequency.value = 220;
      gain.gain.value = 0.01;
      oscillator.connect(gain);
      gain.connect(destination);
      oscillator.start();

      mockWindow.__mockMediaSources?.push({ audioContext, oscillator });

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
        context.fillText(`p2p media ${frame}`, 16, 180);
      };

      paint();
      const timer = window.setInterval(paint, 100);
      const stream = canvas.captureStream(10);
      const track = stream.getVideoTracks()[0];
      track.addEventListener("ended", () => window.clearInterval(timer));

      mockWindow.__mockMediaSources?.push({ canvas, timer });

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

        mockWindow.__mockGetUserMediaCalls =
          (mockWindow.__mockGetUserMediaCalls || 0) + 1;

        return stream;
      },
      getDisplayMedia: async () => {
        const stream = new MediaStream();
        stream.addTrack(createSyntheticVideoTrack());
        return stream;
      },
      enumerateDevices: async () => [
        {
          deviceId: "mock-mic",
          groupId: "mock-p2p-media",
          kind: "audioinput",
          label: "Mock Microphone",
          toJSON() {
            return this;
          },
        },
        {
          deviceId: "mock-camera",
          groupId: "mock-p2p-media",
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

export async function installAudioOnlyCameraDeniedMedia(ctx: BrowserContext) {
  await ctx.addInitScript(() => {
    type MockWindow = typeof window & {
      __mockGetUserMediaCalls?: number;
      __mockMediaSources?: unknown[];
      webkitAudioContext?: typeof AudioContext;
    };

    const mockWindow = window as MockWindow;
    mockWindow.__mockMediaSources = [];

    function createSyntheticAudioTrack() {
      const AudioContextCtor =
        window.AudioContext || mockWindow.webkitAudioContext;
      const audioContext = new AudioContextCtor();
      const oscillator = audioContext.createOscillator();
      const gain = audioContext.createGain();
      const destination = audioContext.createMediaStreamDestination();

      oscillator.frequency.value = 330;
      gain.gain.value = 0.01;
      oscillator.connect(gain);
      gain.connect(destination);
      oscillator.start();

      mockWindow.__mockMediaSources?.push({ audioContext, oscillator });

      return destination.stream.getAudioTracks()[0];
    }

    const mediaDevices = {
      getUserMedia: async (constraints: MediaStreamConstraints = {}) => {
        if (constraints.video) {
          throw new DOMException("Camera permission denied", "NotAllowedError");
        }

        const stream = new MediaStream();
        if (constraints.audio) {
          stream.addTrack(createSyntheticAudioTrack());
        }

        mockWindow.__mockGetUserMediaCalls =
          (mockWindow.__mockGetUserMediaCalls || 0) + 1;

        return stream;
      },
      enumerateDevices: async () => [
        {
          deviceId: "mock-mic",
          groupId: "mock-p2p-media",
          kind: "audioinput",
          label: "Mock Microphone",
          toJSON() {
            return this;
          },
        },
        {
          deviceId: "mock-camera-denied",
          groupId: "mock-p2p-media",
          kind: "videoinput",
          label: "Blocked Camera",
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

export async function installMediaWithDeviceFailure(
  ctx: BrowserContext,
  failure: "camera-missing" | "camera-busy" | "mic-missing" | "mic-busy",
) {
  await ctx.addInitScript((failureMode) => {
    type MockWindow = typeof window & {
      __mockGetUserMediaCalls?: number;
      __mockMediaSources?: unknown[];
      webkitAudioContext?: typeof AudioContext;
    };

    const mockWindow = window as MockWindow;
    mockWindow.__mockMediaSources = [];

    function createSyntheticAudioTrack() {
      const AudioContextCtor =
        window.AudioContext || mockWindow.webkitAudioContext;
      const audioContext = new AudioContextCtor();
      const oscillator = audioContext.createOscillator();
      const gain = audioContext.createGain();
      const destination = audioContext.createMediaStreamDestination();

      oscillator.frequency.value = 260;
      gain.gain.value = 0.01;
      oscillator.connect(gain);
      gain.connect(destination);
      oscillator.start();

      mockWindow.__mockMediaSources?.push({ audioContext, oscillator });

      return destination.stream.getAudioTracks()[0];
    }

    function createSyntheticVideoTrack() {
      const canvas = document.createElement("canvas");
      canvas.width = 320;
      canvas.height = 240;
      const context = canvas.getContext("2d");

      if (context) {
        context.fillStyle = "#101820";
        context.fillRect(0, 0, canvas.width, canvas.height);
        context.fillStyle = "#ffd166";
        context.fillRect(40, 40, 120, 80);
      }

      const stream = canvas.captureStream(5);
      return stream.getVideoTracks()[0];
    }

    function failureFor(kind: "audio" | "video") {
      if (kind === "video" && failureMode === "camera-missing") {
        return new DOMException("No camera found", "NotFoundError");
      }

      if (kind === "video" && failureMode === "camera-busy") {
        return new DOMException("Camera busy", "NotReadableError");
      }

      if (kind === "audio" && failureMode === "mic-missing") {
        return new DOMException("No microphone found", "NotFoundError");
      }

      if (kind === "audio" && failureMode === "mic-busy") {
        return new DOMException("Microphone busy", "NotReadableError");
      }

      return null;
    }

    const mediaDevices = {
      getUserMedia: async (constraints: MediaStreamConstraints = {}) => {
        const videoFailure = constraints.video ? failureFor("video") : null;
        if (videoFailure) throw videoFailure;

        const audioFailure = constraints.audio ? failureFor("audio") : null;
        if (audioFailure) throw audioFailure;

        const stream = new MediaStream();
        if (constraints.audio) stream.addTrack(createSyntheticAudioTrack());
        if (constraints.video) stream.addTrack(createSyntheticVideoTrack());

        mockWindow.__mockGetUserMediaCalls =
          (mockWindow.__mockGetUserMediaCalls || 0) + 1;

        return stream;
      },
      enumerateDevices: async () => [
        {
          deviceId: "mock-mic",
          groupId: "mock-p2p-media",
          kind: "audioinput",
          label: "Mock Microphone",
          toJSON() {
            return this;
          },
        },
        {
          deviceId: "mock-camera",
          groupId: "mock-p2p-media",
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
  }, failure);
}

export async function newP2PUser(
  browser: Browser,
  prefix = "p2p",
  options: NewP2PUserOptions = {},
): Promise<P2PTestUser> {
  const contextOptions: BrowserContextOptions = {};

  if (options.acceptDownloads !== undefined) {
    contextOptions.acceptDownloads = options.acceptDownloads;
  }

  if (options.locale) {
    contextOptions.locale = options.locale.replace("_", "-");
  }

  if (options.media) {
    contextOptions.permissions = options.permissions || [
      "microphone",
      "camera",
    ];
  }

  const ctx = await browser.newContext(contextOptions);

  if (options.media === "camera-denied") {
    await installAudioOnlyCameraDeniedMedia(ctx);
  } else if (
    options.media === "camera-missing" ||
    options.media === "camera-busy" ||
    options.media === "mic-missing" ||
    options.media === "mic-busy"
  ) {
    await installMediaWithDeviceFailure(ctx, options.media);
  } else if (options.media) {
    await installSyntheticMedia(ctx);
  }

  const page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);
  const password = "pass12345";

  await connect.open(options.locale);
  await connect.enterNickname(nick);
  await connect.registerWithPassword(password);
  await chat.waitUntilConnected();

  return { chat, connect, ctx, page, nick, password };
}

export async function closeP2PUsers(users: P2PTestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close().catch(() => {})));
}

// --- Session entry ---

export function statusBarP2P(page: Page) {
  return page.getByTestId("status-bar-p2p");
}

export async function sendP2PInvite(user: P2PTestUser, targetNick: string) {
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

export async function acceptP2PInvite(
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

// --- Remote media observation ---

/** A remote track only leaves `muted` once RTP actually arrives. */
export async function remoteVideoLive(page: Page) {
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

/** Samples the decoded picture: a live track can still render black. */
export async function remoteVideoHasVisibleFrame(page: Page) {
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

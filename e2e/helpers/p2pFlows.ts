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
  /** Runs against the fresh context, before the first navigation. */
  instrument?: (ctx: BrowserContext) => Promise<void>;
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

  if (options.instrument) await options.instrument(ctx);

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

/**
 * The card in the conversation is the door, and it opens a tab of its own.
 *
 * The chat has no window for a session any more: `/p2p <nick>` writes the
 * request into the private message with the session's own address on it, and
 * both people — the one who asked as much as the one who was asked — enter by
 * following that. The page is returned so a spec drives the session where the
 * session actually is, and the chat stays the chat.
 */
export async function enterP2PSession(user: P2PTestUser): Promise<Page> {
  const entry = user.page.getByTestId("p2p-peer-entry");

  await expect(entry).toBeVisible({ timeout: 20_000 });
  await expect(entry).toHaveAttribute("href", /\/p2p\//);

  const [session] = await Promise.all([
    user.ctx.waitForEvent("page"),
    entry.click(),
  ]);

  await session.waitForLoadState("domcontentloaded");
  await expect(session.getByTestId("p2p-call-window")).toBeVisible();

  return session;
}

/**
 * Creating the session IS inviting, so `/p2p <nick>` sends the request and
 * writes its card. The host then follows that card into the starting room,
 * where the devices are chosen while waiting for an answer — which is why
 * Ready is pressed here and Start is not: Start needs the other side too.
 */
export async function sendP2PInvite(
  user: P2PTestUser,
  targetNick: string,
): Promise<Page> {
  await user.chat.sendMessage(`/p2p ${targetNick}`);

  const session = await enterP2PSession(user);

  await expect(session.getByTestId("p2p-starting-room")).toBeVisible();
  await expect(session.getByTestId("p2p-room-waiting")).toContainText(
    "Choose your devices",
  );
  await session.getByTestId("p2p-room-ready").click();
  await expect(session.getByTestId("p2p-room-waiting")).toContainText(
    `Waiting for ${targetNick} to accept the invite.`,
  );
  await expect(session.getByTestId("p2p-room-start")).toBeDisabled();

  return session;
}

/**
 * The host releases the first offer. The button only enables once the domain
 * has seen both hooks report ready, so waiting for it to become enabled is
 * waiting for the gate the negotiation has always had.
 */
export async function startP2PSession(session: Page) {
  await expect(session.getByTestId("p2p-room-start")).toBeEnabled({
    timeout: 20_000,
  });
  await session.getByTestId("p2p-room-start").click();
  await expect(session.getByTestId("p2p-session-console")).toBeVisible();
}

/**
 * The invited side follows the same card. There is nothing to accept: entering
 * is the consent, and the only thing the chat still offers about the invite is
 * refusing it.
 */
export async function acceptP2PInvite(
  user: P2PTestUser,
  options: { audio?: boolean; video?: boolean; turnOnly?: boolean } = {},
): Promise<Page> {
  await expect(user.page.getByTestId("p2p-peer-entry")).toHaveAttribute(
    "data-p2p-state",
    "pending",
  );
  await expect(user.page.getByTestId("session-card-accept")).toHaveCount(0);
  await expect(user.page.getByTestId("session-card-decline")).toHaveCount(0);

  const session = await enterP2PSession(user);

  await expect(session.getByTestId("p2p-starting-room")).toBeVisible();
  await expect(session.getByTestId("p2p-setup-preview")).toBeVisible();

  if (options.audio !== undefined) {
    const audioToggle = session.getByTestId("p2p-setup-audio");
    await audioToggle.setChecked(options.audio);
    if (options.audio) {
      await expect(audioToggle).toBeChecked();
    } else {
      await expect(audioToggle).not.toBeChecked();
    }
  }

  if (options.video !== undefined) {
    const videoToggle = session.getByTestId("p2p-setup-video");
    await videoToggle.setChecked(options.video);
    if (options.video) {
      await expect(videoToggle).toBeChecked();
    } else {
      await expect(videoToggle).not.toBeChecked();
    }
  }

  if (options.turnOnly !== undefined) {
    await session.getByTestId("p2p-setup-advanced").locator("summary").click();
    await expect(session.getByTestId("p2p-setup-turn-only")).toBeEnabled();
    await session
      .getByTestId("p2p-setup-turn-only")
      .setChecked(options.turnOnly);
  }

  await session.getByTestId("p2p-room-ready").click();
  // The guest never gets Start: the creator is always the offerer.
  await expect(session.getByTestId("p2p-room-start")).toHaveCount(0);

  return session;
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

/**
 * Records the SDP of every local offer, so a test can assert what the *first*
 * one carried. Media added only after the connection settles rides a second
 * negotiation round, which the picture waits out.
 */
export async function recordLocalOffers(ctx: BrowserContext) {
  await ctx.addInitScript(() => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const recorder = window as any;
    recorder.__localOffers = [];

    const original = RTCPeerConnection.prototype.setLocalDescription;
    RTCPeerConnection.prototype.setLocalDescription = async function patched(
      ...args: unknown[]
    ) {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const result = await (original as any).apply(this, args);
      const description = this.localDescription;
      if (description?.type === "offer") {
        recorder.__localOffers.push(description.sdp);
      }
      return result;
    };
  });
}

export async function localOffers(page: Page): Promise<string[]> {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return page.evaluate(() => (window as any).__localOffers || []);
}

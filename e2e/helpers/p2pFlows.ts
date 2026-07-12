import {
  Browser,
  BrowserContext,
  BrowserContextOptions,
  Page,
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

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword(password);
  await chat.waitUntilConnected();

  return { chat, connect, ctx, page, nick, password };
}

export async function closeP2PUsers(users: P2PTestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close().catch(() => {})));
}

import {
  Browser,
  BrowserContext,
  BrowserContextOptions,
  Locator,
  Page,
  expect,
} from '@playwright/test';
import { ChatPage } from '../pages/ChatPage';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import {
  P2PLobbyPage,
  openP2PLobbyFromInvite,
} from '../pages/P2PLobbyPage';
import {
  GameSessionPage,
  openGameSessionFromInvite,
} from '../pages/GameSessionPage';

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
    | 'camera-denied'
    | 'camera-missing'
    | 'camera-busy'
    | 'mic-missing'
    | 'mic-busy';
  permissions?: BrowserContextOptions['permissions'];
};

type P2PSessionKind = 'generic' | 'audio_call' | 'file_transfer';

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
      const canvas = document.createElement('canvas');
      canvas.width = 320;
      canvas.height = 240;
      const context = canvas.getContext('2d');
      let frame = 0;

      const paint = () => {
        if (!context) return;

        frame += 1;
        context.fillStyle = '#001818';
        context.fillRect(0, 0, canvas.width, canvas.height);
        context.fillStyle = '#00ffff';
        context.fillRect((frame * 7) % canvas.width, 32, 64, 64);
        context.fillStyle = '#ffffff';
        context.font = '16px monospace';
        context.fillText(`p2p media ${frame}`, 16, 180);
      };

      paint();
      const timer = window.setInterval(paint, 100);
      const stream = canvas.captureStream(10);
      const track = stream.getVideoTracks()[0];
      track.addEventListener('ended', () => window.clearInterval(timer));

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
      enumerateDevices: async () => [
        {
          deviceId: 'mock-mic',
          groupId: 'mock-p2p-media',
          kind: 'audioinput',
          label: 'Mock Microphone',
          toJSON() {
            return this;
          },
        },
        {
          deviceId: 'mock-camera',
          groupId: 'mock-p2p-media',
          kind: 'videoinput',
          label: 'Mock Camera',
          toJSON() {
            return this;
          },
        },
      ],
      addEventListener: () => {},
      removeEventListener: () => {},
    };

    Object.defineProperty(navigator, 'mediaDevices', {
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
          throw new DOMException('Camera permission denied', 'NotAllowedError');
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
          deviceId: 'mock-mic',
          groupId: 'mock-p2p-media',
          kind: 'audioinput',
          label: 'Mock Microphone',
          toJSON() {
            return this;
          },
        },
        {
          deviceId: 'mock-camera-denied',
          groupId: 'mock-p2p-media',
          kind: 'videoinput',
          label: 'Blocked Camera',
          toJSON() {
            return this;
          },
        },
      ],
      addEventListener: () => {},
      removeEventListener: () => {},
    };

    Object.defineProperty(navigator, 'mediaDevices', {
      configurable: true,
      value: mediaDevices,
    });
  });
}

export async function installMediaWithDeviceFailure(
  ctx: BrowserContext,
  failure:
    | 'camera-missing'
    | 'camera-busy'
    | 'mic-missing'
    | 'mic-busy',
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
      const canvas = document.createElement('canvas');
      canvas.width = 320;
      canvas.height = 240;
      const context = canvas.getContext('2d');

      if (context) {
        context.fillStyle = '#101820';
        context.fillRect(0, 0, canvas.width, canvas.height);
        context.fillStyle = '#ffd166';
        context.fillRect(40, 40, 120, 80);
      }

      const stream = canvas.captureStream(5);
      return stream.getVideoTracks()[0];
    }

    function failureFor(kind: 'audio' | 'video') {
      if (kind === 'video' && failureMode === 'camera-missing') {
        return new DOMException('No camera found', 'NotFoundError');
      }

      if (kind === 'video' && failureMode === 'camera-busy') {
        return new DOMException('Camera busy', 'NotReadableError');
      }

      if (kind === 'audio' && failureMode === 'mic-missing') {
        return new DOMException('No microphone found', 'NotFoundError');
      }

      if (kind === 'audio' && failureMode === 'mic-busy') {
        return new DOMException('Microphone busy', 'NotReadableError');
      }

      return null;
    }

    const mediaDevices = {
      getUserMedia: async (constraints: MediaStreamConstraints = {}) => {
        const videoFailure = constraints.video ? failureFor('video') : null;
        if (videoFailure) throw videoFailure;

        const audioFailure = constraints.audio ? failureFor('audio') : null;
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
          deviceId: 'mock-mic',
          groupId: 'mock-p2p-media',
          kind: 'audioinput',
          label: 'Mock Microphone',
          toJSON() {
            return this;
          },
        },
        {
          deviceId: 'mock-camera',
          groupId: 'mock-p2p-media',
          kind: 'videoinput',
          label: 'Mock Camera',
          toJSON() {
            return this;
          },
        },
      ],
      addEventListener: () => {},
      removeEventListener: () => {},
    };

    Object.defineProperty(navigator, 'mediaDevices', {
      configurable: true,
      value: mediaDevices,
    });
  }, failure);
}

export async function newP2PUser(
  browser: Browser,
  prefix = 'p2p',
  options: NewP2PUserOptions = {},
): Promise<P2PTestUser> {
  const contextOptions: BrowserContextOptions = {};

  if (options.acceptDownloads !== undefined) {
    contextOptions.acceptDownloads = options.acceptDownloads;
  }

  if (options.media) {
    contextOptions.permissions = options.permissions || ['microphone', 'camera'];
  }

  const ctx = await browser.newContext(contextOptions);

  if (options.media === 'camera-denied') {
    await installAudioOnlyCameraDeniedMedia(ctx);
  } else if (
    options.media === 'camera-missing' ||
    options.media === 'camera-busy' ||
    options.media === 'mic-missing' ||
    options.media === 'mic-busy'
  ) {
    await installMediaWithDeviceFailure(ctx, options.media);
  } else if (options.media) {
    await installSyntheticMedia(ctx);
  }

  const page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);
  const password = 'pass12345';

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword(password);
  await chat.waitUntilConnected();

  return { chat, connect, ctx, page, nick, password };
}

export async function closeP2PUsers(users: P2PTestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close().catch(() => {})));
}

export async function openP2PLobbiesFromCommand(
  initiator: P2PTestUser,
  receiver: P2PTestUser,
  kind: P2PSessionKind = 'generic',
) {
  await initiator.chat.sendMessage(`${commandFor(kind)} ${receiver.nick}`);
  await initiator.chat.expectTabVisible(receiver.nick);
  await initiator.chat.expectTabSelected(receiver.nick);
  await initiator.chat.expectMessageVisible(
    `P2P invite sent to ${receiver.nick}. Waiting for response...`,
  );

  const startedText = sessionStartedText(kind);
  if (startedText) {
    await initiator.chat.expectMessageVisible(startedText);
  }

  return openP2PLobbiesFromInviteCards(
    initiator,
    receiver,
    /^\/p2p\/[A-Za-z0-9_-]+$/,
  );
}

export async function openP2PLobbiesFromInviteCards(
  initiator: P2PTestUser,
  receiver: P2PTestUser,
  hrefPattern: RegExp,
) {
  const initiatorLink = initiator.chat
    .p2pInviteCard()
    .getByRole('link', { name: 'Join lobby' });
  await expect(initiatorLink).toHaveAttribute('href', hrefPattern);
  const inviteHref = await requireHref(initiatorLink);

  await receiver.chat.expectTabVisible(initiator.nick);
  await receiver.chat.switchToTab(initiator.nick);

  const receiverLink = receiver.chat
    .p2pInviteCard()
    .getByRole('link', { name: 'Join lobby' });
  await expect(receiverLink).toHaveAttribute('href', inviteHref);

  const initiatorLobby = await openP2PLobbyFromInvite(
    initiator.page,
    initiatorLink,
  );
  const receiverLobby = await openP2PLobbyFromInvite(receiver.page, receiverLink);

  await initiatorLobby.waitUntilLiveViewConnected();
  await receiverLobby.waitUntilLiveViewConnected();

  return { initiatorLobby, receiverLobby, inviteHref };
}

export async function openGameSessionsFromCommand(
  host: P2PTestUser,
  peer: P2PTestUser,
) {
  await host.chat.sendMessage(`/game ${peer.nick}`);
  await host.chat.expectTabVisible(peer.nick);
  await host.chat.expectTabSelected(peer.nick);
  await host.chat.expectMessageVisible(
    `Game invite sent to ${peer.nick}. Waiting for response...`,
  );
  await host.chat.expectMessageVisible('Game session started');

  const hostLink = host.chat
    .p2pInviteCard()
    .getByRole('link', { name: 'Join lobby' });
  await expect(hostLink).toHaveAttribute('href', /^\/game\/[A-Za-z0-9_-]+$/);
  const inviteHref = await requireHref(hostLink);

  await peer.chat.expectTabVisible(host.nick);
  await peer.chat.expectTabSelected('#lobby');
  await peer.chat.switchToTab(host.nick);

  const peerLink = peer.chat
    .p2pInviteCard()
    .getByRole('link', { name: 'Join lobby' });
  await expect(peerLink).toHaveAttribute('href', inviteHref);

  const hostGame = await openGameSessionFromInvite(host.page, hostLink);
  const peerGame = await openGameSessionFromInvite(peer.page, peerLink);

  return { hostGame, peerGame, inviteHref };
}

async function requireHref(link: Locator) {
  const href = await link.getAttribute('href');

  if (!href) {
    throw new Error('Expected invite link to have an href');
  }

  return href;
}

function commandFor(kind: P2PSessionKind) {
  switch (kind) {
    case 'audio_call':
      return '/call';
    case 'file_transfer':
      return '/sendfile';
    case 'generic':
      return '/p2p';
  }
}

function sessionStartedText(kind: P2PSessionKind) {
  switch (kind) {
    case 'audio_call':
      return 'Audio call started';
    case 'file_transfer':
      return 'File transfer started';
    case 'generic':
      return null;
  }
}

export type OpenP2PLobbiesResult = {
  initiatorLobby: P2PLobbyPage;
  receiverLobby: P2PLobbyPage;
  inviteHref: string;
};

export type OpenGameSessionsResult = {
  hostGame: GameSessionPage;
  peerGame: GameSessionPage;
  inviteHref: string;
};

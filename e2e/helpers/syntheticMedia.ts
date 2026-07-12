import { BrowserContext } from '@playwright/test';

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

    function createSyntheticVideoTrack(label = 'synthetic media') {
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
        context.fillText(`${label} ${frame}`, 16, 180);
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
      getDisplayMedia: async () => {
        const stream = new MediaStream();
        stream.addTrack(createSyntheticVideoTrack('synthetic screen'));
        return stream;
      },
      enumerateDevices: async () => [
        {
          deviceId: 'mock-mic',
          groupId: 'mock-media',
          kind: 'audioinput',
          label: 'Mock Microphone',
          toJSON() {
            return this;
          },
        },
        {
          deviceId: 'mock-camera',
          groupId: 'mock-media',
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

import { BrowserContext } from "@playwright/test";

/**
 * A camera and microphone for people on film.
 *
 * A call needs a camera, and a headless browser has none. The suite's
 * `installSyntheticMedia` paints a moving square labelled "p2p media" and
 * names its devices "Mock Camera" — fine for a test, a giveaway on screen.
 * This paints a broadcast test card instead, captioned with the person's
 * nickname, which reads as part of the app's retro world, and names the
 * devices the way a laptop does.
 */
export async function installTestCard(ctx: BrowserContext, nick: string) {
  await ctx.grantPermissions(["camera", "microphone"]);
  await ctx.addInitScript((caption: string) => {
    const BARS = [
      "#c0c0c0",
      "#c0c000",
      "#00c0c0",
      "#00c000",
      "#c000c0",
      "#c00000",
      "#0000c0",
    ];

    function videoTrack(): MediaStreamTrack {
      const canvas = document.createElement("canvas");
      canvas.width = 640;
      canvas.height = 480;
      const g = canvas.getContext("2d")!;
      const started = Date.now();

      const paint = () => {
        const w = canvas.width;
        const h = canvas.height;
        const barW = w / BARS.length;
        BARS.forEach((colour, i) => {
          g.fillStyle = colour;
          g.fillRect(i * barW, 0, barW + 1, h * 0.62);
        });
        g.fillStyle = "#101010";
        g.fillRect(0, h * 0.62, w, h * 0.38);
        // A scanline drifting down: the picture is live, not a still.
        const line = ((Date.now() - started) / 20) % (h * 0.62);
        g.fillStyle = "rgba(255,255,255,0.18)";
        g.fillRect(0, line, w, 6);

        g.fillStyle = "#ffffff";
        g.font = "bold 44px monospace";
        g.textAlign = "center";
        g.fillText(caption, w / 2, h * 0.79);
        const seconds = Math.floor((Date.now() - started) / 1000);
        const clock = `${String(Math.floor(seconds / 60)).padStart(2, "0")}:${String(seconds % 60).padStart(2, "0")}`;
        g.font = "24px monospace";
        g.fillStyle = "#e03030";
        g.fillText(`● LIVE  ${clock}`, w / 2, h * 0.92);
      };

      paint();
      const timer = window.setInterval(paint, 66);
      const track = canvas.captureStream(15).getVideoTracks()[0];
      track.addEventListener("ended", () => window.clearInterval(timer));
      return track;
    }

    function audioTrack(): MediaStreamTrack {
      const audio = new AudioContext();
      const silence = audio.createGain();
      silence.gain.value = 0;
      const tone = audio.createOscillator();
      tone.connect(silence);
      const out = audio.createMediaStreamDestination();
      silence.connect(out);
      tone.start();
      return out.stream.getAudioTracks()[0];
    }

    const device = (kind: MediaDeviceKind, label: string) => ({
      deviceId: `${kind}-default`,
      groupId: "built-in",
      kind,
      label,
      toJSON() {
        return this;
      },
    });

    Object.defineProperty(navigator, "mediaDevices", {
      configurable: true,
      value: {
        getUserMedia: async (constraints: MediaStreamConstraints = {}) => {
          const stream = new MediaStream();
          if (constraints.audio) stream.addTrack(audioTrack());
          if (constraints.video) stream.addTrack(videoTrack());
          return stream;
        },
        getDisplayMedia: async () => new MediaStream([videoTrack()]),
        enumerateDevices: async () => [
          device("audioinput", "Built-in Microphone"),
          device("videoinput", "HD Webcam"),
        ],
        addEventListener: () => {},
        removeEventListener: () => {},
      },
    });
  }, nick);
}

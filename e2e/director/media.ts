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

/**
 * A camera for the people a scene is about: an animated pixel-art character
 * in a room of their own, instead of a test card.
 *
 * Each nick gets a look (Pixel and lumen are designed; anyone else gets one
 * derived from the nick). The character idles — a slow bob, a blink — and
 * the director makes it talk and wave through `window.__directorCamera`,
 * which every page of the context has. The camera canvas lives in whichever
 * page asked for it (the session tab), so the control is passed on through a
 * BroadcastChannel: same origin, same context, every page hears it — and no
 * other person's context does.
 *
 * Sharing the screen shows a music tracker playing "night drive".
 */
export async function installCharacterCamera(
  ctx: BrowserContext,
  nick: string,
) {
  await ctx.grantPermissions(["camera", "microphone"]);
  await ctx.addInitScript(characterCamera, nick);
}

/** Runs in the page: everything it needs is inside it. */
function characterCamera(nick: string) {
  type Look = {
    skin: string;
    skinShade: string;
    hair: string;
    hairShade: string;
    shirt: string;
    shirtShade: string;
    wall: string;
    wallShade: string;
    accent: string;
    style: "spiky" | "long" | "bob";
    glasses: boolean;
    headphones: boolean;
  };

  const LOOKS: Record<string, Look> = {
    pixel: {
      skin: "#f2c39a",
      skinShade: "#d89b72",
      hair: "#4a2c1a",
      hairShade: "#2e1a0e",
      shirt: "#2f9e5b",
      shirtShade: "#1f6e3f",
      wall: "#24345e",
      wallShade: "#1a2546",
      accent: "#ffcc33",
      style: "spiky",
      glasses: true,
      headphones: false,
    },
    lumen: {
      skin: "#a86b48",
      skinShade: "#87503a",
      hair: "#7a3fd0",
      hairShade: "#55289a",
      shirt: "#e0457b",
      shirtShade: "#a82f5a",
      wall: "#4a2450",
      wallShade: "#371a3c",
      accent: "#ffd23f",
      style: "long",
      glasses: false,
      headphones: true,
    },
  };

  function lookFor(name: string): Look {
    const known = LOOKS[name.toLowerCase()];
    if (known) return known;
    let h = 0;
    for (const ch of name) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
    const pick = <T>(xs: T[], salt: number) => xs[(h >>> salt) % xs.length];
    const skins = [
      ["#f2c39a", "#d89b72"],
      ["#c98e66", "#a8714f"],
      ["#8d5a3b", "#6e432b"],
      ["#ffd9b8", "#e6b48f"],
    ];
    const hairs = [
      ["#1c1c1c", "#000000"],
      ["#d9a63c", "#a87a22"],
      ["#b03a2e", "#7d261e"],
      ["#3d7ad6", "#2a5599"],
    ];
    const shirts = [
      ["#3c78d8", "#2a5599"],
      ["#e67e22", "#b35f14"],
      ["#16a085", "#0e6e5c"],
      ["#8e44ad", "#62307a"],
    ];
    const walls = [
      ["#2c3e50", "#1f2d3a"],
      ["#3b2f2f", "#2a2121"],
      ["#1e4d4d", "#153838"],
    ];
    const [skin, skinShade] = pick(skins, 0);
    const [hair, hairShade] = pick(hairs, 3);
    const [shirt, shirtShade] = pick(shirts, 6);
    const [wall, wallShade] = pick(walls, 9);
    return {
      skin,
      skinShade,
      hair,
      hairShade,
      shirt,
      shirtShade,
      wall,
      wallShade,
      accent: "#ffcc33",
      style: pick(["spiky", "long", "bob"] as const, 12),
      glasses: h % 3 === 0,
      headphones: h % 4 === 1,
    };
  }

  const look = lookFor(nick);

  // What the director asked for, in this page's clock.
  const state = { talkUntil: 0, waveUntil: 0 };
  const channel = new BroadcastChannel("director-camera");
  const apply = (msg: { kind: string; seconds: number }) => {
    const until = Date.now() + msg.seconds * 1000;
    if (msg.kind === "talk") state.talkUntil = until;
    if (msg.kind === "wave") state.waveUntil = until;
  };
  channel.onmessage = (event) => apply(event.data);
  const send = (kind: string, seconds: number) => {
    apply({ kind, seconds });
    channel.postMessage({ kind, seconds });
  };
  Object.defineProperty(window, "__directorCamera", {
    configurable: true,
    value: {
      talk: (seconds = 2) => send("talk", seconds),
      wave: (seconds = 2) => send("wave", seconds),
    },
  });

  // A 40x30 grid of 16-pixel blocks: 640x480, chunky on purpose.
  const B = 16;
  const COLS = 40;
  const ROWS = 30;

  function paintCharacter(g: CanvasRenderingContext2D, now: number) {
    const px = (x: number, y: number, w: number, h: number, c: string) => {
      g.fillStyle = c;
      g.fillRect(x * B, y * B, w * B, h * B);
    };

    // The room: wall, a shelf line, a poster, a lamp glow.
    px(0, 0, COLS, ROWS, look.wall);
    for (let y = 0; y < ROWS; y += 2) px(0, y, COLS, 1, look.wallShade);
    px(0, 21, COLS, 1, look.wallShade);
    px(2, 3, 8, 10, "#101018");
    px(3, 4, 6, 8, look.accent);
    px(4, 6, 4, 1, look.wall);
    px(4, 8, 2, 2, look.wall);
    px(31, 3, 6, 6, "#101018");
    px(32, 4, 4, 4, "#7fd3ff");
    px(34, 4, 1, 4, "#101018");
    px(32, 6, 4, 1, "#101018");

    const bob = Math.floor(now / 700) % 2;
    const blink = now % 3800 < 160;
    const talking = now < state.talkUntil;
    const mouthOpen = talking && Math.floor(now / 130) % 3 !== 2;
    const waving = now < state.waveUntil;
    const y0 = bob;

    // Body and shoulders.
    px(10, 20 + y0, 20, 10, look.shirt);
    px(10, 20 + y0, 20, 1, look.shirtShade);
    px(18, 21 + y0, 4, 2, look.shirtShade);
    // Neck.
    px(18, 18 + y0, 4, 2, look.skinShade);
    // Head.
    px(14, 7 + y0, 12, 11, look.skin);
    px(14, 17 + y0, 12, 1, look.skinShade);
    px(13, 11 + y0, 1, 3, look.skin); // ears
    px(26, 11 + y0, 1, 3, look.skin);

    // Hair.
    if (look.style === "spiky") {
      px(14, 5 + y0, 12, 3, look.hair);
      for (let x = 14; x < 26; x += 3) px(x, 4 + y0, 2, 1, look.hair);
      px(14, 8 + y0, 2, 2, look.hair);
      px(24, 8 + y0, 2, 1, look.hairShade);
    } else if (look.style === "long") {
      px(13, 5 + y0, 14, 3, look.hair);
      px(12, 7 + y0, 3, 14, look.hair);
      px(25, 7 + y0, 3, 14, look.hair);
      px(12, 18 + y0, 3, 3, look.hairShade);
      px(25, 18 + y0, 3, 3, look.hairShade);
      px(15, 8 + y0, 5, 1, look.hair);
    } else {
      px(13, 5 + y0, 14, 4, look.hair);
      px(13, 9 + y0, 2, 6, look.hair);
      px(25, 9 + y0, 2, 6, look.hair);
    }

    // Eyes.
    if (blink) {
      px(16, 12 + y0, 3, 1, "#1a1a1a");
      px(21, 12 + y0, 3, 1, "#1a1a1a");
    } else {
      px(16, 11 + y0, 3, 2, "#ffffff");
      px(21, 11 + y0, 3, 2, "#ffffff");
      px(17, 11 + y0, 1, 2, "#1a1a1a");
      px(22, 11 + y0, 1, 2, "#1a1a1a");
    }
    if (look.glasses) {
      // Thin frames: half a block, drawn finer than the grid on purpose.
      g.strokeStyle = "#111111";
      g.lineWidth = 6;
      g.strokeRect(15.5 * B, (10.5 + y0) * B, 4 * B, 3 * B);
      g.strokeRect(20.5 * B, (10.5 + y0) * B, 4 * B, 3 * B);
      g.fillStyle = "#111111";
      g.fillRect(19.5 * B, (11.5 + y0) * B, B, 6);
    }
    // Cheeks and mouth.
    px(15, 14 + y0, 1, 1, "#e88a8a");
    px(24, 14 + y0, 1, 1, "#e88a8a");
    if (mouthOpen) {
      px(18, 14 + y0, 4, 2, "#3a0d0d");
      px(19, 15 + y0, 2, 1, "#d94a5a");
    } else if (talking) {
      px(18, 15 + y0, 4, 1, "#3a0d0d");
    } else {
      px(18, 15 + y0, 4, 1, "#7a3a2a");
      px(17, 14 + y0, 1, 1, "#7a3a2a");
      px(22, 14 + y0, 1, 1, "#7a3a2a");
    }

    if (look.headphones) {
      px(13, 4 + y0, 14, 1, "#222222");
      px(12, 5 + y0, 1, 5, "#222222");
      px(27, 5 + y0, 1, 5, "#222222");
      px(11, 10 + y0, 3, 5, look.accent);
      px(26, 10 + y0, 3, 5, look.accent);
    }

    // A waving hand, swinging.
    if (waving) {
      const swing = Math.floor(now / 220) % 2;
      px(29, 14 + y0, 3, 7, look.shirt);
      px(29 + swing, 10 + y0, 3, 4, look.skin);
      px(29 + swing, 9 + y0, 1, 1, look.skin);
      px(31 + swing, 9 + y0, 1, 1, look.skin);
    }

    // A name tag, the way a webcam overlay would put it.
    g.fillStyle = "rgba(0,0,0,0.55)";
    g.fillRect(16, 480 - 52, 16 + nick.length * 17, 36);
    g.fillStyle = "#ffffff";
    g.font = "bold 26px monospace";
    g.textAlign = "left";
    g.textBaseline = "middle";
    g.fillText(nick, 24, 480 - 34);
  }

  // The shared screen: a tracker playing "night drive".
  const NOTES = ["C-4", "D#4", "G-4", "A#4", "C-5", "F-4", "G#3", "---"];
  function paintTracker(g: CanvasRenderingContext2D, now: number) {
    const W = 1280;
    const H = 720;
    g.fillStyle = "#008080";
    g.fillRect(0, 0, W, H);
    // The window.
    g.fillStyle = "#c0c0c0";
    g.fillRect(40, 30, W - 80, H - 60);
    const grad = g.createLinearGradient(40, 0, W - 40, 0);
    grad.addColorStop(0, "#000080");
    grad.addColorStop(1, "#1084d0");
    g.fillStyle = grad;
    g.fillRect(44, 34, W - 88, 30);
    g.fillStyle = "#ffffff";
    g.font = "bold 20px monospace";
    g.textBaseline = "middle";
    g.textAlign = "left";
    g.fillText("HexTracker — night drive.xm", 56, 49);

    // Pattern view.
    g.fillStyle = "#000000";
    g.fillRect(60, 80, 820, 580);
    const row = Math.floor(now / 125);
    const visible = 24;
    g.font = "20px monospace";
    for (let i = 0; i < visible; i++) {
      const r = row - 12 + i;
      const y = 96 + i * 23;
      if (i === 12) {
        g.fillStyle = "#1f3f7f";
        g.fillRect(60, y - 12, 820, 23);
      }
      g.fillStyle = r % 4 === 0 ? "#ffff66" : "#7f7f7f";
      g.fillText(String(((r % 64) + 64) % 64).padStart(2, "0"), 72, y);
      for (let c = 0; c < 4; c++) {
        const seed = Math.abs((r * 7 + c * 13) % 11);
        const note = seed < 6 ? NOTES[(r + c * 3 + 64) % NOTES.length] : "---";
        g.fillStyle = note === "---" ? "#3f5f3f" : "#66ff66";
        g.fillText(
          `${note} ${note === "---" ? ".." : String(c + 1).padStart(2, "0")}`,
          130 + c * 185,
          y,
        );
      }
    }

    // VU meters.
    g.fillStyle = "#000000";
    g.fillRect(900, 80, 320, 300);
    for (let c = 0; c < 4; c++) {
      const level =
        0.35 + 0.6 * Math.abs(Math.sin(now / (180 + c * 47) + c * 1.7));
      const h = Math.floor(level * 12);
      for (let s = 0; s < 12; s++) {
        g.fillStyle =
          s < h
            ? s > 9
              ? "#ff3030"
              : s > 6
                ? "#ffd030"
                : "#30ff60"
            : "#1a1a1a";
        g.fillRect(925 + c * 75, 350 - s * 22, 55, 18);
      }
    }
    // Waveform.
    g.fillStyle = "#000000";
    g.fillRect(900, 400, 320, 260);
    g.strokeStyle = "#30ff60";
    g.lineWidth = 2;
    g.beginPath();
    for (let x = 0; x <= 300; x += 4) {
      const v =
        Math.sin((x + now / 6) / 18) * 50 + Math.sin((x + now / 3) / 7) * 25;
      if (x === 0) g.moveTo(910 + x, 530 + v);
      else g.lineTo(910 + x, 530 + v);
    }
    g.stroke();
  }

  function track(
    width: number,
    height: number,
    paint: (g: CanvasRenderingContext2D, now: number) => void,
  ): MediaStreamTrack {
    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;
    const g = canvas.getContext("2d")!;
    g.imageSmoothingEnabled = false;
    const draw = () => paint(g, Date.now());
    draw();
    const timer = window.setInterval(draw, 50);
    const video = canvas.captureStream(20).getVideoTracks()[0];
    video.addEventListener("ended", () => window.clearInterval(timer));
    return video;
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
        if (constraints.video) stream.addTrack(track(640, 480, paintCharacter));
        return stream;
      },
      getDisplayMedia: async () =>
        new MediaStream([track(1280, 720, paintTracker)]),
      enumerateDevices: async () => [
        device("audioinput", "Built-in Microphone"),
        device("videoinput", "HD Webcam"),
        device("audiooutput", "Built-in Speakers"),
      ],
      addEventListener: () => {},
      removeEventListener: () => {},
    },
  });
}

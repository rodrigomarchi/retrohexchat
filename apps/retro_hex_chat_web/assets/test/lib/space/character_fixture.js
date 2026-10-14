// A small creator catalog in the shape build_creator.py writes, for tests.
const DIRS = [
  "south",
  "south-east",
  "east",
  "north-east",
  "north",
  "north-west",
  "west",
  "south-west",
];
const still = (frames) => DIRS.map(() => Array.from({ length: frames }, () => [0, 0]));
const ramp = (n) => [
  [n, 0, 0],
  [n, 1, 0],
];

export const CATALOG = Object.freeze({
  v: "test",
  canvas: 144,
  box: [10, 20, 50, 100],
  dirs: DIRS,
  anims: { walk: { frames: 2, ms: 120 }, idle: { frames: 2, ms: 220 } },
  bodies: { av: { top: 6, foot: 96 } },
  channelPalette: { skin: "skin", hair: "hair", primary: "fabric", secondary: "fabric" },
  palettes: {
    skin: [ramp(10), ramp(11)],
    hair: [ramp(20), ramp(21), ramp(22)],
    fabric: [ramp(30), ramp(31), ramp(32), ramp(33)],
  },
  portrait: { rect: [40, 17, 24, 24] },
  items: {
    bodies: ["av"],
    outfits: { bas: { channels: [] }, tun: { channels: ["primary", "secondary"] } },
    bases: ["av/bas", "av/tun"],
    hair: ["lng"],
    headwear: { adv: { channels: ["primary", "secondary"], hair: "clip" } },
    face: { brd: { channel: "hair" }, gls: { channel: "primary" } },
  },
  layers: {
    "base-av-bas": {
      channels: { skin: [1, 2] },
      anims: {
        walk: { url: "/b-walk.png", cell: [40, 90], origin: [12, 25] },
        idle: { url: "/b-idle.png", cell: [40, 90], origin: [12, 25] },
      },
      delta: { walk: still(2), idle: still(2) },
    },
    "base-av-tun": {
      channels: { primary: [1, 2], secondary: [3, 4], skin: [5, 6] },
      anims: {
        walk: { url: "/t-walk.png", cell: [42, 92], origin: [11, 24] },
        idle: { url: "/t-idle.png", cell: [42, 92], origin: [11, 24] },
      },
      delta: {
        walk: DIRS.map(() => [
          [0, 0],
          [1, -1],
        ]),
        idle: still(2),
      },
    },
    "hair-lng": {
      channels: { hair: [1, 2] },
      anims: {
        walk: { url: "/h-walk.png", cell: [20, 30], origin: [25, 20] },
        idle: { url: "/h-idle.png", cell: [20, 30], origin: [25, 20] },
      },
    },
    "face-brd": {
      channels: { hair: [1, 2] },
      anims: {
        walk: { url: "/f-walk.png", cell: [16, 12], origin: [26, 30] },
        idle: { url: "/f-idle.png", cell: [16, 12], origin: [26, 30] },
      },
    },
    "face-gls": {
      channels: { primary: [1, 2] },
      anims: {
        walk: { url: "/g-walk.png", cell: [16, 6], origin: [26, 26] },
        idle: { url: "/g-idle.png", cell: [16, 6], origin: [26, 26] },
      },
    },
    "hat-adv": {
      channels: { primary: [1, 2], secondary: [3, 4] },
      anims: {
        walk: { url: "/w-walk.png", cell: [26, 14], origin: [23, 16] },
        idle: { url: "/w-idle.png", cell: [26, 14], origin: [23, 16] },
      },
      mask: {
        walk: { url: "/m-walk.png", cell: [26, 18], origin: [23, 12] },
        idle: { url: "/m-idle.png", cell: [26, 18], origin: [23, 12] },
      },
    },
  },
  default: "c1.b-av.s-0.o-bas-0-0.h-0.w-0.f-0",
});

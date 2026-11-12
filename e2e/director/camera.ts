// No Playwright import here: playwright.config.ts reads these too.

/**
 * 1280x720 CSS pixels at 1.5x: the interface reads at YouTube size, frames are
 * 1920x1080. The scale must come from the browser's launch flags
 * (`CAMERA_LAUNCH_ARGS`, set on the director project): the screencast paints at
 * the window's native scale and ignores a context's emulated deviceScaleFactor,
 * which would leave every frame at 1280x720.
 */
const DESKTOP = {
  css: { width: 1280, height: 720 },
  scale: 1.5,
  frame: { width: 1920, height: 1080 },
};

/**
 * A phone held upright, for a YouTube Short: 360x640 CSS pixels at 3x →
 * 1080x1920 frames. The page is touched, not pointed at (`hasTouch`), so the
 * app lays itself out for a finger — the games' pad over the stage.
 */
const PHONE = {
  css: { width: 360, height: 640 },
  scale: 3,
  frame: { width: 1080, height: 1920 },
};

/**
 * The screen this run films, from the shot list's `frame` (`make e2e.director`
 * reads it into DIRECTOR_FRAME): one browser films one frame size.
 */
export const DIRECTOR_FRAME: "desktop" | "phone" =
  process.env.DIRECTOR_FRAME === "phone" ? "phone" : "desktop";

export const CAMERA = DIRECTOR_FRAME === "phone" ? PHONE : DESKTOP;

export const CAMERA_LAUNCH_ARGS = [
  `--force-device-scale-factor=${CAMERA.scale}`,
  `--window-size=${CAMERA.css.width},${CAMERA.css.height}`,
  // A character's voice is an AudioContext started with no click: without
  // this it stays suspended, the call hears silence and nobody lights up.
  "--autoplay-policy=no-user-gesture-required",
  // Draw on the machine's GPU. Headless otherwise rasterises every canvas in
  // software (SwiftShader), and a scene with several Spaces open starves the
  // camera's page: keystrokes took a third of a second each.
  "--enable-gpu",
  "--ignore-gpu-blocklist",
  "--use-angle=metal",
];

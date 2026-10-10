// No Playwright import here: playwright.config.ts reads these too.

/**
 * 1280x720 CSS pixels at 1.5x: the interface reads at YouTube size, frames are
 * 1920x1080. The scale must come from the browser's launch flags
 * (`CAMERA_LAUNCH_ARGS`, set on the director project): the screencast paints at
 * the window's native scale and ignores a context's emulated deviceScaleFactor,
 * which would leave every frame at 1280x720.
 */
export const CAMERA = {
  css: { width: 1280, height: 720 },
  scale: 1.5,
  frame: { width: 1920, height: 1080 },
};

export const CAMERA_LAUNCH_ARGS = [
  `--force-device-scale-factor=${CAMERA.scale}`,
  `--window-size=${CAMERA.css.width},${CAMERA.css.height}`,
  // A character's voice is an AudioContext started with no click: without
  // this it stays suspended, the call hears silence and nobody lights up.
  "--autoplay-policy=no-user-gesture-required",
];

/**
 * Turning a screenshot into the files a public page serves, with the browser
 * as the image toolchain — which spares the repository one.
 *
 * Shared by the captures of the games (`capture-game-shots.mjs`) and of the
 * Spaces (`capture/spaces.capture.ts`). Each function takes a Playwright page
 * to draw on; any page will do, even a blank one.
 */

/**
 * A PNG as WebP, optionally cut to `clip` ([x, y, w, h]) and shrunk to at most
 * `maxWidth`. Shrinking smooths unless `smooth` is false: a picture halved to
 * the pixel stays crisp without it, any other ratio smears without it.
 */
export async function toWebp(
  page,
  png,
  { quality, maxWidth = Infinity, clip = null, smooth = true },
) {
  const result = await page.evaluate(
    async ({ base64, quality, maxWidth, clip, smooth }) => {
      const image = new Image();
      image.src = `data:image/png;base64,${base64}`;
      await image.decode();

      const [sx, sy, sw, sh] = clip || [
        0,
        0,
        image.naturalWidth,
        image.naturalHeight,
      ];
      const scale = Math.min(1, maxWidth / sw);
      const canvas = document.createElement("canvas");
      canvas.width = Math.round(sw * scale);
      canvas.height = Math.round(sh * scale);

      const context = canvas.getContext("2d");
      context.imageSmoothingEnabled = smooth && scale < 1;
      context.drawImage(
        image,
        sx,
        sy,
        sw,
        sh,
        0,
        0,
        canvas.width,
        canvas.height,
      );

      const webp = canvas.toDataURL("image/webp", quality);
      if (!webp.startsWith("data:image/webp"))
        throw new Error("this Chromium cannot encode WebP");

      return {
        base64: webp.split(",")[1],
        width: canvas.width,
        height: canvas.height,
      };
    },
    {
      base64: png.toString("base64"),
      quality,
      maxWidth: Number.isFinite(maxWidth) ? maxWidth : 1e9,
      clip,
      smooth,
    },
  );

  return {
    webp: Buffer.from(result.base64, "base64"),
    width: result.width,
    height: result.height,
  };
}

/**
 * A share card from a picture: `width` x `height` JPEG, because LinkedIn and
 * WhatsApp do not reliably show WebP.
 *
 * - `fit: "contain"` draws the whole picture, centred on black — a game's
 *   screen keeps its edges.
 * - `fit: "crop"` cuts the card from the picture's centre at its own size —
 *   pixel art scaled by anything but a whole number smears, so it is not scaled.
 */
export async function toCard(page, webp, { width, height, quality, fit }) {
  const base64 = await page.evaluate(
    async ({ source, width, height, quality, fit }) => {
      const image = new Image();
      image.src = `data:image/webp;base64,${source}`;
      await image.decode();

      const canvas = document.createElement("canvas");
      canvas.width = width;
      canvas.height = height;
      const context = canvas.getContext("2d");
      context.fillStyle = "black";
      context.fillRect(0, 0, width, height);

      if (fit === "crop") {
        const sx = Math.max(0, Math.round((image.naturalWidth - width) / 2));
        const sy = Math.max(0, Math.round((image.naturalHeight - height) / 2));
        context.drawImage(image, sx, sy, width, height, 0, 0, width, height);
      } else {
        const scale = Math.min(
          width / image.naturalWidth,
          height / image.naturalHeight,
        );
        const drawnWidth = Math.round(image.naturalWidth * scale);
        const drawnHeight = Math.round(image.naturalHeight * scale);
        context.drawImage(
          image,
          (width - drawnWidth) / 2,
          (height - drawnHeight) / 2,
          drawnWidth,
          drawnHeight,
        );
      }

      return canvas.toDataURL("image/jpeg", quality).split(",")[1];
    },
    { source: webp.toString("base64"), width, height, quality, fit },
  );

  return Buffer.from(base64, "base64");
}

/** An object with its keys sorted, so a manifest diff shows only what changed. */
export function sortKeys(object) {
  return Object.fromEntries(
    Object.keys(object)
      .sort()
      .map((key) => [key, object[key]]),
  );
}

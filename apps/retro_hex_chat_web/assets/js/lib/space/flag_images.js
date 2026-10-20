// The language flags drawn on the nameplates, as canvas images. The server
// hands each one over as an image of its own (`config.flags`: locale → data
// URL), the very drawing the chat uses beside a nickname. A flag still
// loading draws nothing; the next frame finds it ready.

const FLAG_PX = 14;
const SVG_DATA = "data:image/svg+xml;";

export class FlagImages {
  /**
   * @param {object} options
   * @param {Object<string,string>} [options.urls] locale → data URL
   * @param {(url: string) => object} [options.makeImage]
   */
  constructor({ urls = {}, makeImage } = {}) {
    this._urls = urls && typeof urls === "object" ? urls : {};
    this._makeImage = makeImage ?? defaultMakeImage;
    this._images = new Map();
  }

  /** The side of a flag, in canvas pixels. */
  get size() {
    return FLAG_PX;
  }

  /**
   * The flag for `locale` once it is ready to draw, else null.
   * @param {string|null} locale
   * @returns {object|null}
   */
  get(locale) {
    const url = typeof locale === "string" ? this._urls[locale] : null;
    if (typeof url !== "string" || !url.startsWith(SVG_DATA)) return null;
    if (!this._images.has(locale)) this._images.set(locale, this._makeImage(url));
    const image = this._images.get(locale);
    return image?.complete && image.naturalWidth !== 0 ? image : null;
  }
}

function defaultMakeImage(url) {
  const image = new Image(FLAG_PX, FLAG_PX);
  image.src = url;
  return image;
}

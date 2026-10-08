import { CDPSession, Page } from "@playwright/test";
import { mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";

/**
 * Records a page as JPEG frames through the Chrome DevTools screencast.
 *
 * Playwright's own video is VP8 at a hard-coded 1 Mbit/s — fine to debug a
 * failure, not to publish. The screencast hands over each frame the compositor
 * paints, at full quality, and this writes them to disk with the moment each
 * arrived. Chrome only sends a frame when the screen changes, so a still
 * screen is a gap in the list; the encoder holds the previous frame across it.
 *
 * A take is `take.json` plus `frames/NNNNNN.jpg`:
 *
 *   { "seconds": 9.84, "width": 1920, "height": 1080,
 *     "frames": [{ "file": "frames/000000.jpg", "at": 0 }, ...] }
 *
 * `at` and `seconds` count from the call to `start`, on one clock (Date.now),
 * so the last frame is held until `seconds`.
 */

export type Frame = { file: string; at: number };

/** A region of the frame, in frame pixels. */
export type Box = { x: number; y: number; width: number; height: number };

/**
 * From `at` on, the scene is about `box` — or about the whole frame when it is
 * null. The edit zooms towards it.
 */
export type Mark = { at: number; box: Box | null };

export type Take = {
  seconds: number;
  width: number;
  height: number;
  frames: Frame[];
  marks: Mark[];
};

type ScreencastFrame = {
  data: string;
  sessionId: number;
  metadata: { deviceWidth: number; deviceHeight: number };
};

export class Recorder {
  private readonly frames: Frame[] = [];
  private readonly marks: Mark[] = [];
  private readonly startedAt = Date.now();
  private width = 0;
  private height = 0;
  private cdp!: CDPSession;

  private constructor(
    private readonly dir: string,
    private readonly size: { width: number; height: number },
  ) {}

  static async start(
    page: Page,
    dir: string,
    size: { width: number; height: number },
  ): Promise<Recorder> {
    mkdirSync(path.join(dir, "frames"), { recursive: true });
    const recorder = new Recorder(dir, size);
    // A tab behind another one paints nothing to film.
    await page.bringToFront();
    await recorder.watch(page);
    return recorder;
  }

  /**
   * Moves the camera to another page — a tab the scene just opened — on the
   * same timeline: the last frame of the old page holds until the new one
   * paints.
   */
  async follow(page: Page): Promise<void> {
    await this.release();
    await page.bringToFront();
    await this.watch(page);
  }

  private async watch(page: Page): Promise<void> {
    const cdp = await page.context().newCDPSession(page);
    this.cdp = cdp;
    cdp.on("Page.screencastFrame", (frame: ScreencastFrame) =>
      this.onFrame(cdp, frame),
    );
    await cdp.send("Page.startScreencast", {
      format: "jpeg",
      quality: 95,
      maxWidth: this.size.width,
      maxHeight: this.size.height,
      everyNthFrame: 1,
    });
  }

  /** Records what the scene is about from now on (see `Mark`). */
  mark(box: Box | null): void {
    this.marks.push({ at: this.elapsed(), box });
  }

  private async release(): Promise<void> {
    const cdp = this.cdp;
    await cdp.send("Page.stopScreencast").catch(ignoreClosed);
    await cdp.detach().catch(ignoreClosed);
  }

  private onFrame(cdp: CDPSession, { data, sessionId }: ScreencastFrame): void {
    // A frame in flight from a page the camera has left belongs to no take.
    if (cdp !== this.cdp) return;
    const file = `frames/${String(this.frames.length).padStart(6, "0")}.jpg`;
    const jpeg = Buffer.from(data, "base64");
    writeFileSync(path.join(this.dir, file), jpeg);
    this.frames.push({ file, at: this.elapsed() });
    if (this.width === 0) [this.width, this.height] = jpegSize(jpeg);
    // Chrome sends the next frame only after this one is acknowledged.
    cdp.send("Page.screencastFrameAck", { sessionId }).catch(ignoreClosed);
  }

  async stop(): Promise<Take> {
    const seconds = this.elapsed();
    await this.release();
    if (this.frames.length === 0) {
      throw new Error(`no frame was painted during the take in ${this.dir}`);
    }
    if (this.width !== this.size.width || this.height !== this.size.height) {
      throw new Error(
        `frames are ${this.width}x${this.height}, the camera asked for ${this.size.width}x${this.size.height} — ` +
          "is the browser launched with CAMERA_LAUNCH_ARGS?",
      );
    }
    const take: Take = {
      seconds,
      width: this.width,
      height: this.height,
      frames: this.frames,
      marks: this.marks,
    };
    writeFileSync(
      path.join(this.dir, "take.json"),
      JSON.stringify(take, null, 2),
    );
    return take;
  }

  private elapsed(): number {
    return (Date.now() - this.startedAt) / 1000;
  }
}

/**
 * A screencast call racing the page that closes under it — the last ack of a
 * take, a tab the scene closed — is expected. Anything else is not.
 */
function ignoreClosed(error: Error): void {
  if (!/Target closed|Session closed|has been closed/.test(error.message)) {
    throw error;
  }
}

/** Reads width and height from a JPEG's start-of-frame marker. */
export function jpegSize(jpeg: Buffer): [number, number] {
  let offset = 2;
  while (offset < jpeg.length) {
    const marker = jpeg.readUInt16BE(offset);
    const length = jpeg.readUInt16BE(offset + 2);
    // SOF0..SOF15, except DHT (C4), JPG (C8) and DAC (CC).
    if (
      marker >= 0xffc0 &&
      marker <= 0xffcf &&
      ![0xffc4, 0xffc8, 0xffcc].includes(marker)
    ) {
      return [jpeg.readUInt16BE(offset + 7), jpeg.readUInt16BE(offset + 5)];
    }
    offset += 2 + length;
  }
  throw new Error("not a JPEG with a frame header");
}

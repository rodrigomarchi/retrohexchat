import { expect, type BrowserContext, type Page } from "@playwright/test";

/**
 * Counts the sounds the client actually starts.
 *
 * The chat synthesises its beeps through the Web Audio API rather than playing
 * files, so there is no request to intercept and no element to read. Swapping
 * `AudioContext` for one whose oscillator only counts its `start()` calls makes
 * "did this make a noise?" answerable — which is the real question behind mute,
 * sound settings and per-event previews.
 *
 * Install it before the page loads: `addInitScript` runs ahead of the app, so
 * the app never sees the real constructor. Pass a `BrowserContext` when a spec
 * opens more than one page and needs every one of them spied on.
 */
type SpyTarget = Pick<Page | BrowserContext, "addInitScript">;

export async function installAudioSpy(target: SpyTarget): Promise<void> {
  await target.addInitScript(() => {
    class FakeAudioParam {
      setValueAtTime() {}
      exponentialRampToValueAtTime() {}
    }

    class FakeOscillatorNode {
      frequency = new FakeAudioParam();
      type = "sine";

      connect() {}
      start() {
        (
          window as unknown as { __soundStartCount: number }
        ).__soundStartCount += 1;
      }
      stop() {}
    }

    class FakeGainNode {
      gain = new FakeAudioParam();

      connect() {}
    }

    class FakeAudioContext {
      currentTime = 0;
      destination = {};

      createOscillator() {
        return new FakeOscillatorNode();
      }

      createGain() {
        return new FakeGainNode();
      }
    }

    (window as unknown as { __soundStartCount: number }).__soundStartCount = 0;
    (
      window as unknown as { AudioContext: typeof FakeAudioContext }
    ).AudioContext = FakeAudioContext;
    (
      window as unknown as { webkitAudioContext: typeof FakeAudioContext }
    ).webkitAudioContext = FakeAudioContext;
  });
}

export async function resetAudioSpy(page: Page): Promise<void> {
  await page.evaluate(() => {
    (window as unknown as { __soundStartCount: number }).__soundStartCount = 0;
  });
}

export async function expectSoundStarts(
  page: Page,
  count: number,
): Promise<void> {
  await expect
    .poll(() =>
      page.evaluate(
        () =>
          (window as unknown as { __soundStartCount: number })
            .__soundStartCount,
      ),
    )
    .toBe(count);
}

/**
 * Asserts nothing played, after giving it long enough to have played.
 *
 * A muted client is proved by an absence, and an absence read too early is just
 * impatience — the beat before the count is the whole assertion.
 */
export async function expectNoSoundStarts(page: Page): Promise<void> {
  await page.waitForTimeout(500);
  await expectSoundStarts(page, 0);
}

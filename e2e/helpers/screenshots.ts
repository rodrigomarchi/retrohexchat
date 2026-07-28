/**
 * Opt-in visual evidence for the E2E suite.
 *
 * Calls to `shot()` are inert unless `E2E_SHOTS` is set, so a spec carrying
 * evidence points behaves *exactly* like one that does not on a normal run —
 * no extra I/O, no extra wall clock, no behavioural difference. That is the
 * whole point: evidence lives inside the real spec instead of a throwaway one
 * written to capture a picture and then deleted.
 *
 * Usage inside a spec:
 *
 *     import { shot } from "../helpers/screenshots";
 *
 *     await chat.openChannelList();
 *     await shot(page, "channel-list-first-page");
 *     await chat.scrollChannelListToBottom();
 *     await shot(chat.channelListPanel, "channel-list-end-marker");
 *
 * Capture a run:
 *
 *     make e2e.shots FILE=tests/chat-infinite-scroll.spec.ts
 *
 * Files land in `e2e/screenshots/<spec>/<nn>-<name>.png`, numbered in call
 * order so the sequence reads as the story of the journey. Each shot is also
 * attached to the Playwright HTML report.
 */
import { test, type Locator, type Page } from "@playwright/test";
import path from "node:path";

const SHOTS_DIR = "screenshots";

/** Per-test counter so filenames keep the order the spec captured them in. */
const counters = new Map<string, number>();

/** True when this run was asked for visual evidence. */
export function shotsEnabled(): boolean {
  const flag = process.env.E2E_SHOTS;
  if (!flag) return false;
  const normalized = flag.trim().toLowerCase();
  return normalized !== "" && normalized !== "0" && normalized !== "false";
}

function slugify(value: string): string {
  return (
    value
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "")
      .slice(0, 80) || "shot"
  );
}

function nextIndex(testId: string): string {
  const next = (counters.get(testId) ?? 0) + 1;
  counters.set(testId, next);
  return String(next).padStart(2, "0");
}

/**
 * Capture `target` as evidence under the given name. No-op unless E2E_SHOTS.
 *
 * Pass a `Page` for the full viewport, or a `Locator` to frame a single
 * window/panel — the latter is usually the better evidence for a dialog.
 */
export async function shot(
  target: Page | Locator,
  name: string,
): Promise<void> {
  if (!shotsEnabled()) return;

  const info = test.info();
  const specFile = path.basename(info.file).replace(/\.spec\.ts$/, "");
  const fileName = `${nextIndex(info.testId)}-${slugify(name)}.png`;
  // Playwright is always invoked from `e2e/` (see the Makefile targets), so a
  // cwd-relative path keeps the output where a human can find it without
  // digging through `test-results/`, which Playwright wipes between runs.
  const filePath = path.resolve(
    process.cwd(),
    SHOTS_DIR,
    specFile,
    slugify(info.title),
    fileName,
  );

  await target.screenshot({ path: filePath });
  await info.attach(name, { path: filePath, contentType: "image/png" });
}

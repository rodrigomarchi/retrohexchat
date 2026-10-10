/**
 * @section N - P2P, File, Call, Game
 * @flow N48 [done] Choosing a call layout rearranges the call: side by side puts your camera beside the peer's, focus puts it in a corner of theirs
 * @flow N49 [done] A reaction sent from one side of the call appears on the other side's peer tile
 * @flow N50 [done] A second file picked while one is transferring waits in the queue, then is offered and completes by itself
 * @flow N51 [done] Leaving the call leaves only you: the peer is told you left instead of a frozen picture, and you can join again
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect, Page } from "@playwright/test";
import { writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import {
  acceptP2PInvite,
  closeP2PUsers,
  newP2PUser,
  remoteVideoLive,
  sendP2PInvite,
  startP2PSession,
  type P2PTestUser,
} from "../helpers/p2pFlows";

/**
 * The small things a live call is made of: how it is laid out, a reaction
 * across to the other side, and files handed over one after another. Each
 * runs on a call that is already up both ways.
 */

type Call = { alice: Page; bob: Page };

/** Where your own camera is drawn against the peer's picture. */
async function selfViewPlace(
  page: Page,
): Promise<"beside" | "inside" | "other"> {
  const remote = await page.getByTestId("p2p-call-remote-tile").boundingBox();
  const local = await page.getByTestId("p2p-call-local-tile").boundingBox();
  if (!remote || !local) return "other";
  if (
    local.x >= remote.x + remote.width - 1 &&
    local.width > remote.width * 0.8
  ) {
    return "beside";
  }
  const inside =
    local.x >= remote.x &&
    local.y >= remote.y &&
    local.x + local.width <= remote.x + remote.width &&
    local.y + local.height <= remote.y + remote.height;
  return inside ? "inside" : "other";
}

async function liveCall(alice: P2PTestUser, bob: P2PTestUser): Promise<Call> {
  const aliceSession = await sendP2PInvite(alice, bob.nick);
  await bob.chat.expectTabVisible(alice.nick);
  await bob.chat.switchToTab(alice.nick);
  const bobSession = await acceptP2PInvite(bob);
  await startP2PSession(aliceSession);
  for (const page of [aliceSession, bobSession]) {
    await expect
      .poll(() => remoteVideoLive(page), { timeout: 30_000 })
      .toBe(true);
  }
  return { alice: aliceSession, bob: bobSession };
}

async function consoleSection(page: Page, section: "call" | "files") {
  await page.getByTestId(`p2p-console-nav-${section}`).click();
  await expect(
    page.getByTestId(`p2p-console-section-${section}`),
  ).toBeVisible();
}

/** A file on disk: big enough that its transfer is still running a moment later. */
function fileOf(name: string, mb: number): string {
  const file = path.join(tmpdir(), name);
  writeFileSync(file, Buffer.alloc(mb * 1024 * 1024, 7));
  return file;
}

test.describe("P2P call moments", () => {
  test.describe.configure({ mode: "serial" });

  test("choosing a layout takes effect on the call surface", async ({
    browser,
  }) => {
    test.setTimeout(75_000);
    const alice = await newP2PUser(browser, "cma", { media: true });
    const bob = await newP2PUser(browser, "cmb", { media: true });

    try {
      const call = await liveCall(alice, bob);
      const surface = call.alice.getByTestId("p2p-call-surface");

      for (const layout of ["split", "focus"]) {
        const control = call.alice.getByTestId(`p2p-call-layout-${layout}`);
        await control.click();
        await expect(surface).toHaveAttribute("data-call-layout", layout);
        await expect(control).toHaveAttribute("aria-pressed", "true");
      }

      // What you see changes, not just the pressed button: side by side, your
      // own camera stands beside the peer's; focused, it sits inside it.
      await call.alice.getByTestId("p2p-call-layout-split").click();
      await expect.poll(() => selfViewPlace(call.alice)).toBe("beside");
      await call.alice.getByTestId("p2p-call-layout-focus").click();
      await expect.poll(() => selfViewPlace(call.alice)).toBe("inside");
      // The remote picture survives the change of layout.
      await expect
        .poll(() => remoteVideoLive(call.alice), { timeout: 10_000 })
        .toBe(true);
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test("a reaction reaches the other side's peer tile", async ({ browser }) => {
    test.setTimeout(75_000);
    const alice = await newP2PUser(browser, "cmc", { media: true });
    const bob = await newP2PUser(browser, "cmd", { media: true });

    try {
      const call = await liveCall(alice, bob);

      await call.alice
        .getByTestId("p2p-call-dock")
        .locator('summary[aria-label="Reactions"]')
        .click();
      await call.alice.getByTestId("p2p-call-reaction-heart").click();

      // Shown on the sender's own tile, and across on the receiver's peer tile.
      await expect(
        call.alice
          .getByTestId("p2p-local-reactions")
          .locator('[data-reaction="heart"]'),
      ).toBeVisible();
      await expect(
        call.bob
          .getByTestId("p2p-peer-reactions")
          .locator('[data-reaction="heart"]'),
      ).toBeVisible({ timeout: 10_000 });
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test("a second file waits its turn, then is offered and completes", async ({
    browser,
  }) => {
    test.setTimeout(120_000);
    const alice = await newP2PUser(browser, "cme", {
      media: true,
      acceptDownloads: true,
    });
    const bob = await newP2PUser(browser, "cmf", {
      media: true,
      acceptDownloads: true,
    });
    const first = fileOf("moments-first.bin", 60);
    const second = fileOf("moments-second.bin", 1);

    try {
      const call = await liveCall(alice, bob);
      await consoleSection(call.alice, "files");
      const bobFiles = call.bob.getByTestId("lobby-file-panel");

      await call.alice.locator("#lobby-file-input").setInputFiles(first);
      await expect(bobFiles.getByTestId("file-transfer")).toContainText(
        "moments-first.bin",
        { timeout: 15_000 },
      );
      await bobFiles.getByTestId("file-transfer-accept").click();
      await expect(
        call.alice.getByTestId("file-transfer-status"),
      ).toContainText(/%/, { timeout: 15_000 });

      // Picked mid-transfer: it waits, and the sender is told so.
      await call.alice.locator("#lobby-file-input").setInputFiles(second);
      await expect(call.alice.getByTestId("p2p-notice")).toContainText(
        "Queued for after the current transfer: moments-second.bin",
      );

      // The first one lands; then the second is offered without a new pick.
      await expect(bobFiles.getByTestId("file-transfer")).toContainText(
        "moments-second.bin",
        { timeout: 60_000 },
      );
      // On offer, it no longer waits: the queue line leaves the status bar.
      await expect(
        call.alice
          .getByTestId("p2p-notice")
          .filter({ hasText: "Queued for after the current transfer" }),
      ).toHaveCount(0);
      // Accepting downloads it for real, the way the first one did.
      const download = call.bob.waitForEvent("download", { timeout: 30_000 });
      await bobFiles.getByTestId("file-transfer-accept").click();
      expect((await download).suggestedFilename()).toBe("moments-second.bin");
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test("leaving the call leaves only you, and you can join again", async ({
    browser,
  }) => {
    test.setTimeout(75_000);
    const alice = await newP2PUser(browser, "cme", { media: true });
    const bob = await newP2PUser(browser, "cmf", { media: true });

    try {
      const call = await liveCall(alice, bob);

      await call.alice.getByTestId("p2p-call-end").click();
      // The one who stayed is told, and the frozen picture is gone.
      await expect(call.bob.getByTestId("p2p-call-peer-left")).toBeVisible({
        timeout: 15_000,
      });
      await expect(call.bob.locator("#lobby-remote-video")).toBeHidden();
      await expect(call.bob.getByTestId("p2p-call-end")).toBeVisible();
      // The one who left is invited back rather than shown a blank panel.
      await expect(
        call.alice.getByTestId("p2p-call-peer-in-call"),
      ).toBeVisible();

      await call.alice.getByTestId("lobby-call-start-video").click();
      await expect(call.bob.getByTestId("p2p-call-peer-left")).toBeHidden({
        timeout: 15_000,
      });
      for (const page of [call.alice, call.bob]) {
        await expect
          .poll(() => remoteVideoLive(page), { timeout: 30_000 })
          .toBe(true);
      }
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });
});

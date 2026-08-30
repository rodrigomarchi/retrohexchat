/**
 * @section SP - Virtual Spaces
 * @flow SP6 [done] A space opened at its own address runs without the chat around it
 * @flow SP7 [done] A shared space link resolves to a card and then to the space itself
 * @flow SP8 [done] Two people in the same space, one in a tab of its own, see each other
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect, Page } from "@playwright/test";
import {
  newSignedInUser,
  closeUsers,
  uniqueChannel,
  TestUser,
} from "../helpers/chatUsers";

// A compact hash of the canvas pixels — changes when anything redraws.
function canvasSignature(page: Page): Promise<number> {
  return page
    .locator('[data-testid="channel-space-shell"] canvas')
    .evaluate((el: HTMLCanvasElement) => {
      const ctx = el.getContext("2d");
      if (!ctx || !el.width || !el.height) return 0;
      const { data } = ctx.getImageData(0, 0, el.width, el.height);
      let sum = 0;
      for (let i = 0; i < data.length; i += 97)
        sum = (sum + data[i] * ((i % 251) + 1)) % 1_000_003;
      return sum;
    });
}

async function openSpaceTab(user: TestUser, channel: string): Promise<string> {
  await user.chat.sendMessage(`/join ${channel}`);
  await user.page
    .locator('[data-testid="tab-bar"] [role="tab"][phx-value-type="space"]')
    .click();
  await expect(user.page.getByTestId("space-character-select")).toBeVisible();

  const href = await user.page
    .getByTestId("space-open-in-tab")
    .getAttribute("href");
  expect(href).toBeTruthy();
  return href as string;
}

test.describe("A space at an address of its own", () => {
  test("runs without the chat around it", async ({ browser }) => {
    const user = await newSignedInUser(browser, "spa");
    try {
      const channel = uniqueChannel("spa");
      const address = await openSpaceTab(user, channel);

      // A tab of its own: opened cold, with no chat page behind it.
      const solo = await user.ctx.newPage();
      await solo.goto(address);

      // The antechamber is the first thing the address renders, and it names
      // who is already inside.
      await expect(solo.getByTestId("space-character-select")).toBeVisible();
      await expect(solo.getByTestId("space-roster-names")).toContainText(
        user.nick,
      );
      await expect(solo.getByTestId("space-back-to-chat")).toBeVisible();

      // The page already is the space, so it offers neither a tab of its own
      // nor a second way to fill the screen.
      await expect(solo.getByTestId("space-open-in-tab")).toHaveCount(0);
      await expect(solo.getByTestId("space-fullscreen-toggle")).toHaveCount(0);

      // Choosing a character is entering.
      await solo.getByTestId("space-avatar-monk").click();
      await expect(
        solo.locator('[data-testid="channel-space-shell"][data-avatar="monk"]'),
      ).toBeVisible();
      await expect(
        solo.locator('[data-testid="channel-space-shell"] canvas'),
      ).toBeVisible();

      // The world boots and keeps drawing: the loading panel goes away and the
      // canvas has pixels in it.
      await expect(solo.getByTestId("space-loading")).toBeHidden({
        timeout: 15_000,
      });
      await expect.poll(() => canvasSignature(solo)).not.toBe(0);

      // Walking works with nothing but this tab: the frame changes after a step.
      const before = await canvasSignature(solo);
      await solo.locator('[data-space-pad-dir="right"]').click();
      await expect.poll(() => canvasSignature(solo)).not.toBe(before);
    } finally {
      await closeUsers([user]);
    }
  });

  test("a shared link resolves to a card and then to the space", async ({
    browser,
  }) => {
    const user = await newSignedInUser(browser, "spl");
    try {
      const channel = uniqueChannel("spl");
      await openSpaceTab(user, channel);

      await user.page.getByTestId("share-create").click();
      const shareUrl = await user.page.getByTestId("share-url").inputValue();
      expect(shareUrl).toContain("/join/");

      // The public card: it names the space and offers the way in.
      const visitor = await user.ctx.newPage();
      await visitor.goto(shareUrl);
      await expect(visitor.getByTestId("join-card")).toBeVisible();
      await expect(visitor.getByTestId("join-enter")).toBeVisible();

      await visitor.getByTestId("join-enter").click();
      await expect(visitor.getByTestId("space-character-select")).toBeVisible();
      await expect(visitor).toHaveURL(/\/space\//);
    } finally {
      await closeUsers([user]);
    }
  });

  test("two people in the same space see each other", async ({ browser }) => {
    const host = await newSignedInUser(browser, "spx");
    const guest = await newSignedInUser(browser, "spy");
    try {
      const channel = uniqueChannel("spx");
      const address = await openSpaceTab(host, channel);

      // The host walks in from the chat.
      await host.page.getByTestId("space-avatar-knight").click();
      await expect(host.page.getByTestId("space-loading")).toBeHidden({
        timeout: 15_000,
      });

      // The guest joins the channel and opens the same address in a tab of
      // its own — the two hosts of the same surface, side by side.
      await guest.chat.sendMessage(`/join ${channel}`);
      const solo = await guest.ctx.newPage();
      await solo.goto(address);
      await expect(solo.getByTestId("space-roster-names")).toContainText(
        host.nick,
      );

      await solo.getByTestId("space-avatar-sorceress").click();
      await expect(solo.getByTestId("space-loading")).toBeHidden({
        timeout: 15_000,
      });

      // Each one's arrival redraws the other's world.
      await expect
        .poll(() => canvasSignature(host.page), { timeout: 15_000 })
        .not.toBe(0);
      await expect
        .poll(() => canvasSignature(solo), { timeout: 15_000 })
        .not.toBe(0);
    } finally {
      await closeUsers([host, guest]);
    }
  });
});

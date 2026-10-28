/**
 * @section AC - Accessories: Hex Paint And ASCII Art
 * @flow AC1 [done] Hex Paint opens from Start > Accessories, a drag draws a line, Ctrl+Z takes it back
 * @flow AC2 [done] A drawing posted from Hex Paint reaches another member of the channel as a picture with its line of text
 * @flow AC3 [done] ASCII Art turns a word into a banner and posts it as one block that another member sees whole, with no flood ignore
 * @flow AC4 [done] Hex Paint's File > Open in ASCII Art opens ASCII Art on the drawing
 * @flow AC5 [done] A visitor who picks Start > Accessories > Hex Paint is asked to register
 * @flow AC6 [done] Both windows fit a phone, their menus on the rail
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, Page, test } from "@playwright/test";
import {
  closeUsers,
  newSignedInUser,
  TestUser,
  uniqueChannel,
} from "../helpers/chatUsers";
import { shot } from "../helpers/screenshots";
import { ChatPage } from "../pages/ChatPage";

const DRAFT_KEY = "retrohex.paint.draft";

// The pixels Hex Paint keeps in the browser: "<size>:" then one character a
// pixel, "." for a clear one.
async function paintedPixels(page: Page): Promise<number> {
  return page.evaluate((key) => {
    const draft = window.localStorage.getItem(key) ?? "";
    return [...(draft.split(":")[1] ?? "")].filter((c) => c !== ".").length;
  }, DRAFT_KEY);
}

async function openFromAccessories(
  user: TestUser,
  item: "open_paint" | "open_ascii_art",
) {
  const trigger = user.page.getByTestId("start-menu-accessories-submenu");
  const entry = user.page.getByTestId(`start-menu-item-${item}`);
  await user.chat.openStartGroup(trigger, entry);
  await entry.click();
}

async function openPaint(user: TestUser) {
  await openFromAccessories(user, "open_paint");
  const canvas = user.page.getByTestId("hex-paint-canvas");
  await expect(canvas).toBeVisible();
  // The hook draws the canvas at the drawing's size times the zoom.
  await expect
    .poll(() => canvas.evaluate((el: HTMLCanvasElement) => el.width))
    .toBeGreaterThan(32);
  return canvas;
}

// A drag across the drawing, from one fraction of it to another.
async function drag(
  page: Page,
  canvas: ReturnType<Page["getByTestId"]>,
  from: number[],
  to: number[],
) {
  const box = (await canvas.boundingBox())!;
  const at = ([x, y]: number[]) => [
    box.x + box.width * x,
    box.y + box.height * y,
  ];
  const [x0, y0] = at(from);
  const [x1, y1] = at(to);
  await page.mouse.move(x0, y0);
  await page.mouse.down();
  await page.mouse.move(x1, y1, { steps: 8 });
  await page.mouse.up();
}

// A menu of the window's bar, then one of its items — the desktop menu's, not
// the copy the phone's drawer carries.
async function menu(page: Page, window: string, label: string, item: string) {
  const menus = page
    .getByTestId(`${window}-menu-bar`)
    .locator(".app-menu-bar__desktop-menu");
  const menu = menus.filter({ hasText: label });
  await menu.locator("button[data-menubar-trigger]").click();
  await menu.getByTestId(item).click();
}

test("Hex Paint draws, undoes and posts a picture another member sees (AC1, AC2)", async ({
  browser,
}) => {
  const ana = await newSignedInUser(browser, "pnta");
  const beto = await newSignedInUser(browser, "pntb");
  const channel = uniqueChannel("pnt");

  try {
    for (const user of [ana, beto])
      await user.chat.sendMessage(`/join ${channel}`);

    const canvas = await openPaint(ana);
    await shot(ana.page.getByTestId("paint-window"), "hex paint open");

    // AC1: a pencil drag paints a run of pixels; Ctrl+Z takes the stroke back.
    await ana.page.locator("#hex-paint-palette-colours label").nth(4).click();
    await drag(ana.page, canvas, [0.2, 0.2], [0.8, 0.6]);
    await expect.poll(() => paintedPixels(ana.page)).toBeGreaterThan(10);
    await ana.page.keyboard.press("Control+z");
    await expect.poll(() => paintedPixels(ana.page)).toBe(0);

    // A filled rectangle chosen by its key, and an ellipse from the toolbar.
    await canvas.click({ position: { x: 1, y: 1 } });
    await ana.page.keyboard.press("Shift+R");
    await expect(
      ana.page.getByTestId("hex-paint-tool-rect_fill"),
    ).toHaveAttribute("aria-pressed", "true");
    await drag(ana.page, canvas, [0.1, 0.1], [0.5, 0.5]);
    await ana.page.getByTestId("hex-paint-tool-ellipse").click();
    await drag(ana.page, canvas, [0.5, 0.5], [0.9, 0.9]);
    await expect.poll(() => paintedPixels(ana.page)).toBeGreaterThan(50);
    await shot(ana.page.getByTestId("paint-window"), "a drawing");

    // AC2: File > Post to channel… shows the picture and where it goes.
    await menu(ana.page, "hex-paint", "File", "hex-paint-menu-post");
    const dialog = ana.page.getByTestId("hex-paint-post-form");
    await expect(dialog).toBeVisible();
    await expect(
      ana.page.getByTestId("hex-paint-post-preview").locator("img"),
    ).toBeVisible();
    await expect(ana.page.getByTestId("hex-paint-post-submit")).toBeEnabled();
    await ana.page
      .getByTestId("hex-paint-post-caption")
      .fill("a box and a ball");
    await shot(ana.page.getByTestId("paint-window"), "post dialog");
    await ana.page.getByTestId("hex-paint-post-submit").click();
    await expect(dialog).toBeHidden();

    await beto.chat.expectMessageVisible("a box and a ball");
    const row = beto.chat.messageRows
      .filter({ hasText: "a box and a ball" })
      .last();
    await expect(
      row.getByTestId("message-attachment-image-preview"),
    ).toBeVisible();
    await shot(beto.page, "the drawing in the channel");
  } finally {
    await closeUsers([ana, beto]);
  }
});

test("ASCII Art posts a banner as one block, and opens on the Hex Paint drawing (AC3, AC4)", async ({
  browser,
}) => {
  const ana = await newSignedInUser(browser, "asca");
  const beto = await newSignedInUser(browser, "ascb");
  const channel = uniqueChannel("asc");

  try {
    for (const user of [ana, beto])
      await user.chat.sendMessage(`/join ${channel}`);

    // AC3: a word in rainbow blocks.
    await openFromAccessories(ana, "open_ascii_art");
    const window = ana.page.getByTestId("ascii-art-window");
    await expect(window).toBeVisible();
    await ana.page.getByTestId("ascii-art-text").fill("HELLO");
    const scheme = ana.page.getByTestId("ascii-scheme");
    await scheme.locator("button").first().click();
    await scheme.getByRole("option", { name: "Rainbow" }).click();
    // The choice shows on the closed list, as the browser made it.
    await expect(scheme.locator(".select-content")).toBeHidden();
    await expect(scheme.locator(".select-value")).toHaveAttribute(
      "data-content",
      "Rainbow",
    );
    const preview = ana.page.getByTestId("ascii-art-preview");
    await expect(preview.locator("pre.irc-art")).toContainText("█");
    await expect(
      preview.locator("pre.irc-art span[class*='irc-fg-']").first(),
    ).toBeVisible();
    await shot(window, "ascii art banner");

    await menu(ana.page, "ascii-art", "File", "ascii-art-menu-post");
    await expect(
      ana.page.getByTestId("ascii-art-post-preview").locator("pre.irc-art"),
    ).toBeVisible();
    await shot(window, "ascii art post dialog");
    await ana.page.getByTestId("ascii-art-post-submit").click();

    const block = beto.chat.messageList.locator("pre.irc-art").last();
    await expect(block).toBeVisible();
    // One message, five rows of the font, and the author not ignored for a flood.
    expect((await block.innerText()).split("\n").length).toBeGreaterThanOrEqual(
      5,
    );
    await expect(
      beto.chat.messageRows.filter({ has: beto.page.locator("pre.irc-art") }),
    ).toHaveCount(1);
    await expect(beto.chat.messageList).not.toContainText("auto-ignored");
    await shot(beto.page, "the banner in the channel");

    // AC4: Hex Paint hands its drawing over.
    const canvas = await openPaint(ana);
    await drag(ana.page, canvas, [0.1, 0.5], [0.9, 0.5]);
    await menu(ana.page, "hex-paint", "File", "hex-paint-menu-to-ascii");
    await expect(window).toBeVisible();
    await expect(
      ana.page.getByTestId("ascii-art-source-paint"),
    ).toHaveAttribute("data-state", "active");
    await expect(preview.locator("pre.irc-art")).toContainText(/[▀▄█]/);
    await shot(window, "ascii art from hex paint");
  } finally {
    await closeUsers([ana, beto]);
  }
});

test("a visitor is asked to register for Hex Paint (AC5)", async ({
  browser,
}) => {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  try {
    await page.goto("/");
    await page.waitForFunction(
      () =>
        !!document
          .querySelector("[data-phx-main]")
          ?.classList.contains("phx-connected"),
    );
    const entry = page.getByTestId("start-menu-item-open_paint");
    await new ChatPage(page).openStartGroup(
      page.getByTestId("start-menu-accessories-submenu"),
      entry,
    );
    await entry.click();
    await expect(page.getByTestId("document-window-connect")).toBeVisible();
    await expect(page.getByTestId("document-window-connect")).toContainText(
      "Hex Paint",
    );
    await expect(page.getByTestId("paint-window")).toHaveCount(0);
    await shot(page, "visitor asked to register");
  } finally {
    await ctx.close();
  }
});

test("both windows fit a phone (AC6)", async ({ browser }) => {
  const user = await newSignedInUser(browser, "pnph");
  const phone = await user.ctx.newPage();
  await phone.setViewportSize({ width: 390, height: 844 });

  try {
    await phone.goto("/");
    await phone.waitForFunction(
      () =>
        !!document
          .querySelector("[data-phx-main]")
          ?.classList.contains("phx-connected"),
    );
    for (const [command, testid] of [
      ["/paint", "paint-window"],
      ["/ascii", "ascii-art-window"],
    ]) {
      const input = phone.getByTestId("chat-input-field");
      await input.fill(command);
      await input.press("Enter");
      const window = phone.getByTestId(testid);
      await expect(window).toBeVisible();
      await expect(window).toBeInViewport({ ratio: 0.95 });
      await shot(phone, `${testid} on a phone`);
      await window.locator("[data-window-control='close']").click();
      await expect(window).toBeHidden();
    }
  } finally {
    await closeUsers([user]);
  }
});

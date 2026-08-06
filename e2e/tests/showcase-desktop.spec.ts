/**
 * @section PW - Public Pages, Landing, And Showcase
 * @flow PW7 [done] The showcase drives the page as a window and carries the layout across pages
 * @flow PW8 [done] Components are navigated through the Components window
 * @flow PW9 [done] The Start menu is the app's own, with the showcase's windows in it
 * @flow PW10 [done] Every menu row takes the same highlight
 * @flow PW11 [done] The nested demo desktop runs beside the shell's own
 * @flow PW12 [done] With JavaScript disabled the page still reads and links like a document, keeping its canonical URL
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, Page, test } from "@playwright/test";
import { shot } from "../helpers/screenshots";

// The server renders windows hidden so they never flash before the manager
// places them, which means a visible window is the signal that the manager is
// live. Acting before that is a race — one that only ever loses over a real
// network, so it has to be waited on explicitly rather than assumed.
async function waitForDesktop(page: Page) {
  await expect(page.getByTestId("showcase-component-window")).toBeVisible();
}

function watchBrowserFailures(page: Page) {
  const failures: string[] = [];

  page.on("pageerror", (error) => failures.push(`pageerror: ${error.message}`));
  page.on("console", (message) => {
    if (message.type() === "error") {
      failures.push(`console error: ${message.text()}`);
    }
  });

  return failures;
}

test.describe("Showcase desktop", () => {
  test("drives the page as a window and carries the layout across pages", async ({
    page,
  }) => {
    const failures = watchBrowserFailures(page);

    await page.goto("/showcase/button");

    const component = page.getByTestId("showcase-component-window");
    const navigator = page.getByTestId("showcase-navigator-window");

    await expect(component).toBeVisible();
    await expect(navigator).toBeVisible();
    await expect(component).toContainText("Button");
    await shot(page, "showcase-desktop");

    // The window manager owns the geometry: drag it and the page keeps it.
    const titlebar = component.locator("[data-window-titlebar]").first();
    const before = await component.boundingBox();
    const grip = await titlebar.boundingBox();
    if (!before || !grip) throw new Error("component window has no box");

    // Rightwards: the navigator sits to the left of the component window, and a
    // window dragged over it would swallow the link the navigation below needs.
    await page.mouse.move(grip.x + grip.width / 2, grip.y + grip.height / 2);
    await page.mouse.down();
    await page.mouse.move(
      grip.x + grip.width / 2 + 140,
      grip.y + grip.height / 2 + 60,
      { steps: 12 },
    );
    await page.mouse.up();

    const moved = await component.boundingBox();
    if (!moved) throw new Error("component window vanished after drag");
    expect(Math.abs(moved.x - before.x)).toBeGreaterThan(80);
    await shot(page, "showcase-window-dragged");

    // Every component page reuses the window id `component`, so the layout the
    // reader arranged follows them from page to page. The navigator links are
    // LiveView navigation — one document throughout, which is the whole span
    // the manager remembers: a full reload is a fresh tab and starts over.
    await navigator.locator('a[href="/showcase/input"]').click();
    await expect(page).toHaveURL(/\/showcase\/input$/);
    await waitForDesktop(page);
    await expect(component).toContainText("Input");

    const carried = await component.boundingBox();
    if (!carried) throw new Error("component window missing after navigation");
    expect(Math.abs(carried.x - moved.x)).toBeLessThan(8);
    expect(Math.abs(carried.y - moved.y)).toBeLessThan(8);

    expect(failures).toEqual([]);
  });

  // The catalog used to hang off the Start menu, a submenu per category. It
  // moved to the Components window when the Start menu became the same menu on
  // every screen — the showcase reaches its own pages the way the landing
  // desktop reaches its sections, through a window rather than through chrome.
  test("navigates between components through the Components window", async ({
    page,
  }) => {
    const failures = watchBrowserFailures(page);

    await page.goto("/showcase/button");
    await waitForDesktop(page);

    // The tree keeps only the group holding the current page open, so reaching
    // another category means expanding it first — a `<details>` summary.
    const navigator = page.getByTestId("showcase-navigator-window");
    const target = navigator.locator('a[href="/showcase/table"]');
    await expect(target).toHaveCount(1);

    await navigator
      .locator('details:has(a[href="/showcase/table"]) > summary')
      .click();

    // Each entry is a real link, so the click is ordinary navigation.
    await target.click();

    await expect(page).toHaveURL(/\/showcase\/table$/);
    await waitForDesktop(page);
    await expect(page.getByTestId("showcase-component-window")).toContainText(
      "Table",
    );

    expect(failures).toEqual([]);
  });

  test("the Start menu is the app's own, with the showcase's windows in it", async ({
    page,
  }) => {
    const failures = watchBrowserFailures(page);

    await page.goto("/showcase/button");
    await waitForDesktop(page);

    await page.locator("[data-window-start]").click();
    const startMenu = page.locator("#showcase-start-menu");
    await expect(startMenu).toBeVisible();
    await shot(page, "showcase-start-menu");

    // Closing the navigator takes its taskbar button with it; Start ▸ Windows
    // is what brings it back, the same as on every other desktop.
    const navigator = page.getByTestId("showcase-navigator-window");
    await navigator.locator('[data-window-control="close"]').click();
    await expect(navigator).toBeHidden();

    await page.locator("[data-window-start]").click();
    await startMenu
      .locator("[data-start-submenu-trigger]")
      .filter({ hasText: "Windows" })
      .hover();
    await startMenu.locator('[data-window-open="navigator"]').click();
    await expect(navigator).toBeVisible();

    // The app's own entries are named here too, grayed out: the showcase is not
    // a chat, but the menu still says what a chat would offer.
    await page.locator("[data-window-start]").click();
    await startMenu
      .locator("[data-start-submenu-trigger]")
      .filter({ hasText: "Tools" })
      .hover();
    await expect(
      startMenu.getByTestId("start-menu-item-address-book"),
    ).toBeDisabled();

    // About is live here: the showcase mounts the same `about-dialog` the chat
    // and connect screens do, so the entry has something to open. The menu is
    // still open — hovering a group does not close it, and clicking Start again
    // would toggle the whole menu shut.
    await startMenu
      .locator("[data-start-submenu-trigger]")
      .filter({ hasText: "Help" })
      .hover();
    await startMenu.getByTestId("start-menu-item-show_about").click();
    // The wrapper keeps its `hidden` class; the panel inside it is what shows.
    await expect(page.locator('#about-dialog [role="dialog"]')).toBeVisible();

    expect(failures).toEqual([]);
  });

  // Menu bar, dropdown, select and tree all mark "this row" the same way, and
  // the showcase is where that can be checked in one pass. The colour is
  // asserted, not just screenshotted: the failure this guards against is one
  // component quietly going back to the window-title navy, which reads as a
  // deliberate accent until you see it beside the others.
  test("every menu row takes the same highlight", async ({ page }) => {
    const wash = "rgb(204, 211, 230)";

    for (const route of ["menu", "dropdown-menu", "select", "tree-view"]) {
      await page.goto(`/showcase/${route}`);
      await waitForDesktop(page);

      // Several of these pages also render a closed menu as a code example, so
      // the row that can be hovered is the first one actually on screen.
      const row = page.locator(".menu-row").locator("visible=true").first();
      await expect(row).toBeVisible();
      await row.hover();
      await expect(row).toHaveCSS("background-color", wash);
      await shot(row, `menu-row-highlight-${route}`);
    }
  });

  // The demo on /showcase/desktop is a desktop nested inside the shell's own
  // desktop — the one page in the app running two window managers at once. Ids
  // shared between the two would leave the document with pairs of elements
  // answering to one id, and the demo's tray needs a clock hook the showcase
  // bundle actually registers. Neither shows up on any other showcase page,
  // which is why this test names the route explicitly.
  test("the nested demo desktop runs beside the shell's own", async ({
    page,
  }) => {
    const failures = watchBrowserFailures(page);

    await page.goto("/showcase/desktop");
    await waitForDesktop(page);

    for (const id of [
      "#showcase-desktop",
      "#showcase-desktop-demo",
      "#showcase-start-menu",
      "#showcase-desktop-demo-start-menu",
    ]) {
      await expect(page.locator(id)).toHaveCount(1);
    }

    // A ticking tray clock is the proof that ClockHook resolved: an unregistered
    // hook leaves the span empty and logs, which `failures` would catch anyway.
    await expect(page.locator("#showcase-desktop-demo-clock")).toHaveText(
      /^\d{2}:\d{2}$/,
    );

    // Both managers are live: the demo's own windows placed, the shell's too.
    await expect(page.getByTestId("showcase-navigator-window")).toBeVisible();
    await expect(page.locator("#showcase-desktop-demo #readme")).toBeVisible();

    expect(failures).toEqual([]);
  });

  // The whole design rests on this: the window manager decorates markup the
  // server already sent. With JavaScript off, the page is exactly what a
  // crawler receives — and it must still be readable and navigable.
  test.describe("without JavaScript", () => {
    test.use({ javaScriptEnabled: false });

    test("the page still reads and links like a document", async ({ page }) => {
      await page.goto("/showcase/button");

      await expect(page.getByTestId("showcase-component-window")).toContainText(
        "Button",
      );
      await expect(page.locator('link[rel="canonical"]')).toHaveAttribute(
        "href",
        /\/showcase\/button$/,
      );
      // Windows leave the absolute layer and stack as ordinary blocks, so the
      // page reads top to bottom instead of rendering an empty desktop.
      await expect(page.getByTestId("showcase-navigator-window")).toBeVisible();
      await shot(page, "showcase-no-javascript");

      // Navigation survives, through the navigator rather than the Start menu:
      // a popup with nothing to open it is behaviour, not content, and stays
      // hidden.
      await expect(page.locator("#showcase-start-menu")).toBeHidden();
      await page
        .getByTestId("showcase-navigator-window")
        .locator('a[href="/showcase/input"]')
        .click();
      await expect(page).toHaveURL(/\/showcase\/input$/);
      await expect(page.getByTestId("showcase-component-window")).toContainText(
        "Input",
      );
    });
  });
});

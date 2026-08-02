import { expect, Page, test } from "@playwright/test";
import { shot } from "../helpers/screenshots";

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
  test("drives the page as a window and remembers where it was put", async ({
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

    await page.mouse.move(grip.x + grip.width / 2, grip.y + grip.height / 2);
    await page.mouse.down();
    await page.mouse.move(
      grip.x + grip.width / 2 - 140,
      grip.y + grip.height / 2 + 60,
      { steps: 12 },
    );
    await page.mouse.up();

    const moved = await component.boundingBox();
    if (!moved) throw new Error("component window vanished after drag");
    expect(Math.abs(moved.x - before.x)).toBeGreaterThan(80);
    await shot(page, "showcase-window-dragged");

    await page.reload();
    const restored = await page
      .getByTestId("showcase-component-window")
      .boundingBox();
    if (!restored) throw new Error("component window missing after reload");
    expect(Math.abs(restored.x - moved.x)).toBeLessThan(8);

    expect(failures).toEqual([]);
  });

  test("navigates between components through the Start menu", async ({
    page,
  }) => {
    const failures = watchBrowserFailures(page);

    await page.goto("/showcase/button");

    await page.locator("[data-window-start]").click();
    const startMenu = page.locator("#showcase-start-menu");
    await expect(startMenu).toBeVisible();
    await shot(page, "showcase-start-menu");

    // Components are filed by category. The submenu flies out on hover — a
    // click would toggle it straight back shut.
    await startMenu
      .locator("[data-start-submenu-trigger]")
      .filter({ hasText: "Layout" })
      .hover();

    // Each entry is a real link, so the click is ordinary navigation.
    const target = startMenu.locator('a[href="/showcase/table"]');
    await expect(target).toHaveCount(1);
    await target.click();

    await expect(page).toHaveURL(/\/showcase\/table$/);
    await expect(page.getByTestId("showcase-component-window")).toContainText(
      "Table",
    );

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

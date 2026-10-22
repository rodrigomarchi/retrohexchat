/**
 * @section PW - Public Pages, Landing, And Showcase
 * @flow PW33 [done] The public Spaces page shows the world in real pictures — the island, the Construct, the Game Room, the Office and the character creator — on a desktop and a phone, and its way in takes a visitor through creating an account straight into the #lobby Space, put in the channel on arrival
 * @flow PW34 [done] A member's way in on the Spaces page opens the #lobby Space in a tab of its own, and the features window and the home page lead to the Spaces page
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { devices, expect, test } from "@playwright/test";
import { closeUsers, newSignedInUser } from "../helpers/chatUsers";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { shot } from "../helpers/screenshots";
import { waitForView } from "../helpers/liveView";

test.describe("Spaces page", () => {
  test("a visitor sees the world in pictures and is led into the #lobby Space (PW33)", async ({
    browser,
  }) => {
    for (const [label, options] of [
      ["desktop", {}],
      ["phone", devices["Pixel 5"]],
    ] as const) {
      const ctx = await browser.newContext(options);
      const page = await ctx.newPage();

      try {
        await page.goto("/spaces");
        await waitForView(page);
        await expect(page.locator("#spaces-heading")).toBeVisible();

        // A phone shows the page's first window; the others wait in the
        // taskbar's group. A desktop shows all four, each brought forward in
        // turn and read from its top.
        const windows =
          label === "phone" ? ["intro"] : ["intro", "places", "creator", "how"];

        for (const id of windows) {
          const window = page.getByTestId(`site-window-${id}`);
          await expect(window).toBeVisible();
          await window.dispatchEvent("pointerdown");
          const body = window.locator(".site-window__body");
          await body.evaluate((el) => (el.scrollTop = 0));

          // Every picture loads: a broken image is a page a search result
          // should not send anybody to.
          for (const picture of await window
            .locator('img[src*="/images/spaces/"]')
            .all()) {
            await picture.scrollIntoViewIfNeeded();
            await expect
              .poll(() =>
                picture.evaluate((img: HTMLImageElement) => img.naturalWidth),
              )
              .toBeGreaterThan(0);
          }

          await body.evaluate((el) => (el.scrollTop = 0));
          await shot(window, `spaces-${id}-${label}`);
        }

        const intro = page.getByTestId("site-window-intro");
        // Brought forward the way the window manager hears a click on it: the
        // windows read last cover its title bar.
        await intro.dispatchEvent("pointerdown");
        const enter = intro.getByTestId("spaces-enter");
        await enter.scrollIntoViewIfNeeded();
        await shot(page, `spaces-way-in-${label}`);
        await enter.click();
        await expect(page).toHaveURL(
          /\/connect\?(?=.*signup=space)(?=.*return_to=%2Fspace%2FI2xvYmJ5)/,
        );
        await shot(page, `spaces-enter-asks-to-sign-in-${label}`);

        // A new account lands in the Space itself, not in a refusal: the
        // Space puts its owner in #lobby on arrival.
        const connect = new ConnectPage(page);
        await connect.enterNickname(uniqueNickname("spv"));
        await connect.registerWithPassword("pass12345");
        await expect(page).toHaveURL(/\/space\/I2xvYmJ5/, { timeout: 20_000 });
        await expect(page.getByTestId("space-creator-enter")).toBeVisible({
          timeout: 15_000,
        });
        await expect(page.getByTestId("space-denied")).toHaveCount(0);
        await shot(page, `spaces-new-account-in-the-space-${label}`);
      } finally {
        await ctx.close();
      }
    }
  });

  test("a member walks into the #lobby Space, and the site leads to the page (PW34)", async ({
    browser,
  }) => {
    const ana = await newSignedInUser(browser, "spg");

    try {
      await ana.page.goto("/spaces");
      await waitForView(ana.page);
      const enter = ana.page.getByTestId("spaces-enter");
      await expect(enter).toHaveAttribute("href", "/space/I2xvYmJ5");
      await shot(ana.page, "spaces-page-member");

      await enter.click();
      const popupPromise = ana.page.waitForEvent("popup");
      await ana.page.getByTestId("open-tab-confirm-open").click();
      const space = await popupPromise;
      await expect(space).toHaveURL(/\/space\/I2xvYmJ5/);
      await expect(space.getByTestId("space-creator-enter")).toBeVisible({
        timeout: 15_000,
      });
      await shot(space, "spaces-member-in-the-lobby-space");
      await space.close();

      // The features window and the home page lead here.
      await ana.page.goto("/features");
      await waitForView(ana.page);
      const fromFeatures = ana.page.locator('a[href$="/spaces"]').first();
      await fromFeatures.scrollIntoViewIfNeeded();
      await shot(ana.page, "features-link-to-spaces");
      await fromFeatures.click();
      await expect(ana.page.locator("#spaces-heading")).toBeVisible();

      // And the home page a visitor lands on, under the picture of a Space.
      const visitor = await browser.newPage();
      try {
        await visitor.goto("/");
        await waitForView(visitor);
        // The home's windows wait on the desk, behind the Welcome icon.
        await visitor.getByTestId("desktop-icon-page-home").dblclick();
        const window = visitor.getByTestId(
          "site-window-three-ways-to-be-together",
        );
        await expect(window).toBeVisible();
        await window.dispatchEvent("pointerdown");
        const fromHome = window.locator('a[href$="/spaces"]');
        await fromHome.scrollIntoViewIfNeeded();
        await fromHome.click();
        await expect(visitor.locator("#spaces-heading")).toBeVisible();
      } finally {
        await visitor.close();
      }
    } finally {
      await closeUsers([ana]);
    }
  });
});

import { expect, test } from "@playwright/test";
import { shot } from "../helpers/screenshots";

// The five desktops are meant to read as one product, and the place that kept
// drifting is the header: the landing pages carried a Connect CTA and a lone
// hamburger while the chat had already moved to an icon rail, and help shipped
// a status bar whose breadcrumb ate the width the rail needed.
//
// These are the public shells — the ones reachable with no session, so a single
// spec can hold them side by side. The chat's own mobile chrome is covered by
// chat-mobile-desktop.spec.ts, which needs a logged-in user.
const PHONE = { width: 390, height: 780 };

const SHELLS = [
  { name: "landing", path: "/", rail: 3 },
  { name: "connect", path: "/connect", rail: 2 },
  { name: "help", path: "/chat/help", rail: 4 },
];

test.describe("Shell chrome parity", () => {
  test.use({ viewport: PHONE });

  for (const shell of SHELLS) {
    test(`${shell.name} wears the same phone chrome`, async ({ page }) => {
      const failures: string[] = [];
      page.on("pageerror", (error) =>
        failures.push(`pageerror: ${error.message}`),
      );
      page.on("console", (message) => {
        if (message.type() === "error")
          failures.push(`console error: ${message.text()}`);
      });

      await page.goto(shell.path);
      await expect(page.getByTestId("app-header")).toBeVisible();

      // Below 768px the window manager stamps the stacked class, which is what
      // swaps the textual menu strip for the rail.
      await expect(page.locator(".desktop--stacked")).toHaveCount(1);

      const rail = page.getByTestId("app-mobile-menu-rail");
      await expect(rail).toBeVisible();
      await expect(rail.locator("button")).toHaveCount(shell.rail);
      await expect(page.locator("[data-menubar-trigger]").first()).toBeHidden();

      // Every shell ends its taskbar with the tray clock, help and showcase
      // included — they used to have no tray at all. `data-clock` is the one
      // marker all five carry: the app shells tick it with a LiveView hook, the
      // landing with a plain interval, and neither is the other's business.
      await expect(page.locator(".desktop-taskbar [data-clock]")).toHaveText(
        /^\d{2}:\d{2}$/,
      );

      await shot(page, `${shell.name}-phone-chrome`);
      expect(failures).toEqual([]);
    });
  }

  test("a rail button opens the shared drawer on its own section", async ({
    page,
  }) => {
    await page.goto("/");
    await expect(page.getByTestId("app-header")).toBeVisible();

    // The landing runs this engine without a LiveSocket, so a working drawer
    // here is the proof that the vanilla bundle and the hook share one
    // implementation rather than two that drifted.
    const language = page.getByTestId("app-mobile-menu-rail-language");
    await language.click();

    await expect(language).toHaveAttribute("data-active", "true");
    const drawer = page.getByTestId("app-mobile-menu-section-language");
    await expect(drawer).toBeVisible();
    await expect(
      page.getByTestId("app-mobile-menu-section-navigate"),
    ).toBeHidden();
    await shot(page, "landing-phone-drawer");

    // The same button puts it away; a different one only swaps the section.
    await page.getByTestId("app-mobile-menu-rail-navigate").click();
    await expect(
      page.getByTestId("app-mobile-menu-section-navigate"),
    ).toBeVisible();
    await expect(drawer).toBeHidden();
  });

  test("the landing keeps its Connect out of the chrome", async ({ page }) => {
    await page.goto("/");
    await expect(page.getByTestId("app-header")).toBeVisible();

    // A CTA in the header and a second one in the tray were chrome no other
    // shell had. The way in is the Start menu, named as everywhere else — and
    // the page's own content is still free to invite you in.
    await expect(
      page.getByTestId("app-header").getByText("Connect"),
    ).toHaveCount(0);
    await expect(
      page.getByTestId("landing-taskbar").getByText("Connect"),
    ).toHaveCount(0);

    await page.locator("[data-window-start]").click();
    await expect(
      page.locator("#landing-start-menu").getByText("Open the app"),
    ).toBeVisible();
  });
});

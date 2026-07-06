import { test, expect } from "@playwright/test";
import { newP2PUser, closeP2PUsers } from "../helpers/p2pFlows";

// Phase 2 acceptance: opening /space/:token as an identified user renders the
// canvas shell (space name in the header) and the engine paints a non-blank
// canvas (floor tiles + avatar) once the Phoenix Channel join returns
// space_init.
test.describe("Virtual space canvas", () => {
  test("renders the shell and paints a non-blank canvas", async ({
    browser,
  }) => {
    const user = await newP2PUser(browser, "spc");
    const channel = `#spc-${Date.now().toString(36)}`;

    try {
      await user.chat.sendMessage(`/join ${channel}`);
      await user.chat.expectTabVisible(channel);

      await user.chat.sendMessage("/space Tavern E2E");

      // The invite card exposes the /space/<token> link; read it and open the
      // space directly (the card CTA targets a new tab).
      const spaceLink = user.page.locator('a[href*="/space/"]').first();
      await expect(spaceLink).toBeVisible({ timeout: 10_000 });
      const href = await spaceLink.getAttribute("href");
      expect(href).toMatch(/\/space\/[^/\s]+$/);

      await user.page.goto(href as string);

      const shell = user.page.getByTestId("space-shell");
      await expect(shell).toBeVisible({ timeout: 15_000 });
      // The space name shows in the window-manager chrome (window title + status bar).
      await expect(user.page.getByTestId("space-root")).toContainText("Tavern E2E");

      const canvas = user.page.locator("#space-canvas");
      await expect(canvas).toBeVisible();

      // Poll the drawing buffer until the engine has painted something: a blank
      // canvas is fully transparent/uniform, a rendered one has colour variance.
      await expect(async () => {
        const rendered = await canvas.evaluate((el: HTMLCanvasElement) => {
          const ctx = el.getContext("2d");
          if (!ctx || el.width === 0 || el.height === 0) return false;
          const { data } = ctx.getImageData(0, 0, el.width, el.height);
          let opaque = 0;
          const first = [data[0], data[1], data[2], data[3]];
          let varied = false;
          for (let i = 0; i < data.length; i += 4) {
            if (data[i + 3] !== 0) opaque += 1;
            if (
              data[i] !== first[0] ||
              data[i + 1] !== first[1] ||
              data[i + 2] !== first[2] ||
              data[i + 3] !== first[3]
            ) {
              varied = true;
            }
          }
          return opaque > 0 && varied;
        });
        expect(rendered).toBe(true);
      }).toPass({ timeout: 15_000 });
    } finally {
      await closeP2PUsers([user]);
    }
  });
});

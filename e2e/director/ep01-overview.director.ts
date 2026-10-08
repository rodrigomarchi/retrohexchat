/**
 * Director — EP01, "RetroHexChat: a real IRC client, in your browser".
 *
 * Films the episode's scenes for the YouTube channel. Not a test: nothing here
 * guards a behaviour, and it never runs with the suite. The script, narration
 * and timing live in `retro_hex_chat_videos/episodes/01-overview/script.md`;
 * each `film` call below plays one scene's SCREEN directions.
 *
 *   make e2e.director SHOTS=/abs/shots.json OUT=/abs/capture
 */
import { expect, test } from "@playwright/test";
import { ChatPage } from "../pages/ChatPage";
import { cameraContext, film, shotFor, typeOnCamera } from "./shots";

const CONNECT_WINDOW = '[data-testid="landing-connect-window"]';

// The viewer's nickname for the whole episode. A registered nick takes the
// sign-in path instead, so a retake needs a fresh database or another nick.
const NICK = process.env.DIRECTOR_NICK || "Pixel";
const PASSWORD = "retro1998";

test.describe("EP01 overview", () => {
  test("01 connect in five seconds", async ({ browser }) => {
    const shot = shotFor(1);
    const ctx = await cameraContext(browser);
    const page = await ctx.newPage();

    // Off camera: the landing has painted and its fonts are in.
    await page.goto("/");
    await expect(page.locator(CONNECT_WINDOW)).toBeVisible();
    await page.evaluate(() => document.fonts.ready);

    await film(page, shot, async (pace) => {
      await pace(1500);
      await page.locator(`${CONNECT_WINDOW} #nickname`).click();
      await typeOnCamera(page, `${CONNECT_WINDOW} #nickname`, NICK);
      await pace(500);
      await page
        .locator(`${CONNECT_WINDOW} [data-testid="connect-btn"]`)
        .click();

      const password = page.locator(`${CONNECT_WINDOW} #reg-password`);
      await expect(
        password,
        `"${NICK}" is already registered — run \`make e2e.prepare\` or set DIRECTOR_NICK`,
      ).toBeVisible({ timeout: 15_000 });
      await pace(600);
      await typeOnCamera(page, `${CONNECT_WINDOW} #reg-password`, PASSWORD);
      await typeOnCamera(
        page,
        `${CONNECT_WINDOW} #reg-password-confirm`,
        PASSWORD,
      );
      await pace(400);
      await page
        .locator(`${CONNECT_WINDOW} [data-testid="register-btn"]`)
        .click();

      await new ChatPage(page).waitUntilConnected();
      await pace(2500);
    });

    await ctx.close();
  });
});

/**
 * @section PW - Public Pages, Landing, And Showcase
 * @flow PW22 [done] The public games catalogue leads from a game's page, through the sign-in window over the same desktop, into the game
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, test } from "@playwright/test";
import { uniqueNickname } from "../pages/ConnectPage";
import { shot } from "../helpers/screenshots";
import { bringForward } from "../helpers/siteWindows";

const SIGN_IN_WINDOW = '[data-testid="document-window-connect"]';

test("a game's public page signs a reader in and lands them on the game (PW22)", async ({
  page,
}) => {
  await page.goto("/games");
  await expect(page.locator("#games-heading")).toBeVisible();
  await shot(page, "games-catalogue");

  // The catalogue is a window per list: the page's taskbar group brings the
  // multiplayer one forward, and a card opens the game's page in its place.
  await bringForward(page, "site-multiplayer");
  await page.getByTestId("game-card-hex-tennis").scrollIntoViewIfNeeded();
  await page.getByTestId("game-card-hex-tennis").click();
  await expect(page).toHaveURL(/\/games\/hex-tennis$/);
  await expect(page.locator("#game-heading")).toHaveText("Hex Tennis");
  // One window, the game's home: a way in per mode.
  await expect(page.getByTestId("game-way-hex_tennis_quick")).toContainText(
    "Quick Match",
  );
  await shot(page, "game-page");

  // Playing needs a nickname: the sign-in window opens over the same
  // desktop, remembering the game it was asked for.
  await page
    .getByTestId("game-way-hex_tennis")
    .getByTestId("game-play")
    .click();
  const connect = page.locator(SIGN_IN_WINDOW);
  await expect(connect).toBeVisible();
  await expect(page).toHaveURL(/\/connect\?.*return_to=%2Fplay%2Fhex_tennis/);

  await connect.locator("#nickname").fill(uniqueNickname("PWGame"));
  await connect.locator('[data-testid="connect-btn"]').click();
  await connect.locator("#reg-password").fill("pw12345");
  await connect.locator("#reg-password-confirm").fill("pw12345");
  await connect.locator('[data-testid="register-btn"]').click();

  // Signing in lands on the game the page was about, not on the chat.
  await expect(page).toHaveURL(/\/play\/hex_tennis$/, { timeout: 15000 });
  await expect(page.getByRole("button", { name: "Play vs AI" })).toBeVisible();
});

test("an arcade game's page is the same sheet the in-app Arcade shows (PW22)", async ({
  page,
}) => {
  await page.goto("/games/freedoom1");
  await expect(page.locator("#game-heading")).toHaveText("Freedoom: Phase 1");

  // The screenshot, what the game is, every key and the tips — before any
  // nickname, exactly as the Arcade window shows them after one.
  const sheet = page.locator('[data-testid="site-window-game"]');
  await expect(sheet.locator('img[src*="freedoom1"]')).toBeVisible();
  await expect(
    sheet.getByTestId("game-controls").locator("kbd").first(),
  ).toBeVisible();
  await expect(sheet).toContainText(
    "Freedoom serves both as a standalone game",
  );
  await expect(sheet.getByTestId("game-play")).toBeVisible();
  await expect(sheet.getByTestId("game-how-to-play")).toBeVisible();
  await shot(page, "arcade-game-page");

  await page.setViewportSize({ width: 390, height: 844 });
  await expect(sheet.getByTestId("game-play")).toBeVisible();
  await shot(page, "arcade-game-page-phone");
  await sheet.getByTestId("game-controls").scrollIntoViewIfNeeded();
  await shot(page, "arcade-game-page-phone-keys");
});

test("both catalogues are listed on their category shelves on every page that lists them (PW22)", async ({
  page,
}) => {
  await page.goto("/games");
  await bringForward(page, "site-arcade");
  const arcade = page.getByTestId("site-window-arcade");
  await expect(arcade.getByTestId("game-group-adventure")).toBeVisible();
  await expect(arcade.getByTestId("game-group-fps")).toBeVisible();
  await expect(arcade.getByTestId("game-card-scummvm-bass")).toBeVisible();
  await shot(page, "games-catalogue-arcade");

  // Taller than the desk, the window stops at its bottom and its body
  // scrolls to the last card, rather than the frame growing past the cap
  // and the last rows being cut off with nothing to scroll.
  const body = arcade.locator(".site-window__body");
  const [windowBottom, deskBottom] = await arcade.evaluate((el) => [
    el.getBoundingClientRect().bottom,
    el.closest(".desktop__workspace")!.getBoundingClientRect().bottom,
  ]);
  expect(windowBottom).toBeLessThanOrEqual(deskBottom + 1);
  await body.hover();
  await page.mouse.wheel(0, 10_000);
  await expect
    .poll(() =>
      body.evaluate(
        (el) => el.scrollTop + el.clientHeight >= el.scrollHeight - 1,
      ),
    )
    .toBe(true);
  await expect(arcade.getByTestId("game-card-scummvm-soltys")).toBeInViewport();
  await shot(page, "games-catalogue-arcade-scrolled");

  await page.goto("/features");
  await bringForward(page, "site-solo-arcade");
  const summary = page.getByTestId("site-window-solo-arcade");
  await expect(summary.getByTestId("arcade-link-freedoom1")).toBeVisible();
  await shot(summary, "features-arcade");

  // The home's windows wait closed behind the chat; the list is there all
  // the same, every game on its shelf.
  await page.goto("/");
  await expect(
    page
      .getByTestId("index-arcade-games")
      .locator('[data-testid^="arcade-link-"]'),
  ).toHaveCount(18);

  // The help lists the same games, from the same catalogue, each opening
  // its page.
  await page.goto("/chat/help/feature-arcade");
  const help = page.getByTestId("help-games-adventure");
  await help.scrollIntoViewIfNeeded();
  await expect(help.locator('a[href="/games/scummvm-bass"]')).toBeVisible();
  await shot(page, "help-arcade-games");
  await page.goto("/chat/help/feature-retro-games");
  await expect(
    page
      .getByTestId("help-games-sports")
      .locator('a[href="/games/hex-tennis"]'),
  ).toBeVisible();
  await shot(page, "help-retro-games");

  // The Retro Games on the same shelves as the app's folders.
  await page.goto("/games");
  await bringForward(page, "site-multiplayer");
  const retro = page.getByTestId("site-window-multiplayer");
  await expect(retro.getByTestId("game-group-cards")).toBeVisible();
  await shot(page, "games-catalogue-retro");

  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/games");
  await bringForward(page, "site-arcade");
  await shot(page, "games-catalogue-arcade-phone");
});

/**
 * @section LC - Localization
 * @flow LC1 [done] The sign-in window switches between English and pt-BR, at the address in that language, and persists the selection
 * @flow LC2 [done] A first visit uses pt-BR from Accept-Language
 * @flow LC3 [done] Switching to Japanese survives a reload
 * @flow LC4 [done] pt-BR is kept through registration into the chat shell
 * @flow LC5 [done] Language switches from the chat menu bar
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect, type Locator, type Page } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { CHAT_URL } from "../helpers/urls";

// The menu bar a language is picked from: the sign-in window's own, or the
// chat window's when nothing is in front of it.
function signIn(page: Page): Locator {
  return page.getByTestId("document-window-connect");
}

async function chooseLanguage(
  page: Page,
  locale: string,
  menuBar: Locator = page.getByTestId("chat-window"),
) {
  // A narrow window folds its menus into the icon rail; the same languages
  // are in its drawer.
  const item = menuBar.locator(
    `[data-testid="language-menu-item-${locale}"] a:visible`,
  );
  const trigger = menuBar.getByTestId("language-menu-trigger");
  const rail = menuBar.getByTestId("app-mobile-menu-rail-language");

  // A LiveView re-render arriving just after connect can close the dropdown
  // that was only now opened — the first-menu-open flake this suite works
  // around elsewhere. Locally the re-render lands before the click; against a
  // deployment it lands after, and the item never appears.
  await expect(async () => {
    if (await trigger.isVisible()) await trigger.click();
    else await rail.click();
    await expect(item.first()).toBeVisible({ timeout: 1_000 });
  }).toPass({ timeout: 15_000 });

  await item.first().click();
}

test.describe("Internationalization", () => {
  test("switches the connect UI between English and pt-BR and persists the selection", async ({
    page,
  }) => {
    await page.goto("/connect");

    await expect(page.locator("html")).toHaveAttribute("lang", "en");
    await expect(
      signIn(page).getByText("Connect to RetroHexChat").first(),
    ).toBeVisible();
    await expect(page.locator("#nickname")).toHaveAttribute(
      "placeholder",
      "Enter your nickname...",
    );

    await chooseLanguage(page, "pt_BR", signIn(page));

    await expect(page).toHaveURL(/\/pt-BR\/connect$/);
    await expect(page.locator("html")).toHaveAttribute("lang", "pt-BR");
    await expect(
      signIn(page).getByText("Conectar ao RetroHexChat").first(),
    ).toBeVisible();
    await expect(page.locator("#nickname")).toHaveAttribute(
      "placeholder",
      "Digite seu apelido...",
    );

    await page.reload();

    await expect(page.locator("html")).toHaveAttribute("lang", "pt-BR");
    await expect(
      signIn(page).getByText("Conectar ao RetroHexChat").first(),
    ).toBeVisible();

    await chooseLanguage(page, "en", signIn(page));
    await expect(page).toHaveURL(/\/\/[^/]+\/connect$/);

    await expect(page.locator("html")).toHaveAttribute("lang", "en");
    await expect(
      signIn(page).getByText("Connect to RetroHexChat").first(),
    ).toBeVisible();
  });

  test("uses pt-BR from Accept-Language on the first visit", async ({
    browser,
  }) => {
    const context = await browser.newContext({ locale: "pt-BR" });
    const page = await context.newPage();

    try {
      await page.goto("/connect");

      await expect(page.locator("html")).toHaveAttribute("lang", "pt-BR");
      await expect(
        signIn(page).getByText("Conectar ao RetroHexChat").first(),
      ).toBeVisible();
      await expect(page.locator("#nickname")).toHaveAttribute(
        "placeholder",
        "Digite seu apelido...",
      );
    } finally {
      await context.close();
    }
  });

  test("switches to Japanese and survives a reload", async ({ page }) => {
    await page.goto("/connect");

    await chooseLanguage(page, "ja", signIn(page));

    await expect(page).toHaveURL(/\/ja\/connect$/);
    await expect(page.locator("html")).toHaveAttribute("lang", "ja");
    await expect(page.locator("html")).toHaveAttribute("dir", "ltr");

    await page.reload();

    await expect(page.locator("html")).toHaveAttribute("lang", "ja");
    await expect(page.locator("html")).toHaveAttribute("dir", "ltr");
  });

  test("keeps pt-BR through registration into the chat shell", async ({
    page,
  }) => {
    const connect = new ConnectPage(page);

    await page.goto("/locale/pt_BR?return_to=/connect");
    await expect(page.locator("html")).toHaveAttribute("lang", "pt-BR");

    await connect.enterNickname(uniqueNickname("i18n"));
    await expect(page.getByText("Registrar e conectar")).toBeVisible();
    await connect.registerWithPassword("pass12345");

    await expect(page).toHaveURL(CHAT_URL);
    await expect(page.locator("html")).toHaveAttribute("lang", "pt-BR");
    await expect(page.getByTestId("chat-input-field")).toHaveAttribute(
      "placeholder",
      /Mensagem para #lobby/,
    );
    await expect(page.getByTestId("chat-input-send")).toContainText("Enviar");
  });

  test("switches language from the chat menu bar", async ({ page }) => {
    const connect = new ConnectPage(page);

    await page.goto("/connect");
    await connect.enterNickname(uniqueNickname("i18nchat"));
    await connect.registerWithPassword("pass12345");

    await expect(page).toHaveURL(CHAT_URL);

    await chooseLanguage(page, "ja");

    await expect(page).toHaveURL(CHAT_URL);
    await expect(page).toHaveURL(/\/ja(\/|$)/);
    await expect(page.locator("html")).toHaveAttribute("lang", "ja");
    await expect(page.locator("html")).toHaveAttribute("dir", "ltr");
  });
});

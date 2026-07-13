import { test, expect, type Page } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";

async function chooseLanguage(page: Page, locale: string) {
  await page.getByTestId("language-menu-trigger").click();
  await page.getByTestId(`language-menu-item-${locale}`).getByRole("link").click();
}

test.describe("Internationalization", () => {
  test("switches the connect UI between English and pt-BR and persists the selection", async ({
    page,
  }) => {
    await page.goto("/connect");

    await expect(page.locator("html")).toHaveAttribute("lang", "en");
    await expect(page.getByText("Connect to RetroHexChat")).toBeVisible();
    await expect(page.locator("#nickname")).toHaveAttribute(
      "placeholder",
      "Enter your nickname...",
    );

    await chooseLanguage(page, "pt_BR");

    await expect(page).toHaveURL(/\/connect$/);
    await expect(page.locator("html")).toHaveAttribute("lang", "pt-BR");
    await expect(page.getByText("Conectar ao RetroHexChat")).toBeVisible();
    await expect(page.locator("#nickname")).toHaveAttribute(
      "placeholder",
      "Digite seu apelido...",
    );

    await page.reload();

    await expect(page.locator("html")).toHaveAttribute("lang", "pt-BR");
    await expect(page.getByText("Conectar ao RetroHexChat")).toBeVisible();

    await chooseLanguage(page, "en");

    await expect(page.locator("html")).toHaveAttribute("lang", "en");
    await expect(page.getByText("Connect to RetroHexChat")).toBeVisible();
  });

  test("uses pt-BR from Accept-Language on the first visit", async ({
    browser,
  }) => {
    const context = await browser.newContext({ locale: "pt-BR" });
    const page = await context.newPage();

    try {
      await page.goto("/connect");

      await expect(page.locator("html")).toHaveAttribute("lang", "pt-BR");
      await expect(page.getByText("Conectar ao RetroHexChat")).toBeVisible();
      await expect(page.locator("#nickname")).toHaveAttribute(
        "placeholder",
        "Digite seu apelido...",
      );
    } finally {
      await context.close();
    }
  });

  test("switches to Arabic with RTL document direction", async ({ page }) => {
    await page.goto("/connect");

    await chooseLanguage(page, "ar");

    await expect(page).toHaveURL(/\/connect$/);
    await expect(page.locator("html")).toHaveAttribute("lang", "ar");
    await expect(page.locator("html")).toHaveAttribute("dir", "rtl");

    await page.reload();

    await expect(page.locator("html")).toHaveAttribute("lang", "ar");
    await expect(page.locator("html")).toHaveAttribute("dir", "rtl");
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

    await expect(page).toHaveURL(/\/chat(\?.*)?$/);
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

    await expect(page).toHaveURL(/\/chat(\?.*)?$/);

    await chooseLanguage(page, "ar");

    await expect(page).toHaveURL(/\/chat$/);
    await expect(page.locator("html")).toHaveAttribute("lang", "ar");
    await expect(page.locator("html")).toHaveAttribute("dir", "rtl");
  });
});

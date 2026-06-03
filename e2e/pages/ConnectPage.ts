import { Page, Locator, expect } from '@playwright/test';

// Page Object for the app ConnectLive flow at /connect.
// Mirrors the three steps in the LiveView state machine: :nickname, :register,
// :password (only one is visible at a time).
export class ConnectPage {
  readonly page: Page;
  readonly nicknameInput: Locator;
  readonly connectButton: Locator;
  readonly backButton: Locator;
  // :nickname step error feedback (validate event, debounced 300ms)
  readonly nicknameError: Locator;
  // :register step (brand-new nickname)
  readonly registerPasswordInput: Locator;
  readonly registerPasswordConfirmInput: Locator;
  readonly registerButton: Locator;
  readonly registerError: Locator;
  // :password step (already-registered nickname)
  readonly authPasswordInput: Locator;
  readonly authButton: Locator;
  readonly authError: Locator;

  constructor(page: Page) {
    this.page = page;
    this.nicknameInput = page.locator('#nickname');
    this.connectButton = page.getByTestId('connect-btn');
    this.backButton = page.getByTestId('back-btn');
    // The validation error is the only .text-destructive paragraph inside
    // the :nickname step form (phx-submit=connect).
    this.nicknameError = page
      .locator('form[phx-submit="connect"] p.text-destructive');
    this.registerPasswordInput = page.locator('#reg-password');
    this.registerPasswordConfirmInput = page.locator('#reg-password-confirm');
    this.registerButton = page.getByTestId('register-btn');
    this.registerError = page
      .locator('form[phx-submit="register"] p.text-destructive');
    this.authPasswordInput = page.locator('#password');
    this.authButton = page.getByTestId('auth-btn');
    this.authError = page
      .locator('form[phx-submit="authenticate"] p.text-destructive');
  }

  // Click the "Back" button (visible in :register and :password steps).
  async clickBack() {
    await this.backButton.click();
    await expect(this.nicknameInput).toBeVisible();
  }

  // Type into the nickname field WITHOUT submitting — useful for asserting
  // validation behavior. Waits past the 300ms phx-debounce so the
  // server-side validate event has fired and any error has rendered.
  async typeNickname(nick: string) {
    await this.nicknameInput.fill(nick);
    // The LiveView phx-debounce is 300ms; allow a bit of slack.
    await this.page.waitForTimeout(400);
  }

  async open() {
    await this.page.goto('/connect');
    await expect(this.nicknameInput).toBeVisible();
  }

  async enterNickname(nick: string) {
    await this.nicknameInput.fill(nick);
    // phx-debounce=300ms on the validate event — wait for the connect button
    // to clear validation state before clicking.
    await expect(this.connectButton).toBeEnabled();
    await this.connectButton.click();
  }

  async registerWithPassword(password: string) {
    await expect(this.registerPasswordInput).toBeVisible();

    for (let attempt = 0; attempt < 3; attempt++) {
      await this.registerPasswordInput.fill('');
      await this.registerPasswordConfirmInput.fill('');
      await this.registerPasswordInput.fill(password);
      await this.registerPasswordConfirmInput.fill(password);
      await this.page.waitForTimeout(100);

      if (
        (await this.registerPasswordInput.inputValue()) === password &&
        (await this.registerPasswordConfirmInput.inputValue()) === password
      ) {
        break;
      }
    }

    await expect(this.registerPasswordInput).toHaveValue(password);
    await expect(this.registerPasswordConfirmInput).toHaveValue(password);
    await expect(this.registerButton).toBeEnabled();
    await this.registerButton.click();
  }

  async authenticateWithPassword(password: string) {
    await expect(this.authPasswordInput).toBeVisible();
    await this.authPasswordInput.fill(password);
    await expect(this.authButton).toBeEnabled();
    await this.authButton.click();
  }

  // Convenience for tests that reuse a SHARED nick across runs (e.g. the
  // built-in TestAdmin admin nick): tries register flow first, falls back
  // to auth if the nick already exists in the e2e database.
  async signIn(nick: string, password: string) {
    await this.enterNickname(nick);
    const stepInput = this.page.locator('#reg-password, #password').first();
    await expect(stepInput).toBeVisible();

    if ((await stepInput.getAttribute('id')) === 'reg-password') {
      await this.registerWithPassword(password);
    } else {
      await this.authenticateWithPassword(password);
    }
  }
}

// Generates a nickname that satisfies ConnectLive validation:
//   - starts with a letter
//   - 1–16 chars
//   - no spaces
// And is unique enough to avoid collisions across runs without a DB reset.
export function uniqueNickname(prefix = 'e2e'): string {
  const rand = Math.random().toString(36).slice(2, 8);
  return `${prefix}${rand}`;
}

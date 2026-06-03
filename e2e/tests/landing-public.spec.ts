import { expect, Page, test } from '@playwright/test';

function watchBrowserFailures(page: Page) {
  const failures: string[] = [];

  page.on('pageerror', (error) => failures.push(`pageerror: ${error.message}`));
  page.on('console', (message) => {
    if (message.type() === 'error') {
      failures.push(`console error: ${message.text()}`);
    }
  });
  page.on('requestfailed', (request) => {
    const url = request.url();
    if (url.includes('/assets/')) {
      failures.push(`request failed: ${url} ${request.failure()?.errorText ?? ''}`);
    }
  });
  page.on('response', (response) => {
    const url = response.url();
    if (url.includes('/assets/') && response.status() >= 400) {
      failures.push(`asset response ${response.status()}: ${url}`);
    }
  });

  return failures;
}

test.describe('Landing public pages', () => {
  test('loads public bundle and enables desktop interactions', async ({ page }) => {
    const failures = watchBrowserFailures(page);

    await page.goto('/');
    await expect(page.locator('script[src="/assets/js/public_pages.js"]')).toHaveCount(1);
    await expect(page.locator('#hero-heading')).toBeVisible();

    await expect(page.locator('#readme-popup')).toBeHidden();
    await page.locator('[data-show-target="#readme-popup"]').click();
    await expect(page.locator('#readme-popup')).toBeVisible();
    await expect(page.locator('#readme-popup')).toHaveAttribute('aria-hidden', 'false');

    await page.keyboard.press('Escape');
    await expect(page.locator('#readme-popup')).toBeHidden();
    await expect(page.locator('#readme-popup')).toHaveAttribute('aria-hidden', 'true');

    await page.locator('a[href="/features"]').first().click();
    await expect(page).toHaveURL(/\/features$/);
    await expect(page.locator('#features-heading')).toBeVisible();

    expect(failures).toEqual([]);
  });

  test('mobile navigation opens and links to app connect flow', async ({ page }) => {
    const failures = watchBrowserFailures(page);

    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto('/');

    const menuButton = page.locator('button[aria-controls="mobile-nav"]');
    const mobileNav = page.locator('#mobile-nav');

    await expect(mobileNav).toBeHidden();
    await menuButton.click();
    await expect(menuButton).toHaveAttribute('aria-expanded', 'true');
    await expect(mobileNav).toBeVisible();

    await mobileNav.locator('a[href="/features"]').click();
    await expect(page).toHaveURL(/\/features$/);
    await expect(page.locator('#features-heading')).toBeVisible();

    await page.goto('/');
    await page.locator('a[href="/connect"]').first().click();
    await expect(page).toHaveURL(/\/connect$/);
    await expect(page.locator('#nickname')).toBeVisible();
    await expect(page.locator('script[src="/assets/js/app.js"]')).toHaveCount(1);

    expect(failures).toEqual([]);
  });
});

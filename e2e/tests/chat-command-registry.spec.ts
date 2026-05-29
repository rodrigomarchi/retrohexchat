import { expect, Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';
import {
  commandCategoryLabels,
  registeredCommands,
} from '../helpers/commandRegistry';

async function signedInUser(page: Page) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  await connect.open();
  await connect.enterNickname(uniqueNickname('qreg'));
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();
  return chat;
}

function commandNamesFromHelp(text: string): string[] {
  const commandList = text
    .split('Type /help')[0]
    .replace(/^.*Available commands:\s*/s, '');

  return [...commandList.matchAll(/\/([a-z0-9_]+)/g)]
    .map((match) => match[1])
    .sort();
}

async function latestInlineHelp(chat: ChatPage, previousCount: number) {
  await expect(chat.inlineHelp).toHaveCount(previousCount + 1);
  return chat.inlineHelp.nth(previousCount);
}

test.describe('Command registry, help, and autocomplete', () => {
  test('/help lists exactly the registered command names (Q1)', async ({
    page,
  }) => {
    const chat = await signedInUser(page);
    const expectedCommands = registeredCommands();

    await chat.sendMessage('/help');

    const helpRow = chat.messageRowByText('Available commands:');
    await expect(helpRow).toBeVisible();

    const listedCommands = commandNamesFromHelp((await helpRow.innerText()) || '');
    expect(listedCommands).toEqual(expectedCommands);
  });

  test('/help <command> renders detailed inline help for every registered command (Q2)', async ({
    page,
  }) => {
    test.setTimeout(180_000);
    const chat = await signedInUser(page);

    for (const command of registeredCommands()) {
      const previousCount = await chat.inlineHelp.count();

      await chat.sendMessage(`/help ${command}`);

      const card = await latestInlineHelp(chat, previousCount);
      await expect(card).toContainText('Syntax');
      await expect(card).toContainText('Examples');
      await expect(card).toContainText('Open in Help Topics');
      await expect(card).not.toContainText('Unknown command');
    }
  });

  test('inline command help links deep-link to full Help Topics pages (Q3)', async ({
    page,
  }) => {
    test.setTimeout(240_000);
    const chat = await signedInUser(page);
    const helpPage = await page.context().newPage();

    try {
      for (const command of registeredCommands()) {
        const previousCount = await chat.inlineHelp.count();

        await chat.sendMessage(`/help ${command}`);

        const card = await latestInlineHelp(chat, previousCount);
        const link = card.getByRole('link', { name: 'Open in Help Topics' });
        const href = await link.getAttribute('href');

        expect(href).toMatch(/\/chat\/help\//);
        await helpPage.goto(href!);
        await expect(helpPage).toHaveURL(/\/chat\/help\/.+/);
        await expect(helpPage.getByTestId('help-content-pane')).toContainText(
          'Syntax',
        );
      }
    } finally {
      await helpPage.close();
    }
  });

  test('command autocomplete exposes every command grouped by category (Q4)', async ({
    page,
  }) => {
    const chat = await signedInUser(page);
    const expectedCommands = registeredCommands();

    await chat.chatInput.click();
    await chat.chatInput.pressSequentially('/');

    await expect(chat.autocompleteDropdown).toBeVisible();

    for (const label of commandCategoryLabels) {
      await expect(chat.autocompleteDropdown).toContainText(label);
    }

    const itemTexts = await chat.autocompleteDropdown
      .locator('[data-testid^="autocomplete-item-"]')
      .allInnerTexts();
    const suggestedCommands = itemTexts
      .map((text) => text.match(/\/([a-z0-9_]+)/)?.[1])
      .filter((command): command is string => !!command)
      .sort();

    expect(suggestedCommands).toEqual(expectedCommands);
  });
});

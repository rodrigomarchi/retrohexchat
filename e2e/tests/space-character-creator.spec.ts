/**
 * @section SP - Virtual Spaces
 * @flow SP1 [done] The door of a space is the character creator: pieces, each pictured on the character, colours and Surprise me change the preview, and entering wears exactly that character; one body is no tab
 * @flow SP5 [done] The creator's art is its catalog and its PNG pieces, each decodable, the catalog asked for at most once per screen, and no per-class sprite sheet ever
 * @flow SP37 [done] The character made at the door is remembered for the nickname on reload, and another person in the channel sees it beside the nickname
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect, Page } from "@playwright/test";
import {
  newSignedInUser,
  closeUsers,
  uniqueChannel,
  TestUser,
} from "../helpers/chatUsers";
import { buildCharacter, enterAs, recipeOf } from "../helpers/characters";
import { shot } from "../helpers/screenshots";

// A compact signature of the canvas pixels — changes when the world redraws.
async function canvasSignature(page: Page): Promise<number> {
  return page
    .locator('[data-testid="channel-space-shell"] canvas')
    .evaluate((el: HTMLCanvasElement) => {
      const ctx = el.getContext("2d");
      if (!ctx || !el.width || !el.height) return 0;
      const { data } = ctx.getImageData(0, 0, el.width, el.height);
      let sum = 0;
      for (let i = 0; i < data.length; i += 997)
        sum = (sum + data[i]) % 1_000_000;
      return sum;
    });
}

async function recipeOnPreview(space: Page): Promise<string> {
  return (await space
    .getByTestId("space-creator-preview")
    .getAttribute("data-recipe"))!;
}

test.describe("Virtual space character creator", () => {
  test("the door is the creator, and entering wears what it made (SP1)", async ({
    browser,
  }) => {
    const user: TestUser = await newSignedInUser(browser, "chc");
    try {
      const channel = uniqueChannel("chc");
      await user.chat.sendMessage(`/join ${channel}`);

      // The space is entered from the conversation, in a tab of its own. The
      // creator gates the canvas; it shows before the world mounts.
      const page = await user.chat.openSpace();
      const creator = page.getByTestId("space-character-creator");
      await expect(creator).toBeVisible();
      await expect(page.getByTestId("channel-space-shell")).toHaveCount(0);
      for (const tab of ["skin", "outfit", "hair", "hat", "face"]) {
        await expect(
          page.getByTestId(`space-creator-tab-${tab}`),
        ).toBeVisible();
      }
      // One body is no choice: there is no tab for it.
      await expect(page.getByTestId("space-creator-tab-body")).toHaveCount(0);
      const preview = page.getByTestId("space-creator-preview");
      await expect(preview).toHaveAttribute("data-recipe", /^c1\./);
      await page.screenshot({ path: "test-results/space-creator.png" });

      // Every piece and colour is one field of the recipe the preview draws.
      await buildCharacter(page, "monk");
      await page.getByTestId("space-creator-tab-hair").click();
      await page.getByTestId("space-creator-option-hair-lng").click();
      await expect(preview).toHaveAttribute("data-recipe", /\.h-lng-/);
      await page.getByTestId("space-creator-swatch-hair_colour-4").click();
      await expect(preview).toHaveAttribute("data-recipe", /\.h-lng-4\./);
      await page.getByTestId("space-creator-tab-skin").click();
      await page.getByTestId("space-creator-swatch-skin-0").click();
      await expect(preview).toHaveAttribute("data-recipe", /\.s-0\./);
      await page.getByTestId("space-creator-tab-hair").click();
      await page.getByTestId("space-creator-option-hair-0").click();
      await expect(preview).toHaveAttribute("data-recipe", /\.h-0\./);

      // Every piece is pictured on the character being made: a head for what
      // goes on it, the whole figure for an outfit, each a picture that loads.
      for (const [tab, field] of [
        ["hair", "hair"],
        ["hat", "hat"],
        ["face", "face"],
        ["outfit", "outfit"],
      ]) {
        await page.getByTestId(`space-creator-tab-${tab}`).click();
        const stills = page.locator(
          `[data-testid^="space-creator-still-${field}-"]`,
        );
        await expect(stills.first()).toBeVisible();
        await expect
          .poll(() =>
            stills.evaluateAll((imgs) =>
              imgs.every(
                (i) =>
                  (i as HTMLImageElement).complete &&
                  (i as HTMLImageElement).naturalWidth > 0,
              ),
            ),
          )
          .toBe(true);
      }
      await shot(page, "each outfit pictured on the character");

      // Surprise me makes somebody new.
      const before = await recipeOnPreview(page);
      await page.getByTestId("space-creator-randomize").click();
      await expect(preview).not.toHaveAttribute("data-recipe", before);
      await page.screenshot({ path: "test-results/space-creator-random.png" });

      // Entering wears exactly the character on the preview.
      await buildCharacter(page, "mage");
      const made = await recipeOnPreview(page);
      expect(made).toBe(recipeOf("mage"));
      await page.getByTestId("space-creator-enter").click();

      const shell = page.getByTestId("channel-space-shell");
      await expect(shell).toBeVisible();
      await expect(shell).toHaveAttribute("data-avatar", made);
      await expect(creator).toBeHidden();
      await expect(
        page.locator('[data-testid="channel-space-shell"] canvas'),
      ).toBeVisible();

      // The world draws something (character + map) onto the canvas.
      await expect
        .poll(() => canvasSignature(page), { timeout: 10_000 })
        .toBeGreaterThan(0);
      await page.screenshot({ path: "test-results/space-mage.png" });

      // The attack (Space) exercises the made character's action path. The
      // world must keep rendering.
      const canvas = page.locator('[data-testid="channel-space-shell"] canvas');
      await canvas.click();
      await page.keyboard.press("Space");
      await page.screenshot({ path: "test-results/space-mage-attack.png" });
      await expect.poll(() => canvasSignature(page)).toBeGreaterThan(0);
    } finally {
      await closeUsers([user]);
    }
  });

  test("the character is remembered on reload and seen by others (SP37)", async ({
    browser,
  }) => {
    const host: TestUser = await newSignedInUser(browser, "chr");
    const guest: TestUser = await newSignedInUser(browser, "chg");
    try {
      const channel = uniqueChannel("chr");
      await host.chat.sendMessage(`/join ${channel}`);
      await guest.chat.sendMessage(`/join ${channel}`);

      const space = await host.chat.openSpace();
      await enterAs(space, "scout");
      await expect(space.getByTestId("channel-space-shell")).toHaveAttribute(
        "data-avatar",
        recipeOf("scout"),
      );
      await expect(space.getByTestId("space-loading")).toBeHidden({
        timeout: 15_000,
      });

      // A registered nickname owns its character: the door, reloaded, opens
      // on it rather than on somebody new.
      await space.reload();
      await expect(space.getByTestId("space-character-creator")).toBeVisible();
      await expect(space.getByTestId("space-creator-preview")).toHaveAttribute(
        "data-recipe",
        recipeOf("scout"),
        { timeout: 15_000 },
      );
      await space.getByTestId("space-creator-enter").click();
      await expect(space.getByTestId("channel-space-shell")).toHaveAttribute(
        "data-avatar",
        recipeOf("scout"),
      );

      // Somebody else in the channel sees that same character beside the
      // nickname, in the conversation and in the nicklist.
      await host.chat.sendMessage("look at my new outfit");
      const portrait = `img.rh-portrait[data-testid="nick-portrait"][data-avatar="${recipeOf("scout")}"]`;
      await expect(guest.page.locator(portrait).first()).toBeVisible({
        timeout: 10_000,
      });
      await expect(
        guest.page.locator(
          `[data-testid="nicklist-item-${host.nick}"] ${portrait}`,
        ),
      ).toHaveCount(1);
    } finally {
      await closeUsers([host, guest]);
    }
  });

  // The creator composes a character from PNG pieces described by one catalog,
  // the one thing every piece hangs off: the creator's preview and the map
  // each read it once. A 200 does not prove decoding, so each piece fetched is
  // decoded by the browser too.
  test("the creator's art is its catalog and its pieces (SP5)", async ({
    browser,
  }) => {
    const user: TestUser = await newSignedInUser(browser, "chn");
    try {
      const failed: string[] = [];
      const pieces: string[] = [];
      const sheets: string[] = [];
      const catalogs: string[] = [];
      const watch = (target: Page) => {
        target.on("request", (r) => {
          const url = r.url();
          if (url.includes("/images/space/avatars/")) sheets.push(url);
          if (/\/images\/space\/creator\/catalog(-[0-9a-f]+)?\.json/.test(url))
            catalogs.push(url);
        });
        target.on("response", (r) => {
          const url = r.url();
          if (!url.includes("/images/space/")) return;
          if (r.status() >= 400) failed.push(`${r.status()} ${url}`);
          else if (/\/images\/space\/creator\/.+\.png/.test(url))
            pieces.push(url);
        });
      };

      // The creator's preview asks for the catalog the moment the door paints,
      // so the listener has to be on the tab before it exists.
      watch(user.page);
      user.ctx.on("page", watch);

      const channel = uniqueChannel("chn");
      await user.chat.sendMessage(`/join ${channel}`);

      const page = await user.chat.openSpace();
      await enterAs(page, "bard");
      await expect(page.getByTestId("channel-space-shell")).toHaveAttribute(
        "data-avatar",
        recipeOf("bard"),
      );
      await expect
        .poll(() => canvasSignature(page), { timeout: 15_000 })
        .toBeGreaterThan(0);

      expect(failed, "a space asset 404'd").toEqual([]);
      expect(sheets, "a per-class sprite sheet was requested").toEqual([]);
      // Once by the creator's preview at the door and once by the map: two
      // screens, one catalog each. In production its address carries the digest
      // and an immutable cache, so the second is the browser's own copy.
      expect(
        catalogs.length,
        `the creator catalog was requested ${catalogs.length} times: ${catalogs.join(", ")}`,
      ).toBeLessThanOrEqual(2);

      const served = [...new Set(pieces)];
      expect(served.length, "no creator piece was fetched").toBeGreaterThan(0);
      for (const src of served) {
        const size = await page.evaluate(async (url) => {
          const img = new Image();
          img.src = url;
          await img.decode();
          return { w: img.naturalWidth, h: img.naturalHeight };
        }, src);

        expect(size.w, `${src} decoded to nothing`).toBeGreaterThan(0);
        expect(size.h, `${src} decoded to nothing`).toBeGreaterThan(0);
      }
    } finally {
      await closeUsers([user]);
    }
  });
});

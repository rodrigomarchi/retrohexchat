import { test, expect, Page } from "@playwright/test";
import { readFileSync } from "node:fs";
import path from "node:path";
import {
  ADMIN_NICK,
  ADMIN_PW,
  closeUsers,
  knownSignedInUser,
  newSignedInUser,
} from "../helpers/chatUsers";
import { shot } from "../helpers/screenshots";

/**
 * Runs scripts/server-provision.md the way an operator does — paste the block
 * into the Admin Console, press Run — and reads the transcript back.
 *
 * The static lint in server_provision_test.exs proves the script is well formed.
 * Only this proves it works: a `/bot set` naming a capability that does not yet
 * exist, a topic promising a trigger nothing answers, a greeting that never
 * fires — all of those parse perfectly and still leave a dead server.
 */

const PROVISION_DOC = path.resolve(
  __dirname,
  "../../scripts/server-provision.md",
);

const BOTS = [
  "Brutus",
  "Patches",
  "Wanda",
  "Pixel",
  "Murphy",
  "Tiao",
  "Harold",
];
const CHANNELS = [
  "#lobby",
  "#trivia",
  "#arcade",
  "#retro",
  "#tech",
  "#brasil",
  "#help",
];

/** The first fenced block that carries the provisioning banner. */
function provisioningScript(): string {
  const md = readFileSync(PROVISION_DOC, "utf8");
  const blocks = [...md.matchAll(/```\n([\s\S]*?)```/g)].map((m) => m[1]);
  const script = blocks.find((b) =>
    b.includes("RetroHexChat — Production Setup"),
  );
  if (!script) throw new Error("provisioning block not found in the markdown");
  return script.trimEnd();
}

/** Commands the transcript should echo, in order — comments and blanks removed. */
function commandLines(script: string): string[] {
  return script
    .split("\n")
    .map((l) => l.trim())
    .filter((l) => l.startsWith("/"));
}

async function runInConsole(page: Page, input: string) {
  await page.locator("#admin-console-input").fill(input);
  await page
    .locator("#admin-console-form")
    .getByRole("button", { name: "Run" })
    .click();
}

/**
 * Best-effort reset. The e2e database survives between runs, so a second run
 * would otherwise trip over its own channels and bots. Failures here are
 * expected on a clean database and are deliberately not asserted on.
 */
async function teardown(page: Page) {
  const lines = [
    ...BOTS.map((b) => `/bot destroy ${b}`),
    ...CHANNELS.flatMap((c) => [`/join ${c}`, "/cs drop"]),
  ];
  await runInConsole(page, lines.join("\n"));
  await expect(page.getByTestId("admin-console-output")).not.toBeEmpty();
  await page.getByRole("button", { name: "Clear" }).click();
}

test.describe("server provisioning script", () => {
  test.describe.configure({ mode: "serial", timeout: 180_000 });

  test("the whole script runs with every line accepted", async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);

    try {
      await admin.chat.openAdminWindow("open_admin_console");
      await teardown(admin.page);

      const script = provisioningScript();
      const expected = commandLines(script);
      expect(expected.length).toBeGreaterThan(100);

      await runInConsole(admin.page, script);

      const output = admin.page.getByTestId("admin-console-output");
      // The last line of the script is Harold joining #help; when its echo
      // lands, the batch is done.
      await expect(output).toContainText("/bot join Harold #help", {
        timeout: 60_000,
      });

      await shot(admin.page, "provision-transcript");

      // Nothing scrolled out of the transcript, so what we assert on is all of it.
      await expect(admin.page.getByTestId("admin-console-trimmed")).toHaveCount(
        0,
      );

      // A failed line renders red. There must be none.
      const failures = output.locator(".text-red-400");
      const failureCount = await failures.count();
      if (failureCount > 0) {
        const texts = await failures.allInnerTexts();
        throw new Error(
          `provisioning reported ${failureCount} failed line(s):\n${texts.join("\n")}`,
        );
      }

      // Every command echoed, so nothing was silently skipped.
      const transcript = await output.innerText();
      const missing = expected.filter((line) => !transcript.includes(line));
      expect(missing, "commands missing from the transcript").toEqual([]);

      // The settings that only exist after their first write — the class of bug
      // that silently dropped values before.
      expect(transcript).toContain("trivia.category");
      expect(transcript).toContain("moderation.action");
      expect(transcript).toContain("dice.default_notation");
    } finally {
      await closeUsers([admin]);
    }
  });

  test("a newcomer is greeted, and the advertised triggers answer", async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const visitor = await newSignedInUser(browser, "guest");

    try {
      // #lobby is the room a new connection lands in, so the greeting has
      // already fired by the time we look.
      await visitor.chat.expectMessageVisible("lobby attendant");

      // That only one bot welcomes a newcomer is asserted statically instead:
      // the e2e database keeps its scrollback between runs, so counting lines
      // here would measure history, not this visit. See the provisioning lint
      // and greeter_test for the guarantee that Brutus stays silent.
      await shot(visitor.page, "lobby-greeting");

      // A custom command answers in its short form.
      await visitor.chat.sendMessage("!tour");
      await visitor.chat.expectMessageVisible("Seven rooms, no filler");

      // Cooldowns are per channel: give the bot its second back before asking
      // again, or the next command is dropped in silence.
      await visitor.page.waitForTimeout(1200);

      // dice only answers the long form — the exact thing the topic used to get
      // wrong by promising a bare !roll.
      await visitor.chat.sendMessage("!Patches roll 1d20");
      await visitor.chat.expectMessageVisible("Rolling 1d20");

      // Trivia, likewise, is long-form only.
      await visitor.chat.sendMessage("/join #trivia");
      await visitor.chat.expectMessageVisible("Wanda here");
      await visitor.page.waitForTimeout(1200);
      await visitor.chat.sendMessage("!Wanda trivia start");
      await visitor.chat.expectMessageVisible("Q1/10:");
      await shot(visitor.page, "trivia-round");
      await visitor.chat.sendMessage("!Wanda trivia stop");
    } finally {
      await closeUsers([admin, visitor]);
    }
  });
});

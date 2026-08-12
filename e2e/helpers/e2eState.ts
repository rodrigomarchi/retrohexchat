import type { Browser } from "@playwright/test";
import { ConnectPage } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { adminNick, adminPassword, isLocalTarget } from "./env";
import { spawnSync } from "node:child_process";
import { basename, resolve } from "node:path";

const repoRoot =
  basename(process.cwd()) === "e2e"
    ? resolve(process.cwd(), "..")
    : process.cwd();

const openRegistrationExpression = [
  "Logger.configure(level: :warning)",
  "Application.ensure_all_started(:ecto_sql)",
  "RetroHexChat.Repo.start_link()",
  'Ecto.Adapters.SQL.query!(RetroHexChat.Repo, "DELETE FROM autojoin_entries WHERE owner_nickname IN ($1, $2)", ["TestAdmin", "TestOper"])',
  'Ecto.Adapters.SQL.query!(RetroHexChat.Repo, "DELETE FROM perform_entries WHERE owner_nickname IN ($1, $2)", ["TestAdmin", "TestOper"])',
  'Ecto.Adapters.SQL.query!(RetroHexChat.Repo, "DELETE FROM perform_settings WHERE owner_nickname IN ($1, $2)", ["TestAdmin", "TestOper"])',
  'RetroHexChat.Services.Queries.upsert_setting("registration", "open", "e2e-reset")',
].join("; ");

function runMix(args: string[], description: string) {
  const result = spawnSync("mix", args, {
    cwd: repoRoot,
    encoding: "utf8",
    env: {
      ...process.env,
      LOG_LEVEL: "warning",
      MIX_ENV: "e2e",
    },
  });

  if (result.error) {
    throw result.error;
  }

  if (result.status !== 0) {
    throw new Error(
      [description, result.stdout, result.stderr].filter(Boolean).join("\n"),
    );
  }
}

export function ensureE2eDatabaseMigrated() {
  runMix(["ecto.create"], "Failed to create e2e database.");
  runMix(["ecto.migrate"], "Failed to migrate e2e database.");
}

export function resetRegistrationOpen() {
  const result = spawnSync(
    "mix",
    ["run", "--no-start", "-e", openRegistrationExpression],
    {
      cwd: repoRoot,
      encoding: "utf8",
      env: {
        ...process.env,
        LOG_LEVEL: "warning",
        MIX_ENV: "e2e",
      },
    },
  );

  if (result.error) {
    throw result.error;
  }

  if (result.status !== 0) {
    throw new Error(
      [
        "Failed to reset e2e registration setting to open.",
        result.stdout,
        result.stderr,
      ]
        .filter(Boolean)
        .join("\n"),
    );
  }
}

/**
 * Reopens registration on whichever server the run is pointed at.
 *
 * `resetRegistrationOpen` edits the local e2e database directly, which is the
 * fast path and the only one that works before a browser exists. Against a
 * deployment it reaches the wrong database entirely, and a spec that closed
 * registration there leaves it closed — which is exactly what happened to
 * production, for the best part of an hour, until a later spec could not find
 * the registration form.
 *
 * So a run against anything but localhost undoes it the way an operator would:
 * signed in as the administrator, through the command.
 */
export async function reopenRegistration(browser: Browser): Promise<void> {
  if (isLocalTarget()) {
    resetRegistrationOpen();
    return;
  }

  const ctx = await browser.newContext();

  try {
    const page = await ctx.newPage();
    const connect = new ConnectPage(page);
    const chat = new ChatPage(page);

    await connect.open();
    await connect.signIn(adminNick(), adminPassword());
    await chat.waitUntilConnected();
    await chat.sendMessage("/admin server set registration open");
    await chat.expectMessageVisible("registration");
  } finally {
    await ctx.close();
  }
}

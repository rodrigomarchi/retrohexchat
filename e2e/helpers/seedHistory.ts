import { spawnSync } from "node:child_process";
import { basename, resolve } from "node:path";

/**
 * Seeds a channel's history straight into the database.
 *
 * Scrollback only means something over a history longer than a reader can
 * produce by typing: a thousand messages sent through the composer take
 * minutes and measure the composer, not the pagination. Writing the rows
 * directly makes the history exact — `msg-0001` … `msg-1000`, in id order —
 * so a spec can assert on *which* messages arrived and in what order, not
 * merely that some did.
 */
const repoRoot =
  basename(process.cwd()) === "e2e"
    ? resolve(process.cwd(), "..")
    : process.cwd();

export function seedChannelHistory(
  channel: string,
  count: number,
  author = "Seeder",
): void {
  run(
    [
      `Ecto.Adapters.SQL.query!(RetroHexChat.Repo, "DELETE FROM messages WHERE channel_name = $1", ["${channel}"])`,
      `Ecto.Adapters.SQL.query!(RetroHexChat.Repo, "INSERT INTO messages (channel_name, author_nickname, content, type, inserted_at) SELECT $1, $2, 'msg-' || lpad(i::text, 4, '0'), 'message', now() - (($3 - i) * interval '1 second') FROM generate_series(1, $3) AS i", ["${channel}", "${author}", ${count}])`,
    ],
    `Failed to seed ${count} messages into ${channel}.`,
  );
}

/**
 * Seeds a conversation between two nicks, alternating who wrote each message.
 *
 * The DM scrollback runs through the same viewport as the channel one, so what
 * this covers that `seedChannelHistory` does not is the other query behind it —
 * the conversation is a pair of nicks in either order, not one column.
 */
export function seedPrivateHistory(
  nickA: string,
  nickB: string,
  count: number,
): void {
  run(
    [
      `Ecto.Adapters.SQL.query!(RetroHexChat.Repo, "DELETE FROM private_messages WHERE (sender_nickname = $1 AND recipient_nickname = $2) OR (sender_nickname = $2 AND recipient_nickname = $1)", ["${nickA}", "${nickB}"])`,
      `Ecto.Adapters.SQL.query!(RetroHexChat.Repo, "INSERT INTO private_messages (sender_nickname, recipient_nickname, content, type, inserted_at) SELECT CASE WHEN i % 2 = 0 THEN $1 ELSE $2 END, CASE WHEN i % 2 = 0 THEN $2 ELSE $1 END, 'msg-' || lpad(i::text, 4, '0'), 'message', now() - (($3 - i) * interval '1 second') FROM generate_series(1, $3) AS i", ["${nickA}", "${nickB}", ${count}])`,
    ],
    `Failed to seed ${count} private messages between ${nickA} and ${nickB}.`,
  );
}

function run(statements: string[], failure: string): void {
  const expression = [
    "Logger.configure(level: :warning)",
    "Application.ensure_all_started(:ecto_sql)",
    "RetroHexChat.Repo.start_link()",
    ...statements,
  ].join("; ");

  const result = spawnSync("mix", ["run", "--no-start", "-e", expression], {
    cwd: repoRoot,
    encoding: "utf8",
    env: { ...process.env, LOG_LEVEL: "warning", MIX_ENV: "e2e" },
  });

  if (result.error) throw result.error;

  if (result.status !== 0) {
    throw new Error(
      [failure, result.stdout, result.stderr].filter(Boolean).join("\n"),
    );
  }
}

import { spawnSync } from 'node:child_process';
import { basename, resolve } from 'node:path';

const repoRoot =
  basename(process.cwd()) === 'e2e'
    ? resolve(process.cwd(), '..')
    : process.cwd();

const openRegistrationExpression = [
  'Logger.configure(level: :warning)',
  'Application.ensure_all_started(:ecto_sql)',
  'RetroHexChat.Repo.start_link()',
  'Ecto.Adapters.SQL.query!(RetroHexChat.Repo, "DELETE FROM autojoin_entries WHERE owner_nickname IN ($1, $2)", ["TestAdmin", "TestOper"])',
  'Ecto.Adapters.SQL.query!(RetroHexChat.Repo, "DELETE FROM perform_entries WHERE owner_nickname IN ($1, $2)", ["TestAdmin", "TestOper"])',
  'Ecto.Adapters.SQL.query!(RetroHexChat.Repo, "DELETE FROM perform_settings WHERE owner_nickname IN ($1, $2)", ["TestAdmin", "TestOper"])',
  'RetroHexChat.Services.Queries.upsert_setting("registration", "open", "e2e-reset")',
].join('; ');

export function resetRegistrationOpen() {
  const result = spawnSync(
    'mix',
    ['run', '--no-start', '-e', openRegistrationExpression],
    {
      cwd: repoRoot,
      encoding: 'utf8',
      env: {
        ...process.env,
        LOG_LEVEL: 'warning',
        MIX_ENV: 'e2e',
      },
    },
  );

  if (result.error) {
    throw result.error;
  }

  if (result.status !== 0) {
    throw new Error(
      [
        'Failed to reset e2e registration setting to open.',
        result.stdout,
        result.stderr,
      ]
        .filter(Boolean)
        .join('\n'),
    );
  }
}

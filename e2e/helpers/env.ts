export function e2eBaseURL(): string {
  return (
    process.env.E2E_BASE_URL ||
    `http://localhost:${process.env.E2E_PORT || "4003"}`
  );
}

export function e2eOrigin(): string {
  return new URL(e2eBaseURL()).origin;
}

export function e2eURL(path: string): string {
  return new URL(path, e2eBaseURL()).toString();
}

/**
 * The server administrator to run admin specs as.
 *
 * Locally this is `TestAdmin`, which `config/e2e.exs` names in its `admins`
 * list — it gains its powers by registering, and the e2e database is disposable
 * so its password can be a constant. No other deployment has that config, so a
 * run pointed at one (see `e2eBaseURL`) has to be told which registered
 * nickname is an administrator there, and that is not a thing to write down in
 * a spec: pass `E2E_ADMIN_NICK` and `E2E_ADMIN_PASSWORD` on the command line.
 */
export function adminNick(): string {
  return process.env.E2E_ADMIN_NICK || "TestAdmin";
}

export function adminPassword(): string {
  return process.env.E2E_ADMIN_PASSWORD || "adminpass1";
}

/**
 * Whether the run is pointed at the disposable local e2e server.
 *
 * A spec that leaves the server in a state only `mix run` against the local
 * database can undo — closing registration is the one — must not run anywhere
 * else. `resetRegistrationOpen` hardcodes `MIX_ENV=e2e`, so against a
 * deployment it restores nothing, and the spec's own `@flow` line saying it
 * restores becomes false. It left registration closed on production for the
 * best part of an hour.
 */
export function isLocalTarget(): boolean {
  return new URL(e2eBaseURL()).hostname === "localhost";
}

/**
 * The reason a spec that can only work locally gives when it steps aside.
 *
 * Some specs reach past the browser: they write rows straight into the local
 * database, or call an endpoint compiled only into the e2e build, or wait on a
 * presigned upload to the development storage. Pointed at a deployment they do
 * not test it — they fail, and a failure that means "wrong target" is worse than
 * no coverage, because it takes a place in the list of real defects.
 *
 * Pass this to `test.skip(!isLocalTarget(), …)` so the run says so out loud.
 */
export function localOnlyReason(what: string): string {
  return `${what} — only meaningful against the local e2e server, and this run targets ${e2eBaseURL()}`;
}

/**
 * Whether the configured administrator is a *root* administrator.
 *
 * The two are different powers: `config :retro_hex_chat, :root_admins` may
 * promote others to admin, `:admins` may not. Locally the e2e administrator is
 * an ordinary one, which is what the specs about that restriction assume. A
 * deployment's administrator is usually root, and a spec that needs somebody
 * who *cannot* promote has to make one — so it needs to be told which it has.
 */
export function adminIsRoot(): boolean {
  return process.env.E2E_ADMIN_IS_ROOT === "1";
}

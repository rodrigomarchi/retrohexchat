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

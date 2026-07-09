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

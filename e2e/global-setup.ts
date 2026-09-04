import type { FullConfig } from "@playwright/test";
import {
  ensureE2eDatabaseMigrated,
  resetRegistrationOpen,
  warmRenderPaths,
} from "./helpers/e2eState";

export default async function globalSetup(config: FullConfig) {
  ensureE2eDatabaseMigrated();
  resetRegistrationOpen();

  const baseURL = config.projects[0]?.use?.baseURL;
  if (baseURL) {
    await warmRenderPaths(baseURL);
  }
}

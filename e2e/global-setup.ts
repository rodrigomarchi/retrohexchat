import type { FullConfig } from "@playwright/test";
import {
  ensureE2eDatabaseMigrated,
  resetRegistrationOpen,
} from "./helpers/e2eState";

export default async function globalSetup(_config: FullConfig) {
  ensureE2eDatabaseMigrated();
  resetRegistrationOpen();
}

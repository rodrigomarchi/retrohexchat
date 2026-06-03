import type { FullConfig } from '@playwright/test';
import { resetRegistrationOpen } from './helpers/e2eState';

export default async function globalSetup(_config: FullConfig) {
  resetRegistrationOpen();
}

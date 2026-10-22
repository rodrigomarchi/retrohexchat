// Types for `images.mjs`, for the TypeScript captures that import it.
import type { Page } from "@playwright/test";

export function toWebp(
  page: Page,
  png: Buffer,
  options: {
    quality: number;
    maxWidth?: number;
    clip?: number[] | null;
    smooth?: boolean;
  },
): Promise<{ webp: Buffer; width: number; height: number }>;

export function toCard(
  page: Page,
  webp: Buffer,
  options: {
    width: number;
    height: number;
    quality: number;
    fit: "contain" | "crop";
  },
): Promise<Buffer>;

export function sortKeys<T extends Record<string, unknown>>(object: T): T;

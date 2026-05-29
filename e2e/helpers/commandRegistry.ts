import { readFileSync } from 'node:fs';
import path from 'node:path';

const repoRoot = path.resolve(__dirname, '..', '..');

export const commandCategoryLabels = [
  'Basics',
  'Channel',
  'User',
  'Configuration',
  'Advanced',
];

export function registeredCommands(): string[] {
  const registryPath = path.join(
    repoRoot,
    'apps/retro_hex_chat/lib/retro_hex_chat/commands/registry.ex',
  );
  const source = readFileSync(registryPath, 'utf8');
  const commands = [...source.matchAll(/"([^"]+)"\s*=>/g)].map(
    (match) => match[1],
  );

  return [...new Set(commands)].sort();
}

export function uniqueChannel(prefix = 'q'): string {
  return `#${prefix}${Date.now().toString(36)}${Math.random()
    .toString(36)
    .slice(2, 7)}`;
}

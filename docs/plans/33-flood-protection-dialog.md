# Flood Protection Dialog Migration

## Objetivo

Migrar configuracao de flood protection para componente stateful com draft local.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:645`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/flood_protection_dialog.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/settings_dialogs_events.ex`
- State atual: `show_flood_protection_dialog` e `session.flood_protection`.

## Tecnica

Use LiveComponent stateful montado sob demanda. O componente recebe settings iniciais, mantem draft e envia save/reset ao parent.

## Tasks

- [ ] Criar `FloodProtectionDialogComponent`.
- [ ] Mover draft para o componente.
- [ ] Validar limites localmente.
- [ ] Enviar save/reset como comandos.
- [ ] Atualizar `Session` no parent apos sucesso.

## Validacao

- [ ] Alteracoes aplicam flood settings.
- [ ] Reset defaults funciona.
- [ ] Cancelar nao altera session.
- [ ] Erros de validacao ficam locais.

## Prompt de execucao

Settings dialog deve trabalhar com draft local. Session so muda no OK/Apply.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.

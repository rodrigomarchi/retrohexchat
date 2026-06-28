# Disconnect Confirm Dialog Migration

## Objetivo

Migrar confirmacao de disconnect para dialog simples sem estado global alem da intencao de desconectar.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:539`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/disconnect_confirm_dialog.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/core_events.ex`
- State atual: `show_disconnect_confirm`.

## Tecnica

Use function component com JS modal se possivel. Se confirmar precisa do server, o botao confirm emite evento global `confirm_disconnect`; abrir/fechar pode ser local.

## Tasks

- [ ] Remover `show_disconnect_confirm` se modal JS resolver.
- [ ] Manter evento server apenas para confirmacao.
- [ ] Garantir cancel local sem roundtrip.
- [ ] Padronizar com outros confirm dialogs.

## Validacao

- [ ] Disconnect via menu abre confirmacao.
- [ ] Confirmar executa cleanup e redirect.
- [ ] Cancelar nao altera sessao.
- [ ] Fechar via Escape funciona.

## Prompt de execucao

Confirm dialog simples nao deve virar um bloco de estado permanente no parent.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.

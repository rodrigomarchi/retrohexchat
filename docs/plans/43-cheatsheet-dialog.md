# Cheatsheet Dialog Migration

## Objetivo

Remover estado server-side desnecessario do Cheatsheet dialog ou mover para componente local de ajuda.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:875`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/cheatsheet_dialog.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/menu_toolbar_events.ex`
- State atual: `cheatsheet_visible`.

## Tecnica

Se conteudo e estatico, use function component + `Phoenix.LiveView.JS` modal. Se atalhos podem mudar por usuario, use LiveComponent stateful com dados recebidos do keybinding provider.

## Tasks

- [ ] Confirmar origem de `cheatsheet_bindings()`.
- [ ] Remover `cheatsheet_visible` se JS modal basta.
- [ ] Caso dinamico, criar `CheatsheetDialogComponent`.
- [ ] Evitar recalcular bindings em todo render do chat.

## Validacao

- [ ] Abrir via toolbar/shortcut funciona.
- [ ] Conteudo de bindings esta correto.
- [ ] Fechar nao gera patch global se possivel.
- [ ] Parent nao recalcula cheatsheet em nova mensagem.

## Prompt de execucao

Trate como About: estatico fica client-side; dinamico fica componente dedicado.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.

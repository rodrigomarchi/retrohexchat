# About Dialog Migration

## Objetivo

Remover estado server-side desnecessario do About dialog.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:516`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/about_dialog.ex`
- State atual: `show_about`.
- Abertura atual via `show_modal("about-dialog")` no logo: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:34`.

## Tecnica

Preferir `Phoenix.LiveView.JS` e dialog function component sem stateful server se nao ha dados dinamicos. O parent nao precisa manter `show_about`.

## Tasks

- [ ] Confirmar se About e puramente estatico.
- [ ] Remover `show_about` se `show_modal/1` e suficiente.
- [ ] Se necessario, criar componente wrapper montado no shell.
- [ ] Garantir close via JS sem roundtrip.

## Validacao

- [ ] Clicar logo abre About.
- [ ] Fechar por botao/Escape/click externo funciona.
- [ ] Nenhum evento server e emitido para abrir/fechar About.
- [ ] Parent nao tem assign `show_about`.

## Prompt de execucao

Dialog estatico deve ser client-side sempre que possivel. Nao transforme em LiveComponent se nao ha estado.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.

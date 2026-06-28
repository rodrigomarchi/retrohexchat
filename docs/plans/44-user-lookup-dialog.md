# User Lookup Dialog Migration

## Objetivo

Migrar User Lookup para componente stateful com input local, validacao e chamadas async para whois/whowas.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:882`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/user_lookup_dialog.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/user_lookup_events.ex`
- Helpers: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/whois.ex`
- State atual: `show_user_lookup_dialog`, `user_lookup_nick`, `user_lookup_error`, `lookup_result`.

## Tecnica

Use LiveComponent stateful. Input e erro ficam locais. Whois/whowas podem rodar via `start_async/3`; resultado vai para `LookupResultComponent` ou sub-state.

## Tasks

- [ ] Criar `UserLookupDialogComponent`.
- [ ] Mover nickname/error.
- [ ] Executar whois/whowas async quando custoso.
- [ ] Enviar resultado para LookupResultComponent.
- [ ] Preservar acoes: whois, whowas, query PM.
- [ ] Remover `user_lookup_events.ex` da pipeline global.

## Validacao

- [ ] Lookup por nick online mostra whois.
- [ ] Lookup por nick offline mostra whowas quando existe.
- [ ] Erro aparece localmente.
- [ ] Query PM a partir do resultado funciona.
- [ ] Dialog nao trava chat durante lookup.

## Prompt de execucao

Lookup e consulta. Nao deixe input e resultado no parent; use async e estado local.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.

# Channel List Dialog Migration

## Objetivo

Migrar Channel List para componente stateful com busca/filtro/loading e resultado local.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:631`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/channel_list.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/channel_list_events.ex`
- State atual: `show_channel_list`, `channel_list_channels`, `channel_list_filtered`, `channel_list_selected`, `channel_list_search`, `channel_list_loading`, `channel_list_count`.

## Tecnica

Use LiveComponent stateful com async para carregar canais. Use stream para lista se houver muitos canais. Debounce busca local.

## Tasks

- [ ] Criar `ChannelListDialogComponent`.
- [ ] Mover state de lista/filtro/selecao/loading/count.
- [ ] Carregar canais com `start_async/3`.
- [ ] Usar stream ou virtualizacao simples se lista for grande.
- [ ] Emitir `join` ou `knock` ao parent.
- [ ] Resetar resultado ao fechar ou manter cache com TTL.

## Validacao

- [ ] Abrir mostra loading e depois canais.
- [ ] Busca filtra rapido sem patch global.
- [ ] Join/knock funciona.
- [ ] Lista grande nao degrada DOM.
- [ ] Fechar/reabrir nao deixa loading preso.

## Prompt de execucao

Este dialog e candidato forte a async + stream. Nao carregue lista inteira no parent.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
